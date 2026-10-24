//
//  BXAPI.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  Cliente HTTP único do app novo (§1.7.3 da spec):
//  - `actor`: uma renovação de sessão por vez (single-flight), estado de aquecimento e dispositivo.
//  - Toda URLRequest: sem cookies (o cookie `blaxx_session` + CSRF derrubaria escritas com 401),
//    timeout 30 s, JSON, Bearer, X-Platform, X-Device-Id, X-App-Version e Idempotency-Key quando houver.
//  - GET: até 3 tentativas com espera em erro transitório e 5xx. Escrita: 1 tentativa (a tela repete com a
//    MESMA `BXChaveIdempotencia`).
//  - 401 só derruba a sessão quando o servidor diz que a sessão é inválida (`error == "unauthorized"` ou `msg`
//    do JWT). Senha errada, credencial inválida, MFA e reautenticação Google voltam como erro comum.
//  - Corpo HTML (404/405/429 do Werkzeug/Limiter) é ignorado; a mensagem vem do mapa de status.
//  - Transporte real: `SSLPinning.session` (pinning em Release). Em DEBUG com `-BXDemo`/`-BXDemoVisitante`,
//    `BXTransporteDemo` (nunca abre conexão).
//  As funções de cada endpoint estão em BXAPI+Rotas.swift.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Uma chave por INTENÇÃO do usuário (envio, resgate, cartão). Repetir a mesma em "Tentar de novo".
nonisolated struct BXChaveIdempotencia: Sendable, Hashable {
    let valor: String
    init() { valor = UUID().uuidString.lowercased() }
    init(valor: String) { self.valor = valor }
}

