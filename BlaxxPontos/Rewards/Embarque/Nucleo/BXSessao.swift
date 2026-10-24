//
//  BXSessao.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  Estado de sessão observável (§1.7.8 da spec). A casca (G1) cria UMA instância, injeta com
//  `.environment(_:)`, chama `iniciar()` uma vez e liga `nav.sessaoMudou(logado:)` a `estado`.
//
//  - Login real por e-mail/CPF + senha (com 2FA SMS e TOTP) e por Google (GoogleAuthService:
//    ASWebAuthenticationSession + PKCE → id_token + nonce → POST /auth/google).
//  - Sem conta demo embutida, sem login silencioso, sem /auth/dev/verify-email.
//  - Sair de verdade: POST /auth/logout (melhor esforço), remove o push, limpa cofre, cache do saldo e os
//    restos da versão antiga (TokenStore/WalletCache). Favoritos de parceiros ficam (são do aparelho).
//  - A senha nunca é guardada: passa direto para o `BXAPI` e some.
//

import Foundation
import Observation

@MainActor @Observable final class BXSessao {
    enum Estado: Equatable { case iniciando, visitante, logado }
    /// Operação em curso (para os botões "Entrar"/"Sair" mostrarem carregando).
    enum Transicao: Equatable { case nenhuma, entrando, saindo }

    private(set) var estado: Estado = .iniciando
    private(set) var transicao: Transicao = .nenhuma
    private(set) var usuario: BXUsuario?
    private(set) var carteira: BXCarteira?
    /// Selo "SALDO DO ÚLTIMO ACESSO": a carteira mostrada veio do cache (servidor ainda não respondeu).
    private(set) var carteiraDoCache = false
    /// Último erro ao ler a carteira (nil depois de um sucesso). O Início mostra "—" + estado de erro.
    private(set) var erroCarteira: BXErro?
    private(set) var naoLidas = 0

    /// Onde a sessão mostra avisos ("Sua sessão expirou…"). A casca liga ao criar o `BXToastCentral`.
    @ObservationIgnored weak var toast: BXToastCentral?

    @ObservationIgnored private let api: BXAPI
    @ObservationIgnored private var iniciou = false

    init(api: BXAPI = .shared) {
        self.api = api
        let expirou: @MainActor @Sendable () -> Void = { [weak self] in self?.sessaoExpirou() }
        Task { await api.registrar(aoExpirarSessao: expirou) }
    }

    var entrando: Bool { transicao == .entrando }
    var saindo: Bool { transicao == .saindo }
    var logado: Bool { estado == .logado }
    var emailVerificado: Bool { usuario?.emailVerificado ?? false }
    /// Cartão BlaXx do usuário ("DE0A11C2"), quando conhecido.
    var cartaoID: String? { usuario?.cartaoID }

    // MARK: - Início

    /// Cofre → GET /auth/me → carteira. Sem tokens: visitante. Em DEBUG com `-BXDemo`, sessão de exemplo
    /// (tokens só em memória, respostas do transporte de demonstração).
    func iniciar() async {
        guard !iniciou else { return }
        iniciou = true
        #if DEBUG
        if BXDemo.ativo { await api.guardar(BXTokens(acesso: "demo-acesso", renovacao: "demo-renovacao")) }
        #endif
        guard await api.temSessao() else {
            estado = .visitante
            return
        }
        if let c = BXCacheCarteira.ler() {
            carteira = c
            carteiraDoCache = true
        }
        do {
            usuario = try await api.eu()
            estado = .logado
            await recarregarCarteira()
            await atualizarNaoLidas()
        } catch let e as BXErro where e.ehSessao {
            await api.esquecerSessao()
            limparLocal()
            estado = .visitante
        } catch {
            // Sem rede na abertura: os tokens continuam válidos; entra com o saldo do último acesso
            // e tenta o perfil de novo depois (`recarregarUsuario`, `aoVoltarPrimeiroPlano`).
            if await api.temSessao() {
                estado = .logado
            } else {
                limparLocal()
                estado = .visitante
            }
        }
    }

    // MARK: - Entrar

    /// E-mail ou CPF + senha (+ código TOTP quando o resultado anterior foi `.mfaTOTP`).
    /// `.ok` já deixa a sessão logada; `.mfaSMS` → `concluir2FASMS`; `.mfaTOTP` → repetir com `mfa`.
    func entrar(login: String, senha: String, mfa: String?) async -> Result<BXRespostaLogin, BXErro> {
        transicao = .entrando
        defer { transicao = .nenhuma }
        do {
            let r = try await api.entrar(login: login, senha: senha, mfa: mfa)
            if case let .ok(tokens, u) = r { await concluirLogin(tokens, u) }
            return .success(r)
        } catch {
            return .failure(BXErro.de(error))
        }
    }

    /// Código do SMS do 2FA.
    func concluir2FASMS(desafio: String, codigo: String) async throws {
        transicao = .entrando
        defer { transicao = .nenhuma }
        let (tokens, u) = try await api.entrar2FA(desafio: desafio, codigo: codigo)
        await concluirLogin(tokens, u)
    }

    /// Login com Google (D10, também em Release). Usuário fechou a janela do Google → `CancellationError`
    /// (a tela não mostra erro). Em modo demonstração o Google não abre.
    func entrarComGoogle() async throws {
        transicao = .entrando
        defer { transicao = .nenhuma }
        let (idToken, nonce) = try await idTokenGoogle()
        let (tokens, u) = try await api.entrarGoogle(idToken: idToken, nonce: nonce)
        await concluirLogin(tokens, u)
    }

