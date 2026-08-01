//
//  Session.swift
//  BlaxxPontos
//
//  Estado de autenticação observável (Observation framework / Swift 5.9+).
//

import Foundation
import SwiftUI
import Observation

@Observable
final class Session {
    var user: BlaxxUser?
    var isLoading: Bool = false
    var lastError: String?

    /// Contador incrementado sempre que alguma operação altera saldo/extrato
    /// (compra, envio, resgate, recebimento). Views que mostram carteira ou
    /// extrato observam este valor via `.task(id: session.walletReloadTrigger)`
    /// para recarregar automaticamente quando a fonte de verdade muda.
    var walletReloadTrigger: Int = 0

    var isAuthenticated: Bool { user != nil }

    /// Sinaliza às views de carteira/extrato/dashboard para recarregarem do backend.
    /// Chame após qualquer operação que crie Transaction (compra, envio, resgate).
    func bumpWalletReload() {
        walletReloadTrigger &+= 1
    }

    init() {
        // Migra token legado (UserDefaults) para o Keychain, se existir.
        TokenStore.migrateFromUserDefaultsIfNeeded()
        // Restaura sessão: token e perfil ficam no Keychain.
        if let token = TokenStore.get(),
           !token.isEmpty,
           let data = TokenStore.getProfileData(),
           let user = try? JSONDecoder().decode(BlaxxUser.self, from: data) {
            self.user = user
        }
    }

    func login(emailOrCPF: String, password: String) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            // Acorda o backend (Render hiberna após inatividade) antes do POST
            // de login, que não tem retry e estourava o timeout no cold start.
            await BlaxxAPI.shared.warmUp()
            let resp = try await BlaxxAPI.shared.login(emailOrCPF: emailOrCPF, password: password)
            persist(resp)
        } catch {
            lastError = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    /// Faz login via Google: abre OAuth, troca id_token por JWT Blaxx.
    /// Cria conta automaticamente se for primeiro login Google deste e-mail.
    /// Devolve true em sucesso. lastError é setado em falha.
    @MainActor
    func loginWithGoogle() async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let result = try await GoogleAuthService.shared.signIn()
            let resp = try await BlaxxAPI.shared.loginWithGoogle(
                idToken: result.idToken,
                nonce: result.nonce
            )
            persist(resp)
            return true
        } catch GoogleAuthError.userCancelled {
            // Cancelamento não é erro — não mostra mensagem ofensiva.
            return false
        } catch let e as GoogleAuthError {
            lastError = e.errorDescription ?? "Falha no Google Sign-In"
            return false
        } catch let apiErr as APIError {
            lastError = Self.friendlyGoogleError(apiErr)
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Traduz erros crus do backend no login Google para mensagens amigáveis.
    /// O usuário não deve ver jargão técnico (ex.: "Token Google inválido ou
    /// expirado") que sugere falha na conta dele, quando geralmente é
    /// configuração do servidor (GOOGLE_IOS_CLIENT_ID ausente) ou algo
    /// transitório.
    static func friendlyGoogleError(_ err: APIError) -> String {
        let raw = err.message
        switch raw {
        case "Token Google inválido ou expirado",
             "issuer inválido",
             "Token Google sem sub ou email":
            return "Não foi possível entrar com o Google agora. "
                 + "Tente novamente ou use e-mail e senha."
        case "Google Sign-In não está configurado neste servidor":
            return "Login com Google está temporariamente indisponível. "
                 + "Use e-mail e senha por enquanto."
        case "nonce inválido — possível replay":
            return "A sessão de login expirou. Toque em "
                 + "\"Continuar com Google\" novamente."
        case "Sua conta Google não tem e-mail verificado":
            return "Sua conta Google precisa ter o e-mail verificado "
                 + "para entrar no Blaxx."
        default:
            // 5xx / cold start do Render / rede: mensagem genérica calma.
            if err.status >= 500 || err.status < 0 {
                return "Serviço indisponível no momento. "
                     + "Tente novamente em alguns instantes."
            }
            return raw
        }
    }

    /// Cria nova conta e já faz login (backend devolve token no /auth/register).
    func register(name: String, email: String, cpf: String,
                  password: String, pixKey: String? = nil) async -> Bool {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            // Mesma proteção de cold start do login: o POST de /auth/register
            // também não faz retry.
            await BlaxxAPI.shared.warmUp()
            let resp = try await BlaxxAPI.shared.register(
                name: name, email: email, cpf: cpf,
                password: password, pixKey: pixKey
            )
            persist(resp)
            return true
        } catch {
            lastError = (error as? APIError)?.message ?? error.localizedDescription
            return false
        }
    }

    private func persist(_ resp: LoginResponse) {
        TokenStore.set(resp.token)
        if let userData = try? JSONEncoder().encode(resp.user) {
            TokenStore.setProfile(userData)
        }
        user = resp.user
    }

    /// Logout local + revoga token no backend (best-effort).
    /// Mesmo se o backend estiver offline, sai localmente.
    func logout() {
        Task { try? await BlaxxAPI.shared.logout() }
        TokenStore.clear()
        TokenStore.clearProfile()
        WalletCache.clear()
        user = nil
    }

    /// Atualiza o usuário em memória após mudança (verify email, etc).
    func refreshUser() async {
        guard isAuthenticated else { return }
        do {
            let u = try await BlaxxAPI.shared.me()
            user = u
            if let data = try? JSONEncoder().encode(u) {
                TokenStore.setProfile(data)
            }
        } catch { /* offline OK */ }
    }
}
