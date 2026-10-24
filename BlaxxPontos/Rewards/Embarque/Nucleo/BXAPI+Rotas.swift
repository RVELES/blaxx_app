//
//  BXAPI+Rotas.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  Todas as funções de endpoint que as telas usam (§1.7.5 da spec; contrato em docs/redesenho/03-contrato-api.md).
//  Cada função devolve DTOs já sanitizados (BXModelos.swift) ou lança `BXErro`.
//
//  NÃO existem e não devem ser chamados: PATCH /user/profile, PATCH /user/password, /auth/logout-all,
//  /auth/resend-verification, POST /auth/account/delete, POST /auth/dev/verify-email,
//  POST /campaigns/<id>/progress, /redeem/* (D03).
//

import Foundation

extension BXAPI {

    // MARK: - Ajudantes

    /// "?a=1&b=dois" com valores codificados; itens nil/vazios ficam de fora.
    nonisolated static func consulta(_ itens: [(String, String?)]) -> String {
        var c = URLComponents()
        c.queryItems = itens.compactMap { k, v in
            guard let v = v?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
            return URLQueryItem(name: k, value: v)
        }
        guard let q = c.percentEncodedQuery, !q.isEmpty else { return "" }
        // "+" literal precisa ir codificado (URLComponents não codifica).
        return "?" + q.replacingOccurrences(of: "+", with: "%2B")
    }

    /// Segmento de caminho seguro para ids vindos da API ou da tela.
    nonisolated static func segmento(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-_."))) ?? s
    }

    nonisolated private struct RespostaUsuario: Decodable, Sendable { let user: BXUsuario? }

    /// Login/cadastro/Google/2FA: lê tokens + usuário da mesma resposta.
    private func autenticar(_ r: BXRequisicao) async throws -> (BXTokens, BXUsuario) {
        let dados = try await requisitarDados(r)
        guard let tokens = Self.tokens(de: dados),
              let u = (try? JSONDecoder().decode(RespostaUsuario.self, from: dados))?.user else {
            throw BXErro(status: 200, tipo: .desconhecido, contexto: .acesso)
        }
        return (tokens, u)
    }

    private func publico(_ m: BXRequisicao.Metodo, _ caminho: String, corpo: Data? = nil,
                         contexto: BXSanitizador.Contexto = .geral) -> BXRequisicao {
        var r = BXRequisicao(m, caminho, corpo: corpo, autenticada: false)
        r.contexto = contexto
        return r
    }

    private func privado(_ m: BXRequisicao.Metodo, _ caminho: String, corpo: Data? = nil,
                         contexto: BXSanitizador.Contexto = .geral) -> BXRequisicao {
        var r = BXRequisicao(m, caminho, corpo: corpo, autenticada: true)
        r.contexto = contexto
        return r
    }

    // MARK: - Acesso