    /// Reautenticação Google para excluir conta só-Google (`BXAPI.excluirConta(senha: nil, googleIdToken:)`).
    func reautenticarGoogle() async throws -> String {
        try await idTokenGoogle().idToken
    }

    private func idTokenGoogle() async throws -> (idToken: String, nonce: String) {
        if BXDemo.ativo || BXDemo.visitante {
            throw BXErro(tipo: .validacao, mensagemServidor: "O login com Google não abre no modo demonstração.", contexto: .acesso)
        }
        do {
            let r = try await GoogleAuthService.shared.signIn()
            return (r.idToken, r.nonce)
        } catch GoogleAuthError.userCancelled {
            throw CancellationError()
        } catch {
            throw BXErro(tipo: .naoAutorizado, mensagemServidor: "Não foi possível entrar com o Google. Tente de novo.", contexto: .acesso)
        }
    }

    /// POST /auth/register (os três aceites vão `true`). Sucesso → logado; a casca abre a verificação de e-mail.
    func cadastrar(_ c: BXCadastro) async throws {
        transicao = .entrando
        defer { transicao = .nenhuma }
        let (tokens, u) = try await api.cadastrar(c)
        await concluirLogin(tokens, u)
    }

    private func concluirLogin(_ tokens: BXTokens, _ u: BXUsuario) async {
        await api.guardar(tokens)
        usuario = u
        carteira = nil
        carteiraDoCache = false
        erroCarteira = nil
        estado = .logado
        await recarregarCarteira()
        await atualizarNaoLidas()
    }

    // MARK: - Recargas

    func recarregarCarteira() async {
        guard estado == .logado else { return }
        do {
            let c = try await api.carteira()
            carteira = c
            carteiraDoCache = false
            erroCarteira = nil
            BXCacheCarteira.gravar(c, usuarioID: usuario?.id)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            erroCarteira = BXErro.de(error)
        }
    }

    func recarregarUsuario() async {
        guard estado == .logado else { return }
        if let u = try? await api.eu() { usuario = u }
    }

    func atualizarNaoLidas() async {
        guard estado == .logado else { return }
        if let n = try? await api.contagemNaoLidas() { naoLidas = n }
    }

    /// A tela de notificações informa a contagem que já tem (evita outra ida ao servidor).
    func definirNaoLidas(_ n: Int) { naoLidas = max(0, n) }

    /// A casca chama quando o app volta ao primeiro plano: renova o acesso se tiver mais de 25 min,
    /// relê perfil (se faltou na abertura), saldo e não lidas.
    func aoVoltarPrimeiroPlano() async {
        guard estado == .logado else { return }
        await api.renovarSeNecessario()
        if usuario == nil { await recarregarUsuario() }
        await recarregarCarteira()
        await atualizarNaoLidas()
    }

    // MARK: - Sair

    /// Sair de verdade. Sempre termina como visitante, mesmo sem rede.
    func sair() async {
        guard estado == .logado, transicao != .saindo else { return }
        transicao = .saindo
        defer { transicao = .nenhuma }
        await BXPushRegistro.remover()
        try? await api.sair()
        await api.esquecerSessao()
        limparLocal()
        estado = .visitante
    }

    /// Depois de trocar a senha, encerrar todas as sessões ou excluir a conta: o servidor já matou os tokens.
    func sessaoRevogada(motivo: String) {
        limparLocal()
        estado = .visitante
        toast?.mostrar(motivo, .info)
    }

    /// O `BXAPI` chama quando a renovação falhou de vez (cofre já limpo).
    private func sessaoExpirou() {
        guard estado == .logado else { return }
        limparLocal()
        estado = .visitante
        toast?.mostrar("Sua sessão expirou. Entre de novo.", .aviso)
    }

    private func limparLocal() {
        Task { await api.esquecerSessao() }
        BXPushRegistro.esquecer()
        BXCacheCarteira.limpar()
        // Restos da versão antiga (exceção nomeada no §0.2.2 da spec).
        TokenStore.clear()
        TokenStore.clearProfile()
        WalletCache.clear()
        usuario = nil
        carteira = nil
        carteiraDoCache = false
        erroCarteira = nil
        naoLidas = 0
    }
}

/// Registro do aparelho para push (D12): só depois do login; removido no sair.
/// O PushService (G1) chama `registrar(token:)` quando recebe o token do APNs e a sessão está logada.
nonisolated enum BXPushRegistro {
    private static let chaveID = "bx_push_dispositivo_id"

    /// POST /push/devices/register e guarda o id para o sair. Em modo demonstração não registra.
    static func registrar(token: String) async {
        guard !BXDemo.ativo, !BXDemo.visitante, await BXAPI.shared.temSessao() else { return }
        if let id = try? await BXAPI.shared.registrarDispositivo(token: token) {
            UserDefaults.standard.set(id, forKey: chaveID)
        }
    }

    /// DELETE /push/devices/<id> (melhor esforço).
    static func remover() async {
        guard let id = UserDefaults.standard.string(forKey: chaveID) else { return }
        try? await BXAPI.shared.removerDispositivo(id: id)
        esquecer()
    }

    static func esquecer() { UserDefaults.standard.removeObject(forKey: chaveID) }
}
