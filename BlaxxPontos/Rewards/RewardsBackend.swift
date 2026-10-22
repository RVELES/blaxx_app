//
//  RewardsBackend.swift
//  BlaxxPontos
//
//  Live-data session that sits BEHIND the mock Rewards experience. It silently
//  logs in with a homologação demo account and exposes the REAL wallet so the
//  financial sheets (Comprar / Vender / Enviar) can operate against the backend
//  at https://blaxx-pontos-exe.onrender.com.
//
//  The mock airline-exchange world (hero, programs, Trocar) is never blocked on
//  this: if the silent login fails (account missing / offline / cold start) then
//  `ready` stays false, `wallet` stays nil, and every screen keeps showing its
//  mock data. Real wiring is purely additive.
//
//  ⚠️ HOMOLOGAÇÃO: as credenciais abaixo são de uma conta DEMO fictícia, criada
//  exclusivamente para o ambiente de homologação. Nunca usar usuários, senhas ou
//  CPFs reais. O backend só deve conter dados fictícios.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class RewardsBackend {
    /// True once the silent login + wallet load succeed.
    private(set) var ready = false
    /// The logged-in user, or nil until the silent login completes.
    private(set) var user: BlaxxUser?
    /// The real wallet, or nil until the silent login completes.
    private(set) var wallet: WalletDTO?
    /// False on a fresh account → transfer/redeem return 403 EMAIL_NOT_VERIFIED.
    private(set) var emailVerified = false

    /// PIX key registered on the demo account — used as the redeem destination
    /// (mirrors the Android flow, which lets the backend fall back to it).
    private var demoPixKey: String?

    /// The real points balance, or nil until the silent login + wallet load.
    var balancePts: Int? { wallet?.balance_pts }

    /// BlaXx Card ID: first 8 hex chars of user.id, uppercased (e.g. "CE4910D0").
    var cardId: String? {
        guard let id = user?.id, id.count >= 8 else { return nil }
        return String(id.prefix(8)).uppercased()
    }

    /// Formatted for display: "CE49 10D0".
    var cardIdFormatted: String? {
        guard let c = cardId else { return nil }
        return "\(c.prefix(4)) \(c.suffix(4))"
    }

    /// Performs the silent login (idempotent) and loads the real wallet.
    ///
    /// Em DEBUG, faz o login silencioso usando a conta demo de homologação.
    /// Em RELEASE, NÃO faz login silencioso — exige login manual do usuário,
    /// que será preenchido por outro caminho (LoginView). `ready` permanece
    /// false até existir token válido emitido por login real.
    func start() async {
        // Seed inicial: usa o último wallet conhecido (cache de 1h) para
        // que a UI tenha algo pra mostrar imediatamente, mesmo antes da
        // request real terminar (ou sem rede).
        if wallet == nil, let cached = WalletCache.read() {
            wallet = cached
        }
        #if DEBUG
        do {
            let existing = TokenStore.get()
            if existing == nil || existing?.isEmpty == true {
                await BlaxxAPI.shared.warmUp()
                let resp = try await BlaxxAPI.shared.login(
                    emailOrCPF: Self.demoEmail, password: Self.demoPassword)
                TokenStore.set(resp.token)
                user = resp.user
                emailVerified = resp.user.email_verified_at != nil
                demoPixKey = resp.user.pix_key
            } else if let me = try? await BlaxxAPI.shared.me() {
                user = me
                emailVerified = me.email_verified_at != nil
                demoPixKey = me.pix_key
            }
            // Homologação: auto-verifica e-mail se ainda não confirmado
            if !emailVerified {
                if let _ = try? await BlaxxAPI.shared.devVerifyEmail() {
                    emailVerified = true
                }
            }
            await refresh()
            ready = true
        } catch {
            // Stay on mock data; the experience never breaks on a network failure.
            ready = false
        }
        #else
        // Release: só tenta usar token já existente (login manual prévio).
        // Sem token = `ready` falso → telas seguem em modo mock até o usuário
        // se autenticar manualmente.
        let existing = TokenStore.get()
        guard let t = existing, !t.isEmpty else {
            ready = false
            return
        }
        if let me = try? await BlaxxAPI.shared.me() {
            user = me
            emailVerified = me.email_verified_at != nil
            demoPixKey = me.pix_key
            await refresh()
            ready = true
        } else {
            ready = false
        }
        #endif
    }

    /// Re-reads the wallet after a successful operation.
    func refresh() async {
        if let fresh = try? await BlaxxAPI.shared.wallet() {
            wallet = fresh
            WalletCache.write(fresh)
        }
        // Em falha: mantém o `wallet` atual (do cache ou anterior) — UI
        // nunca vai a branco por causa de offline transitório.
    }

    /// Re-lê o usuário do backend e atualiza o estado de verificação de
    /// e-mail. Chamado após o usuário confirmar o código no gate de
    /// verificação para liberar o uso do app.
    func refreshUserAndEmailStatus() async {
        if let me = try? await BlaxxAPI.shared.me() {
            user = me
            emailVerified = me.email_verified_at != nil
            demoPixKey = me.pix_key
        }
    }

    // ----- Transactional passthroughs (callers catch APIError) ------------ //

    func packages() async throws -> [PointPackageDTO] {
        try await BlaxxAPI.shared.packages()
    }

    func createCharge(package: String) async throws -> PixChargeDTO {
        try await BlaxxAPI.shared.createCharge(package: package)
    }

    func createCharge(amountBRL: Double) async throws -> PixChargeDTO {
        try await BlaxxAPI.shared.createCharge(amountBRL: amountBRL)
    }

    func getCharge(id: String) async throws -> PixChargeDTO {
        try await BlaxxAPI.shared.getCharge(id: id)
    }

    /// Qual gateway de PIX o backend está usando e se ele é o mock.
    /// A afordância de "Simular pagamento" depende disto: `simulate-payment`
    /// só existe com provider mock **e** fora de produção (`api/pix.py:311-330`).
    func providerInfo() async throws -> PixProviderInfo {
        try await BlaxxAPI.shared.providerInfo()
    }

    /// Homologação: confirms the PIX charge without a real bank transfer.
    func simulatePayment(chargeId: String) async throws {
        try await BlaxxAPI.shared.simulatePayment(chargeId: chargeId)
    }

    func redeemQuote(points: Int) async throws -> RedeemQuoteDTO {
        try await BlaxxAPI.shared.redeemQuote(points: points)
    }

    /// Cashback: the demo password + the account's registered PIX key are
    /// supplied internally (mock login gate, no password prompt).
    func redeem(points: Int) async throws -> RedeemResponse {
        #if DEBUG
        return try await BlaxxAPI.shared.redeem(
            points: points, pixKey: demoPixKey ?? Self.demoEmail, password: Self.demoPassword)
        #else
        // Em release ainda não há captura de senha por aqui — bloqueia até a
        // UI ser ampliada para pedir senha real do usuário.
        throw APIError(status: -1, message: "Operação indisponível nesta build.")
        #endif
    }

    /// P2P transfer: the demo password is supplied internally.
    func transfer(to recipient: String, amountPts: Int, message: String?) async throws -> TransferResponse {
        #if DEBUG
        return try await BlaxxAPI.shared.transfer(
            to: recipient, amountPts: amountPts, message: message, password: Self.demoPassword)
        #else
        throw APIError(status: -1, message: "Operação indisponível nesta build.")
        #endif
    }

    // ----- Área logada: paridade com o menu do PWA ------------------------ //
    //
    // Os itens abaixo cobrem `MENU_LOGADO` de `blaxx/assets/blaxx-nav.js`
    // (Conta · Pontos · Descobrir · Ajuda), menos a troca entre programas.
    // Todos são passthrough: quem chama trata `APIError`.

    /// Extrato (`extrato.html`).
    func transactions(limit: Int = 50) async throws -> [TransactionDTO] {
        try await BlaxxAPI.shared.transactions(limit: limit)
    }

    /// Cartão BlaXx: nível, progresso e catálogo de níveis (`cartao.html`).
    func card() async throws -> CardStateDTO {
        try await BlaxxAPI.shared.card()
    }

    /// Notificações (`central-notificacoes.html`).
    func notifications() async throws -> [NotificationDTO] {
        try await BlaxxAPI.shared.notifications().items
    }

    func markNotificationRead(_ id: String) async throws {
        try await BlaxxAPI.shared.markNotificationRead(id)
    }

    func markAllNotificationsRead() async throws {
        try await BlaxxAPI.shared.markAllNotificationsRead()
    }

    /// Campanhas (`campanhas.html`).
    func campaigns() async throws -> [CampaignDTO] {
        try await BlaxxAPI.shared.campaigns()
    }

    func joinCampaign(_ id: String) async throws {
        try await BlaxxAPI.shared.joinCampaign(id)
    }

    /// Catálogo de resgate com pontos e vouchers do usuário (`resgates.html`).
    func benefits() async throws -> [BenefitDTO] {
        try await BlaxxAPI.shared.benefits()
    }

    func vouchers() async throws -> [VoucherDTO] {
        try await BlaxxAPI.shared.myVouchers()
    }

    func redeemBenefit(_ id: String) async throws -> VoucherDTO {
        try await BlaxxAPI.shared.redeemBenefit(id)
    }

    /// Troca de senha (`seguranca.html`).
    func changePassword(current: String, new: String) async throws {
        try await BlaxxAPI.shared.changePassword(oldPassword: current, newPassword: new)
    }

    /// Exclusão de conta (`excluir-conta.html`). Irreversível no backend.
    func deleteAccount(password: String) async throws {
        try await BlaxxAPI.shared.deleteAccount(password: password)
        signOut()
    }

    /// Encerra a sessão local. Não derruba a experiência: o shell volta ao
    /// gate de login e os dados reais somem da tela.
    func signOut() {
        TokenStore.clear()
        user = nil
        wallet = nil
        emailVerified = false
        ready = false
    }

    #if DEBUG
    /// Homologação demo account (fictitious). Never a real credential.
    /// Disponível apenas em DEBUG — em release o login silencioso é desativado.
    static let demoEmail = "rewards.demo@blaxx.app"
    static let demoPassword = "K7m#qP2vR9wL!"
    #endif
}