nonisolated struct BXRequisicao: Sendable {
    enum Metodo: String, Sendable { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

    var metodo: Metodo
    /// "/wallet/transactions?limit=100" (concatenado cru na URL base, nunca appendingPathComponent).
    var caminho: String
    var corpo: Data? = nil
    /// Exige sessão: sem tokens → `.sessaoExpirada` sem tocar a rede.
    var autenticada = true
    /// Rota pública que aceita Bearer opcional (ex.: `/campaigns/` acrescenta a adesão).
    var bearerSeHouver = false
    /// Usa o refresh token como Bearer (só `/auth/refresh`).
    var renovacao = false
    /// Em 401 de sessão, tenta renovar e repetir uma vez (desligado no logout).
    var permitirRenovacao = true
    var idempotencia: BXChaveIdempotencia? = nil
    /// GET /health antes (cold start do Render) se a última resposta tem mais de 10 min.
    var aquecer = false
    /// Contexto da mensagem de erro (só `.compra` pode dizer "PIX").
    var contexto: BXSanitizador.Contexto = .geral
    /// Tempo máximo da requisição.
    var timeout: TimeInterval = 30

    init(_ metodo: Metodo, _ caminho: String, corpo: Data? = nil, autenticada: Bool = true) {
        self.metodo = metodo
        self.caminho = caminho
        self.corpo = corpo
        self.autenticada = autenticada
    }

    /// Corpo JSON a partir de um `Encodable`.
    static func json<C: Encodable>(_ corpo: C) -> Data? { try? JSONEncoder().encode(corpo) }
    /// Corpo JSON a partir de um dicionário simples (valores String/Int/Bool/Double).
    static func campos(_ corpo: [String: any Sendable]) -> Data? {
        try? JSONSerialization.data(withJSONObject: corpo, options: [])
    }
}

nonisolated protocol BXTransporte: Sendable {
    func executar(_ r: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Transporte de verdade: `SSLPinning.session` (pinning ligado em Release; em DEBUG, `URLSession.shared`).
nonisolated struct BXTransporteReal: BXTransporte {
    @MainActor private static func sessao() -> URLSession { SSLPinning.session }

    func executar(_ r: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let s = await Self.sessao()
        let (dados, resposta) = try await s.data(for: r)
        guard let http = resposta as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (dados, http)
    }
}

actor BXAPI {
    /// Cliente do app. Em DEBUG com `-BXDemo`/`-BXDemoVisitante`: transporte de demonstração (zero rede).
    nonisolated static let shared: BXAPI = {
        #if DEBUG
        if BXDemo.ativo || BXDemo.visitante { return BXAPI(transporte: BXTransporteDemo.shared, cofre: .shared) }
        #endif
        return BXAPI(transporte: BXTransporteReal(), cofre: .shared)
    }()

    private let transporte: any BXTransporte
    let cofre: BXCofre
    private var renovacaoEmCurso: Task<BXTokens, Error>?
    private var ultimaResposta: Date?
    private var idDispositivo: String?
    private(set) var aoExpirarSessao: (@MainActor @Sendable () -> Void)?
    private var observadorRede: (@MainActor @Sendable (Bool) -> Void)?
    /// Ids dos parceiros de exemplo ("fictícia"): escondidos com os seus benefícios em todas as builds.
    var idsFicticios: Set<String>?
    var idsFicticiosEm: Date?

    init(transporte: any BXTransporte, cofre: BXCofre) {
        self.transporte = transporte
        self.cofre = cofre
    }

    // MARK: - Registro (a sessão e a conectividade se registram ao nascer)

    /// A sessão registra: chamado quando a renovação falha de vez (cofre já limpo).
    func registrar(aoExpirarSessao f: (@MainActor @Sendable () -> Void)?) { aoExpirarSessao = f }
    /// A conectividade registra: `true` a cada resposta do servidor, `false` a cada falha de rede.
    func registrar(observadorRede f: (@MainActor @Sendable (Bool) -> Void)?) { observadorRede = f }

    // MARK: - API pública do cliente

    func requisitar<T: Decodable & Sendable>(_ r: BXRequisicao, como: T.Type) async throws -> T {
        let (dados, http) = try await executar(r)
        do {
            return try JSONDecoder().decode(T.self, from: dados.isEmpty ? Data("{}".utf8) : dados)
        } catch {
            #if DEBUG
            print("[BXAPI] resposta de \(r.metodo.rawValue) \(Self.caminhoSemConsulta(r.caminho)) não decodificou como \(T.self): \(error)")
            #endif
            throw BXErro(status: http.statusCode, tipo: .desconhecido, contexto: r.contexto)
        }
    }

    func requisitarSemCorpo(_ r: BXRequisicao) async throws {
        _ = try await executar(r)
    }

    /// Bytes crus (.pkpass, exportação LGPD).
    func requisitarDados(_ r: BXRequisicao) async throws -> Data {
        try await executar(r).0
    }

    /// Há sessão guardada no cofre.
    func temSessao() async -> Bool { await cofre.temSessao() }

    /// Grava os tokens de um login bem-sucedido.
    func guardar(_ t: BXTokens) async { await cofre.gravar(t) }

    /// Apaga os tokens locais (sair, sessão revogada).
    func esquecerSessao() async {
        renovacaoEmCurso?.cancel()
        renovacaoEmCurso = nil
        await cofre.limpar()
    }

    /// Renovação proativa (ao voltar para o primeiro plano): só se o acesso tem mais que `idadeMaxima`.
    func renovarSeNecessario(idadeMaxima: TimeInterval = 25 * 60) async {
        guard let t = await cofre.ler(), t.idade() > idadeMaxima else { return }
        _ = try? await renovar()
    }

    /// GET /health (aquecimento do Render e "Verificar agora" da faixa offline). true = servidor respondeu.
    @discardableResult
    func saude() async -> Bool {
        var r = BXRequisicao(.get, "/health", autenticada: false)
        r.timeout = 60
        do { _ = try await executarUmaVez(r, token: nil); return true } catch { return false }
    }

    // MARK: - Execução

    private func executar(_ r: BXRequisicao) async throws -> (Data, HTTPURLResponse) {
        if r.aquecer, ultimaResposta.map({ Date.now.timeIntervalSince($0) > 10 * 60 }) ?? true {
            await saude()
        }
        let maxTentativas = r.metodo == .get ? 3 : 1
        var tentativa = 0
        var jaRenovou = false

        while true {
            try Task.checkCancellation()
            // Token desta tentativa (relido a cada volta: outra chamada pode ter renovado).
            var token: String?
            if r.renovacao {
                token = await cofre.ler()?.renovacao
                if token == nil { throw BXErro(status: 401, tipo: .sessaoExpirada, contexto: r.contexto) }
            } else if r.autenticada || r.bearerSeHouver {
                token = await cofre.ler()?.acesso
                if token == nil && r.autenticada {
                    await avisarExpiracao()
                    throw BXErro(status: 401, tipo: .sessaoExpirada, contexto: r.contexto)
                }
            }

            do {
                let (dados, http) = try await executarUmaVez(r, token: token)
                let status = http.statusCode
                if (200..<300).contains(status) { return (dados, http) }

                // Sessão inválida: renova uma vez (single-flight) e repete.
                if (status == 401 || status == 422), token != nil, !r.renovacao, r.permitirRenovacao,
                   Self.ehSessaoInvalida(status: status, dados: dados) {
                    if !jaRenovou {
                        jaRenovou = true
                        if let atual = await cofre.ler()?.acesso, atual != token { continue }   // alguém já renovou
                        _ = try await renovar()
                        continue
                    }
                    // Mesmo depois de renovar o servidor recusa: a sessão acabou.
                    await cofre.limpar()
                    await avisarExpiracao()
                    throw BXErro(status: status, tipo: .sessaoExpirada, contexto: r.contexto)
                }

                if status >= 500, r.metodo == .get, tentativa + 1 < maxTentativas {
                    tentativa += 1
                    try await esperar(tentativa)
                    continue
                }
                throw Self.mapearErro(status: status, dados: dados, requisicao: r)
            } catch let e as URLError {
                if Task.isCancelled { throw CancellationError() }
                if r.metodo == .get, tentativa + 1 < maxTentativas, Self.ehTransitorio(e) {
                    tentativa += 1
                    try await esperar(tentativa)
                    continue
                }
                var erro = BXErro.de(e)
                erro = BXErro(status: 0, tipo: erro.tipo, contexto: r.contexto)
                throw erro
            }
        }
    }

    /// Uma ida ao transporte, com headers e observação de rede.
    private func executarUmaVez(_ r: BXRequisicao, token: String?) async throws -> (Data, HTTPURLResponse) {
        let req = await montar(r, token: token)
        do {
            let (dados, http) = try await transporte.executar(req)
            ultimaResposta = .now
            if let o = observadorRede { await o(true) }
            #if DEBUG
            if BXAPI.logLigado {
                print("[BXAPI] \(r.metodo.rawValue) \(Self.caminhoSemConsulta(r.caminho)) → \(http.statusCode)")
            }
            #endif
            return (dados, http)
        } catch let e as URLError {
            if e.code != .cancelled || !Task.isCancelled, let o = observadorRede { await o(false) }
            #if DEBUG
            if BXAPI.logLigado { print("[BXAPI] \(r.metodo.rawValue) \(Self.caminhoSemConsulta(r.caminho)) → falha de rede \(e.code.rawValue)") }
            #endif
            throw e
        }
    }

    private func montar(_ r: BXRequisicao, token: String?) async -> URLRequest {
        let base = BXAmbiente.urlBase.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let caminho = r.caminho.hasPrefix("/") ? r.caminho : "/" + r.caminho
        var req = URLRequest(url: URL(string: base + caminho) ?? BXAmbiente.urlBase)
        req.httpMethod = r.metodo.rawValue
        req.httpShouldHandleCookies = false
        req.timeoutInterval = r.timeout
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let corpo = r.corpo {
            req.httpBody = corpo
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if r.metodo != .get {
            req.httpBody = Data("{}".utf8)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue("ios", forHTTPHeaderField: "X-Platform")
        req.setValue(await dispositivo(), forHTTPHeaderField: "X-Device-Id")
        req.setValue(BXAmbiente.versaoApp, forHTTPHeaderField: "X-App-Version")
        if let k = r.idempotencia { req.setValue(k.valor, forHTTPHeaderField: "Idempotency-Key") }
        return req
    }

    private func dispositivo() async -> String {
        if let idDispositivo { return idDispositivo }
        #if canImport(UIKit) && !os(watchOS)
        let id = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString } ?? "desconhecido"
        #else
        let id = "desconhecido"
        #endif
        idDispositivo = id
        return id
    }

    private func esperar(_ tentativa: Int) async throws {
        let base = tentativa == 1 ? 0.3 : 0.6
        let jitter = Double.random(in: 0...0.15)
        try await Task.sleep(for: .seconds(base + jitter))
    }

    private func avisarExpiracao() async {
        if let f = aoExpirarSessao { await f() }
    }

    // MARK: - Renovação single-flight

    /// POST /auth/refresh (rotação com detecção de reuso). Chamadas simultâneas esperam a MESMA tarefa.
    @discardableResult
    func renovar() async throws -> BXTokens {
        if let t = renovacaoEmCurso { return try await t.value }
        let t = Task { try await self.executarRenovacao() }
        renovacaoEmCurso = t
        defer { renovacaoEmCurso = nil }
        return try await t.value
    }

    private func executarRenovacao() async throws -> BXTokens {
        guard let atuais = await cofre.ler() else {
            throw BXErro(status: 401, tipo: .sessaoExpirada)
        }
        var r = BXRequisicao(.post, "/auth/refresh", autenticada: false)
        r.renovacao = true
        r.contexto = .acesso
        let dados: Data
        let http: HTTPURLResponse
        do {
            (dados, http) = try await executarUmaVez(r, token: atuais.renovacao)
        } catch let e as URLError {
            throw BXErro(tipo: BXErro.de(e).tipo)          // sem rede: NÃO derruba a sessão
        }
        switch http.statusCode {
        case 200..<300:
            guard let novos = Self.tokens(de: dados) else { throw BXErro(status: http.statusCode, tipo: .desconhecido) }
            // Outro login pode ter trocado os tokens enquanto renovávamos: não sobrescrever.
            if let agora = await cofre.ler(), agora.renovacao != atuais.renovacao { return agora }
            await cofre.gravar(novos)
            return novos
        case 401, 403, 404, 422:
            if let agora = await cofre.ler(), agora.renovacao != atuais.renovacao { return agora }
            await cofre.limpar()
            await avisarExpiracao()
            throw BXErro(status: http.statusCode, tipo: .sessaoExpirada)
        default:
            throw Self.mapearErro(status: http.statusCode, dados: dados, requisicao: r)
        }
    }

    // MARK: - Utilidades estáticas (sem estado; usadas também pelo transporte de demonstração)

    #if DEBUG
    /// Linha por requisição no console (método, caminho sem consulta, status). Nunca corpo nem token.
    nonisolated static let logLigado = ProcessInfo.processInfo.arguments.contains("-BXLogRede")
    #endif

    nonisolated static func caminhoSemConsulta(_ c: String) -> String {
        c.split(separator: "?", maxSplits: 1).first.map(String.init) ?? c
    }

    /// Lê `token`/`access_token` + `refresh_token` de uma resposta de login/refresh.
    nonisolated static func tokens(de dados: Data) -> BXTokens? {
        guard let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any] else { return nil }
        let acesso = (j["access_token"] as? String) ?? (j["token"] as? String)
        guard let acesso, !acesso.isEmpty, let renovacao = j["refresh_token"] as? String, !renovacao.isEmpty else { return nil }
        return BXTokens(acesso: acesso, renovacao: renovacao, emitidoEm: .now)
    }

    /// 401/422 que significam "sessão inválida": `{"error":"unauthorized"}` ou `{"msg": …}` do flask-jwt.
    nonisolated static func ehSessaoInvalida(status: Int, dados: Data) -> Bool {
        guard let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any] else {
            return status == 401 && dados.isEmpty
        }
        if (j["error"] as? String)?.lowercased() == "unauthorized" { return true }
        if j["msg"] is String, j["error"] == nil, j["mfa_required"] == nil { return true }
        return false
    }

    nonisolated static func ehTransitorio(_ e: URLError) -> Bool {
        switch e.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
             .notConnectedToInternet, .resourceUnavailable, .badServerResponse:
            return true
        default:
            return false
        }
    }

    /// Status + corpo → `BXErro` (§1.7.3).
    nonisolated static func mapearErro(status: Int, dados: Data, requisicao r: BXRequisicao) -> BXErro {
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any] ?? [:]   // HTML → vazio
        func texto(_ k: String) -> String? {
            if let s = j[k] as? String, !s.isEmpty { return s }
            if let n = j[k] as? NSNumber { return n.stringValue }
            return nil
        }
        let codigo = texto("code")
        let mensagem = texto("error") ?? texto("message")
        let mfa = (j["mfa_required"] as? Bool) ?? false
        let problemas: [String] = (j["issues"] as? [[String: Any]])?.compactMap { $0["message"] as? String } ?? []
        var extras: [String: String] = [:]
        for k in ["previous_transfer_id", "hint", "mfa_method", "action", "phone_masked", "already_verified"] {
            if let v = texto(k) { extras[k] = v }
        }
        let tentativas = (j["attempts_left"] as? NSNumber)?.intValue
        let tentarEm = (j["retry_in"] as? NSNumber)?.intValue
        let ate = texto("locked_until").flatMap(BXFormato.iso8601)
        let ehCompraPix = r.contexto == .compra && r.metodo == .post && r.caminho.hasPrefix("/pix/")

        let tipo: BXErro.Tipo
        switch status {
        case 400:
            if ehCompraPix, let m = mensagem,
               m.range(of: #"cobran[cç]a pix|provedor|indispon[ií]vel|tente de novo em alguns minutos|tente novamente em alguns minutos"#,
                       options: [.regularExpression, .caseInsensitive]) != nil {
                tipo = .pagamentoIndisponivel
            } else {
                tipo = .validacao
            }
        case 401:
            if ehSessaoInvalida(status: status, dados: dados) { tipo = .sessaoExpirada }
            else if mfa { tipo = .mfaNecessario }
            else { tipo = .naoAutorizado }
        case 402: tipo = .saldoInsuficiente
        case 403: tipo = codigo == "EMAIL_NOT_VERIFIED" ? .emailNaoVerificado : .naoAutorizado
        case 404: tipo = .naoEncontrado
        case 409:
            if codigo == "DUPLICATE_SUSPECTED" { tipo = .conflito }
            else if let m = mensagem, m.range(of: "estoque", options: .caseInsensitive) != nil { tipo = .semEstoque }
            else { tipo = .conflito }
        case 422: tipo = ehSessaoInvalida(status: status, dados: dados) ? .sessaoExpirada : .validacao
        case 423: tipo = .bloqueado
        case 429: tipo = .muitasTentativas
        case 500...599: tipo = ehCompraPix || (r.contexto == .compra && status == 503) ? .pagamentoIndisponivel : .servidor
        case 405, 410, 413, 415: tipo = .validacao
        default: tipo = (400..<500).contains(status) ? .validacao : .desconhecido
        }
        return BXErro(status: status, tipo: tipo, codigo: codigo, mensagemServidor: mensagem, problemas: problemas,
                      tentativasRestantes: tentativas, tentarEmSegundos: tentarEm, bloqueadoAte: ate,
                      extras: extras, contexto: r.contexto)
    }
}