    /// POST /auth/login {email (e-mail ou CPF), password, mfa_code?} (aquece o servidor antes).
    /// SMS → `.mfaSMS`; TOTP sem código → `.mfaTOTP` (repetir com `mfa`). 401 "Credenciais inválidas",
    /// 423 (bloqueio, `bloqueadoAte`), 429 e 403 voltam como `BXErro` sem mexer na sessão.
    func entrar(login: String, senha: String, mfa: String? = nil) async throws -> BXRespostaLogin {
        var campos: [String: any Sendable] = ["email": login.trimmingCharacters(in: .whitespacesAndNewlines), "password": senha]
        if let mfa, !mfa.isEmpty { campos["mfa_code"] = mfa }
        var r = publico(.post, "/auth/login", corpo: BXRequisicao.campos(campos), contexto: .acesso)
        r.aquecer = true
        do {
            let dados = try await requisitarDados(r)
            let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any] ?? [:]
            if (j["mfa_required"] as? Bool) == true {
                if let desafio = j["mfa_challenge_token"] as? String, !desafio.isEmpty {
                    return .mfaSMS(desafio: desafio, dica: (j["mfa_phone_hint"] as? String).flatMap { $0.isEmpty ? nil : $0 })
                }
                return .mfaTOTP
            }
            guard let tokens = Self.tokens(de: dados),
                  let u = (try? JSONDecoder().decode(RespostaUsuario.self, from: dados))?.user else {
                throw BXErro(status: 200, tipo: .desconhecido, contexto: .acesso)
            }
            return .ok(tokens, u)
        } catch let e as BXErro where e.tipo == .mfaNecessario {
            return .mfaTOTP
        }
    }

    /// POST /auth/login/2fa {challenge_token, code}. Erros 400 com `codigo` invalid_code, challenge_expired, wrong_code…
    func entrar2FA(desafio: String, codigo: String) async throws -> (BXTokens, BXUsuario) {
        try await autenticar(publico(.post, "/auth/login/2fa",
                                     corpo: BXRequisicao.campos(["challenge_token": desafio, "code": codigo]),
                                     contexto: .acesso))
    }

    /// POST /auth/google {id_token, nonce} (id_token + nonce do GoogleAuthService).
    func entrarGoogle(idToken: String, nonce: String?) async throws -> (BXTokens, BXUsuario) {
        var campos: [String: any Sendable] = ["id_token": idToken]
        if let nonce, !nonce.isEmpty { campos["nonce"] = nonce }
        var r = publico(.post, "/auth/google", corpo: BXRequisicao.campos(campos), contexto: .acesso)
        r.aquecer = true
        return try await autenticar(r)
    }

    /// POST /auth/register com accept_terms/privacy/lgpd = true. 400 com `problemas` (política de senha), 409 (e-mail/CPF).
    func cadastrar(_ c: BXCadastro) async throws -> (BXTokens, BXUsuario) {
        var r = publico(.post, "/auth/register", corpo: BXRequisicao.json(c), contexto: .acesso)
        r.aquecer = true
        return try await autenticar(r)
    }

    /// GET /auth/me
    func eu() async throws -> BXUsuario {
        try await requisitar(privado(.get, "/auth/me"), como: BXUsuario.self)
    }

    /// POST /auth/logout (revoga o token de acesso atual; sem tentar renovar).
    func sair() async throws {
        var r = privado(.post, "/auth/logout", contexto: .acesso)
        r.permitirRenovacao = false
        r.timeout = 10
        try await requisitarSemCorpo(r)
    }

    /// POST /auth/forgot-password: resposta sempre genérica.
    func esqueciSenha(email: String) async throws {
        try await requisitarSemCorpo(publico(.post, "/auth/forgot-password",
                                             corpo: BXRequisicao.campos(["email": email.trimmingCharacters(in: .whitespacesAndNewlines)]),
                                             contexto: .acesso))
    }

    /// POST /auth/reset-password {token, password, password_confirm}. Derruba todas as sessões.
    func redefinirSenha(token: String, senha: String) async throws {
        try await requisitarSemCorpo(publico(.post, "/auth/reset-password",
                                             corpo: BXRequisicao.campos(["token": token, "password": senha, "password_confirm": senha]),
                                             contexto: .acesso))
    }

    /// POST /auth/change-password. 401 "Senha atual incorreta" NÃO derruba a sessão; sucesso derruba
    /// (chamar `BXSessao.sessaoRevogada("Senha alterada. Entre de novo.")`).
    func trocarSenha(atual: String, nova: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/auth/change-password",
                                             corpo: BXRequisicao.campos(["old_password": atual, "new_password": nova]),
                                             contexto: .conta))
    }

    /// POST /auth/verify-email/send → minutos de validade do código.
    func enviarCodigoEmail() async throws -> Int {
        let dados = try await requisitarDados(privado(.post, "/auth/verify-email/send", contexto: .acesso))
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any]
        return (j?["expires_in_min"] as? NSNumber)?.intValue ?? 10
    }

    /// POST /auth/verify-email {code}. 400 com `tentativasRestantes`; 429 depois de 3 tentativas.
    func verificarEmail(codigo: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/auth/verify-email",
                                             corpo: BXRequisicao.campos(["code": codigo]), contexto: .acesso))
    }

    /// GET /auth/terms/current → versão vigente dos termos.
    func versaoTermos() async throws -> String {
        let dados = try await requisitarDados(publico(.get, "/auth/terms/current"))
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any]
        return (j?["version"] as? String) ?? "1.0"
    }

    /// POST /auth/terms/reaccept (quando a versão dos termos mudar).
    func reaceitarTermos() async throws {
        try await requisitarSemCorpo(privado(.post, "/auth/terms/reaccept",
                                             corpo: BXRequisicao.campos(["accept_terms": true, "accept_privacy": true, "accept_lgpd": true])))
    }

    // MARK: - Segurança

    /// GET /user/sessions
    func sessoes() async throws -> [BXSessaoDispositivo] {
        try await requisitar(privado(.get, "/user/sessions"), como: BXEnvelopeSessoes.self).sessoes
    }

    /// DELETE /user/sessions/<id>
    func encerrarSessao(id: String) async throws {
        try await requisitarSemCorpo(privado(.delete, "/user/sessions/\(Self.segmento(id))", contexto: .conta))
    }

    /// POST /auth/sessions/revoke-all (derruba a sessão atual também → `sessaoRevogada`).
    func encerrarTodasAsSessoes() async throws {
        var r = privado(.post, "/auth/sessions/revoke-all", contexto: .conta)
        r.permitirRenovacao = false
        try await requisitarSemCorpo(r)
    }

    /// GET /user/access-log?limit= (1…200)
    func historicoAcesso(limite: Int = 50) async throws -> [BXEventoAcesso] {
        let l = min(200, max(1, limite))
        return try await requisitar(privado(.get, "/user/access-log?limit=\(l)"), como: BXEnvelopeItens<BXEventoAcesso>.self).itens
    }

    /// POST /user/phone {phone} → celular mascarado (envia SMS). 429 `cooldown` com `tentarEmSegundos`.
    func cadastrarCelular(_ tel: String) async throws -> String {
        let dados = try await requisitarDados(privado(.post, "/user/phone", corpo: BXRequisicao.campos(["phone": tel]), contexto: .conta))
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any]
        return (j?["phone_masked"] as? String) ?? BXFormato.celularMascarado(tel)
    }

    /// POST /user/phone/verify {code} → usuário atualizado.
    func verificarCelular(codigo: String) async throws -> BXUsuario {
        let dados = try await requisitarDados(privado(.post, "/user/phone/verify", corpo: BXRequisicao.campos(["code": codigo]), contexto: .conta))
        if let u = (try? JSONDecoder().decode(RespostaUsuario.self, from: dados))?.user { return u }
        return try await eu()
    }

    /// DELETE /user/phone {password} (desliga o 2FA por SMS se estiver ativo).
    func removerCelular(senha: String) async throws {
        try await requisitarSemCorpo(privado(.delete, "/user/phone", corpo: BXRequisicao.campos(["password": senha]), contexto: .conta))
    }

    /// POST /user/2fa/sms/enable {password}. 400 `phone_not_verified` → verificar o celular antes.
    func ligar2FASMS(senha: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/user/2fa/sms/enable", corpo: BXRequisicao.campos(["password": senha]), contexto: .conta))
    }

    /// POST /user/2fa/sms/disable {password}
    func desligar2FASMS(senha: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/user/2fa/sms/disable", corpo: BXRequisicao.campos(["password": senha]), contexto: .conta))
    }

    /// POST /auth/mfa/setup → segredo + URI `otpauth://` (para o QR).
    func prepararTOTP() async throws -> (segredo: String, uri: String) {
        let dados = try await requisitarDados(privado(.post, "/auth/mfa/setup", contexto: .conta))
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any] ?? [:]
        guard let segredo = j["secret"] as? String, let uri = j["uri"] as? String else {
            throw BXErro(status: 200, tipo: .desconhecido, contexto: .conta)
        }
        return (segredo, uri)
    }

    /// POST /auth/mfa/enable {code}
    func ligarTOTP(codigo: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/auth/mfa/enable", corpo: BXRequisicao.campos(["code": codigo]), contexto: .conta))
    }

    /// POST /auth/mfa/disable {password, code}
    func desligarTOTP(senha: String, codigo: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/auth/mfa/disable",
                                             corpo: BXRequisicao.campos(["password": senha, "code": codigo]), contexto: .conta))
    }

    // MARK: - Privacidade

    /// GET /privacy/consents
    func consentimentos() async throws -> [BXConsentimento] {
        try await requisitar(privado(.get, "/privacy/consents"), como: BXEnvelopeItens<BXConsentimento>.self).itens
    }

    /// POST /privacy/consents {type, version}
    func registrarConsentimento(tipo: String, versao: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/privacy/consents",
                                             corpo: BXRequisicao.campos(["type": tipo, "version": versao]), contexto: .conta))
    }

    /// DELETE /privacy/consents/<id>
    func revogarConsentimento(id: String) async throws {
        try await requisitarSemCorpo(privado(.delete, "/privacy/consents/\(Self.segmento(id))", contexto: .conta))
    }

    /// GET /auth/account/export → JSON (arquivo para `ShareLink`; não exibir: traz campos proibidos).
    func exportarDados() async throws -> Data {
        var r = privado(.get, "/auth/account/export", contexto: .conta)
        r.timeout = 60
        return try await requisitarDados(r)
    }

    /// DELETE /auth/account {password | google_id_token, confirm: "EXCLUIR MINHA CONTA"} → `sessaoRevogada`.
    func excluirConta(senha: String?, googleIdToken: String?) async throws {
        var campos: [String: any Sendable] = ["confirm": "EXCLUIR MINHA CONTA"]
        if let senha, !senha.isEmpty { campos["password"] = senha }
        if let googleIdToken, !googleIdToken.isEmpty { campos["google_id_token"] = googleIdToken }
        var r = privado(.delete, "/auth/account", corpo: BXRequisicao.campos(campos), contexto: .conta)
        r.permitirRenovacao = true
        try await requisitarSemCorpo(r)
    }

    // MARK: - Carteira e cartão

    /// GET /wallet/ (também efetiva envios cuja janela de 60 s passou).
    func carteira() async throws -> BXCarteira {
        try await requisitar(privado(.get, "/wallet/"), como: BXCarteira.self)
    }

    /// GET /wallet/transactions?limit= (máx. 100, sem paginação).
    func lancamentos(limite: Int = 100) async throws -> [BXLancamento] {
        let l = min(100, max(1, limite))
        return try await requisitar(privado(.get, "/wallet/transactions?limit=\(l)"), como: BXEnvelopeItens<BXLancamento>.self).itens
    }

    /// GET /card/
    func cartao() async throws -> BXCartaoEstado {
        try await requisitar(privado(.get, "/card/"), como: BXCartaoEstado.self)
    }

    /// GET /card/tiers (público)
    func niveis() async throws -> [BXNivel] {
        try await requisitar(publico(.get, "/card/tiers"), como: BXEnvelopeNiveis.self).niveis
    }

    /// GET /card/pass/status
    func passeDisponivel() async throws -> Bool {
        let dados = try await requisitarDados(privado(.get, "/card/pass/status"))
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any]
        return (j?["available"] as? Bool) ?? false
    }

    /// GET /card/pass → .pkpass. 503 `wallet_not_configured` quando o servidor não tem certificado.
    func passe() async throws -> Data {
        var r = privado(.get, "/card/pass")
        r.timeout = 60
        return try await requisitarDados(r)
    }

    // MARK: - Compra (PIX como meio de pagamento)

    /// GET /pix/packages (público; status conferido) → 4 pacotes na ordem start, plus, prime, black.
    func pacotes() async throws -> [BXPacote] {
        try await requisitar(publico(.get, "/pix/packages", contexto: .compra), como: BXMapaPacotes.self).pacotes
    }

    /// GET /pix/provider (público)
    func provedorPix() async throws -> BXProvedorPix {
        try await requisitar(publico(.get, "/pix/provider", contexto: .compra), como: BXProvedorPix.self)
    }

    /// POST /pix/charge {package} (aquece antes). Provedor fora → `.pagamentoIndisponivel` (D01).
    func criarCobrancaPix(pacote: String) async throws -> BXCobrancaPix {
        var r = privado(.post, "/pix/charge", corpo: BXRequisicao.campos(["package": pacote]), contexto: .compra)
        r.aquecer = true
        r.timeout = 45
        return try await requisitar(r, como: BXCobrancaPix.self)
    }

    /// POST /pix/charge {amount_brl} (valor livre, R$ 10 a R$ 100.000).
    func criarCobrancaPix(valor: Decimal) async throws -> BXCobrancaPix {
        let reais = NSDecimalNumber(decimal: valor).doubleValue
        var r = privado(.post, "/pix/charge", corpo: BXRequisicao.campos(["amount_brl": reais]), contexto: .compra)
        r.aquecer = true
        r.timeout = 45
        return try await requisitar(r, como: BXCobrancaPix.self)
    }

    /// GET /pix/charge/<id> (polling do pagamento).
    func cobrancaPix(id: String) async throws -> BXCobrancaPix {
        try await requisitar(privado(.get, "/pix/charge/\(Self.segmento(id))", contexto: .compra), como: BXCobrancaPix.self)
    }

    /// GET /pix/my-charges (50 mais recentes).
    func minhasCobrancasPix() async throws -> [BXCobrancaPix] {
        try await requisitar(privado(.get, "/pix/my-charges", contexto: .compra), como: BXEnvelopeItens<BXCobrancaPix>.self).itens
    }

    /// GET /payments/card/config (público). Só usar com `BXRecursos.compraCartao` (D02).
    func configCartao() async throws -> BXConfigCartao {
        try await requisitar(publico(.get, "/payments/card/config", contexto: .compra), como: BXConfigCartao.self)
    }

    /// POST /payments/card/charge com Idempotency-Key (D02). Cobra de verdade em produção.
    func cobrarCartao(_ p: BXPedidoCartao, chave: BXChaveIdempotencia) async throws -> BXCobrancaCartao {
        var r = privado(.post, "/payments/card/charge", corpo: BXRequisicao.json(p), contexto: .compra)
        r.idempotencia = chave
        r.aquecer = true
        r.timeout = 60
        return try await requisitar(r, como: BXCobrancaCartao.self)
    }

    /// GET /payments/card/charge/<id>
    func cobrancaCartao(id: String) async throws -> BXCobrancaCartao {
        try await requisitar(privado(.get, "/payments/card/charge/\(Self.segmento(id))", contexto: .compra), como: BXCobrancaCartao.self)
    }

    /// GET /payments/card/my-charges
    func minhasCobrancasCartao() async throws -> [BXCobrancaCartao] {
        try await requisitar(privado(.get, "/payments/card/my-charges", contexto: .compra), como: BXEnvelopeItens<BXCobrancaCartao>.self).itens
    }

    // MARK: - Envio

    /// POST /transfer/ {to, amount_pts, password, message?, mfa_code?} com Idempotency-Key da intenção.
    /// 400 "senha incorreta" (não desloga), 401 `mfaNecessario`, 403 e-mail, 409 `conflito` (DUPLICATE_SUSPECTED,
    /// `extras["previous_transfer_id"]`), 429 `codigo == "RECIPIENT_PROBE_BLOCKED"`.
    func enviar(_ p: BXPedidoEnvio, chave: BXChaveIdempotencia) async throws -> BXEnvio {
        var r = privado(.post, "/transfer/", corpo: BXRequisicao.json(p), contexto: .envio)
        r.idempotencia = chave
        r.aquecer = true
        return try await requisitar(r, como: BXEnvio.self)
    }

    /// POST /transfer/<id>/cancel (dentro da janela de 60 s).
    func cancelarEnvio(id: String) async throws -> BXEnvio {
        try await requisitar(privado(.post, "/transfer/\(Self.segmento(id))/cancel", contexto: .envio), como: BXEnvio.self)
    }

    // MARK: - Descobrir (parceiros, benefícios, vouchers, campanhas)

    /// Ids dos parceiros de exemplo (cache de 10 min; busca a lista completa se precisar).
    private func ficticios() async throws -> Set<String> {
        if let ids = idsFicticios, let em = idsFicticiosEm, Date.now.timeIntervalSince(em) < 600 { return ids }
        let todos = try await requisitar(publico(.get, "/partners/"), como: BXEnvelopeItens<BXParceiro>.self).itens
        let ids = Set(todos.filter(\.escondidoNoApp).map(\.id))
        idsFicticios = ids
        idsFicticiosEm = .now
        return ids
    }

    /// GET /partners/?category=&q= (público). Parceiros de exemplo nunca voltam.
    func parceiros(categoria: String? = nil, busca: String? = nil) async throws -> [BXParceiro] {
        let todos = try await requisitar(publico(.get, "/partners/" + Self.consulta([("category", categoria), ("q", busca)])),
                                         como: BXEnvelopeItens<BXParceiro>.self).itens
        if (categoria ?? "").isEmpty && (busca ?? "").isEmpty {
            idsFicticios = Set(todos.filter(\.escondidoNoApp).map(\.id))
            idsFicticiosEm = .now
        }
        return todos.filter { !$0.escondidoNoApp && !$0.nome.isEmpty }
    }

    /// GET /partners/categories (público) → nomes crus; para pílulas usar `BXSanitizador.categoriaCanonica`.
    func categoriasParceiros() async throws -> [String] {
        let dados = try await requisitarDados(publico(.get, "/partners/categories"))
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any]
        return ((j?["items"] as? [Any]) ?? []).compactMap { $0 as? String }.filter { !$0.isEmpty }
    }

    /// GET /partners/<id> (público). Parceiro de exemplo → `.naoEncontrado`.
    func parceiro(id: String) async throws -> BXParceiroDetalhe {
        let d = try await requisitar(publico(.get, "/partners/\(Self.segmento(id))"), como: BXParceiroDetalhe.self)
        if d.parceiro.escondidoNoApp { throw BXErro(status: 404, tipo: .naoEncontrado) }
        return d
    }

    /// GET /benefits/?category=&partner_id= (público). Sem benefícios de parceiro de exemplo nem inativos.
    func beneficios(categoria: String? = nil, parceiroID: String? = nil) async throws -> [BXBeneficio] {
        let lista = try await requisitar(publico(.get, "/benefits/" + Self.consulta([("category", categoria), ("partner_id", parceiroID)])),
                                         como: BXEnvelopeItens<BXBeneficio>.self).itens
        let escondidos = try await ficticios()
        return lista.filter { b in b.ativo && !b.escondidoNoApp && !(b.parceiroID.map(escondidos.contains) ?? false) }
    }

    /// GET /benefits/<id> (público). Benefício de parceiro de exemplo → `.naoEncontrado`.
    func beneficio(id: String) async throws -> BXBeneficio {
        let b = try await requisitar(publico(.get, "/benefits/\(Self.segmento(id))"), como: BXBeneficio.self)
        if b.escondidoNoApp { throw BXErro(status: 404, tipo: .naoEncontrado) }
        if let p = b.parceiroID, try await ficticios().contains(p) { throw BXErro(status: 404, tipo: .naoEncontrado) }
        return b
    }

    /// POST /benefits/<id>/redeem com Idempotency-Key. 402 `.saldoInsuficiente`, 409 `.semEstoque`, 403 e-mail.
    func resgatarBeneficio(id: String, chave: BXChaveIdempotencia) async throws -> BXVoucher {
        var r = privado(.post, "/benefits/\(Self.segmento(id))/redeem", contexto: .resgate)
        r.idempotencia = chave
        r.aquecer = true
        return try await requisitar(r, como: BXVoucher.self)
    }

    /// GET /vouchers/
    func vouchers() async throws -> [BXVoucher] {
        try await requisitar(privado(.get, "/vouchers/", contexto: .resgate), como: BXEnvelopeItens<BXVoucher>.self).itens
    }

    /// GET /vouchers/<id>
    func voucher(id: String) async throws -> BXVoucher {
        try await requisitar(privado(.get, "/vouchers/\(Self.segmento(id))", contexto: .resgate), como: BXVoucher.self)
    }

    /// GET /campaigns/ (público; com sessão traz a adesão). Esconder em Release enquanto D04 (`BXRecursos.campanhas`).
    func campanhas() async throws -> [BXCampanha] {
        var r = publico(.get, "/campaigns/")
        r.bearerSeHouver = true
        return try await requisitar(r, como: BXEnvelopeItens<BXCampanha>.self).itens
    }

    /// POST /campaigns/<id>/join
    func participar(campanha id: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/campaigns/\(Self.segmento(id))/join"))
    }

    // MARK: - Notificações e push

    /// GET /notifications/ → itens (100 no máximo) + não lidas.
    func notificacoes() async throws -> (itens: [BXNotificacao], naoLidas: Int) {
        let e = try await requisitar(privado(.get, "/notifications/"), como: BXEnvelopeNotificacoes.self)
        return (e.itens, e.naoLidas)
    }

    /// GET /notifications/unread-count
    func contagemNaoLidas() async throws -> Int {
        let dados = try await requisitarDados(privado(.get, "/notifications/unread-count"))
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any]
        return (j?["count"] as? NSNumber)?.intValue ?? 0
    }

    /// PATCH /notifications/<id>/read
    func marcarLida(id: String) async throws {
        try await requisitarSemCorpo(privado(.patch, "/notifications/\(Self.segmento(id))/read"))
    }

    /// POST /notifications/read-all
    func marcarTodasLidas() async throws {
        try await requisitarSemCorpo(privado(.post, "/notifications/read-all"))
    }

    /// POST /push/devices/register {token, platform: "ios", app_version} → id do dispositivo.
    /// Só depois do login (D12). Use `BXPushRegistro.registrar(token:)`, que guarda o id para o sair.
    func registrarDispositivo(token: String) async throws -> String {
        let dados = try await requisitarDados(privado(.post, "/push/devices/register",
                                                      corpo: BXRequisicao.campos(["token": token, "platform": "ios", "app_version": BXAmbiente.versaoApp])))
        let j = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any]
        if let s = j?["id"] as? String { return s }
        if let n = j?["id"] as? NSNumber { return n.stringValue }
        throw BXErro(status: 200, tipo: .desconhecido)
    }

    /// DELETE /push/devices/<id>
    func removerDispositivo(id: String) async throws {
        var r = privado(.delete, "/push/devices/\(Self.segmento(id))")
        r.permitirRenovacao = false
        r.timeout = 10
        try await requisitarSemCorpo(r)
    }

    #if DEBUG
    /// POST /pix/simulate-payment {charge_id}: só DEBUG e só com provedor mock (404 em produção).
    func simularPagamento(cobranca id: String) async throws {
        try await requisitarSemCorpo(privado(.post, "/pix/simulate-payment", corpo: BXRequisicao.campos(["charge_id": id]), contexto: .compra))
    }
    #endif
}
