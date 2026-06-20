//
//  API.swift
//  BlaxxPontos
//
//  Cliente HTTP para o backend Flask em 127.0.0.1:5050.
//

import Foundation

// MARK: - DTOs do backend

struct LoginResponse: Decodable {
    let token: String
    let token_type: String
    let user: BlaxxUser
}

struct BlaxxUser: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let cpf: String
    let pix_key: String?
    var email_verified_at: String? = nil   // ISO timestamp ou nil

    // role e is_vip são OPCIONAIS — backend antigo não envia esses campos.
    // Codable do Swift NÃO usa valores default em decode, então se o campo
    // não vier no JSON, o decode falha com keyNotFound. Manter Optional
    // resolve a compatibilidade pra frente e pra trás.
    let role: String?
    let is_vip: Bool?
    // Novos campos da Onda 2 — todos opcionais pela mesma razão:
    let phone: String?
    let avatar_url: String?
    let auth_provider: String?
    let mfa_enabled: Bool?
    let status: String?

    var isEmailVerified: Bool { email_verified_at != nil }
    var isAdmin: Bool { (role ?? "user") == "admin" }
    var isVIP: Bool { is_vip ?? false }
}

// MARK: - Notifications

struct NotificationDTO: Decodable, Identifiable {
    let id: String
    let type: String
    let title: String
    let body: String?
    let icon: String?
    let reference: String?
    let read_at: String?
    let is_read: Bool
    let created_at: String
}

struct NotificationsResponse: Decodable {
    let items: [NotificationDTO]
    let unread_count: Int
}

// MARK: - Partners & Benefits

struct PartnerDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String?
    let logo_emoji: String?
    let accrual_rule: String?
    let city: String?
    let is_active: Bool
}

struct PartnerDetailDTO: Decodable {
    let id: String
    let name: String
    let category: String
    let description: String?
    let logo_emoji: String?
    let accrual_rule: String?
    let benefits: [BenefitDTO]?
}

struct BenefitDTO: Decodable, Identifiable {
    let id: String
    let partner_id: String?
    let partner_name: String?
    let name: String
    let description: String?
    let category: String
    let cost_pts: Int
    let image_emoji: String?
    let stock: Int
    let expires_in_days: Int
    let is_active: Bool
    let tag: String?
}

struct VoucherDTO: Decodable, Identifiable {
    let id: String
    let user_id: String
    let benefit_id: String
    let benefit_name: String?
    let code: String
    let points_spent: Int
    let expires_at: String
    let used_at: String?
    let status: String       // active | used | expired
    let created_at: String
}

struct WalletDTO: Decodable {
    let id: String
    let user_id: String
    let balance_pts: Int
    let pending_pts: Int
    let balance_brl_equiv: Double
}

// MARK: - Cartão Blaxx + níveis (loyalty tiers)

struct TierDTO: Decodable, Identifiable, Hashable {
    let key: String
    let label: String
    let min_points: Int
    let color: String
    let text_color: String
    let perks: String?

    var id: String { key }
}

struct CardStateDTO: Decodable {
    struct Member: Decodable { let id: String; let name: String }
    let member: Member
    let balance_pts: Int
    let lifetime_points: Int
    let tier: TierDTO
    let next_tier: TierDTO?
    let points_to_next: Int
    let progress_pct: Int
    let tiers: [TierDTO]
    let wallet_pass_available: Bool
}

struct TransactionDTO: Decodable, Identifiable {
    let id: String
    let type: String
    let status: String
    let amount_pts: Int
    let description: String
    let reference: String?
    let created_at: String
}

struct TransactionsResponse: Decodable {
    let items: [TransactionDTO]
}

struct PointPackageDTO: Identifiable, Hashable {
    let key: String
    let label: String
    let points: Int
    let price_brl: Double

    var id: String { key }
    var formattedPoints: String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: points)) ?? "\(points)"
    }
    var formattedPrice: String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale(identifier: "pt_BR")
        return nf.string(from: NSNumber(value: price_brl)) ?? "R$ \(price_brl)"
    }
}

struct PixChargeDTO: Decodable {
    let id: String
    let user_id: String
    let package: String
    let amount_brl: Double
    let points_to_credit: Int
    let txid: String
    let br_code: String
    let qr_code_image: String?   // data URI base64 (Mercado Pago) ou nil (Mock)
    let status: String
    let expires_at: String
    let paid_at: String?
}

struct PixProviderInfo: Decodable {
    let name: String
    let is_mock: Bool
}

struct TransferRequest: Encodable {
    let to: String
    let amount_pts: Int
    let message: String?
    let password: String
}

struct TransferResponse: Decodable {
    let id: String
    let sender_id: String
    let recipient_id: String
    let amount_pts: Int
    let message: String?
    let receipt_code: String
    let created_at: String
}

struct RedeemQuoteDTO: Decodable {
    let points: Int
    let amount_brl: Double
    let rate: String
}

struct RedeemRequest: Encodable {
    let points: Int
    let pix_key: String
    let password: String
}

struct RedeemResponse: Decodable {
    let id: String
    let points_debited: Int
    let amount_brl: Double
    let pix_key: String
    let txid: String
    let end_to_end_id: String?
    let status: String
    let failure_reason: String?
    let paid_at: String?
}

// MARK: - Erro de API

struct APIError: Error, LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

extension DecodingError {
    var shortDescription: String {
        switch self {
        case .keyNotFound(let key, _):
            return "campo ausente: '\(key.stringValue)'"
        case .typeMismatch(let type, let ctx):
            return "tipo errado para \(type) em '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))'"
        case .valueNotFound(let type, let ctx):
            return "valor nulo onde esperava \(type) em '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))'"
        case .dataCorrupted(let ctx):
            return "JSON corrompido: \(ctx.debugDescription)"
        @unknown default:
            return "erro de decodificação desconhecido"
        }
    }
}

// MARK: - Cliente HTTP

actor BlaxxAPI {
    static let shared = BlaxxAPI()

    /// Endereço do backend Blaxx Pontos.
    /// Default: produção (Render.com / Oregon). Backend migrou do Fly.io
    /// para o Render em 2026-05 — a URL antiga `blaxx-pontos-backend.fly.dev`
    /// já não responde. Override via UserDefaults("blaxx_backend_url") para
    /// apontar para o Flask local durante desenvolvimento.
    static let defaultBaseURL = "https://blaxx-pontos-exe.onrender.com"

    /// Backoff exponencial com jitter para o retry de GETs.
    /// attempt 1 → ~0,3s, attempt 2 → ~0,6s (+ até 150ms de jitter).
    static func backoffNanos(_ attempt: Int) -> UInt64 {
        let base = 0.3 * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.15)
        return UInt64((base + jitter) * 1_000_000_000)
    }

    private var baseURL: URL {
        let s = UserDefaults.standard.string(forKey: "blaxx_backend_url")
            ?? BlaxxAPI.defaultBaseURL
        return URL(string: s) ?? URL(string: BlaxxAPI.defaultBaseURL)!
    }

    private var token: String? {
        TokenStore.get()
    }

    /// Monta a URL final juntando `baseURL` ao `path`. Aceita path com query
    /// string (`/x/y?foo=1&bar=2`) — concatena raw em string em vez de usar
    /// `appendingPathComponent`, que codifica o `?` como `%3F` e fazia o
    /// backend Flask retornar 404 silencioso em todas as queries com `?`.
    /// Esse era o bug que mantinha o Extrato e o Resgate "vazios" após
    /// compra/venda de pontos.
    private func makeURL(path: String) -> URL {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = path.hasPrefix("/") ? path : "/" + path
        return URL(string: base + suffix) ?? baseURL
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        as type: T.Type
    ) async throws -> T {
        var req = URLRequest(url: makeURL(path: path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body
        // 30s pra tolerar cold start da VM (que pode demorar ~10s pra acordar
        // quando inativa) + alguma latência do banco.
        req.timeoutInterval = 30

        // Retry com backoff SÓ para requests idempotentes (GET). POST de
        // /transfer, /pix/charge e /redeem NÃO pode ser repetido às cegas —
        // o backend não aceita idempotency-key do cliente nesses endpoints,
        // então um retry duplicaria a transação. Por isso POST = 1 tentativa.
        let idempotent = method.uppercased() == "GET"
        let maxAttempts = idempotent ? 3 : 1

        var data = Data()
        var response: URLResponse?
        var attempt = 0
        while true {
            attempt += 1
            do {
                (data, response) = try await URLSession.shared.data(for: req)
            } catch let urlErr as URLError {
                // .cancelled = -999 é normal quando a View é dismissed antes
                // da request terminar (SwiftUI cancela a Task automaticamente).
                // Repropagamos CancellationError para o caller poder ignorar.
                if urlErr.code == .cancelled {
                    throw CancellationError()
                }
                // Erros transitórios: tenta de novo se ainda for idempotente.
                let transient: Set<URLError.Code> = [
                    .timedOut, .networkConnectionLost,
                    .cannotConnectToHost, .cannotFindHost,
                ]
                if transient.contains(urlErr.code) && attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: BlaxxAPI.backoffNanos(attempt))
                    continue
                }
                let hint: String
                switch urlErr.code {
                case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                    hint = "Backend offline. Suba o Flask em outro Terminal: cd backend && python3 run.py"
                case .timedOut:
                    hint = "Tempo esgotado. Verifique se o backend está rodando em \(baseURL.absoluteString)"
                case .notConnectedToInternet:
                    hint = "Sem conexão de rede"
                case .appTransportSecurityRequiresSecureConnection:
                    hint = "ATS bloqueou HTTP. Verifique NSAllowsLocalNetworking no Info.plist"
                default:
                    hint = "URLError \(urlErr.code.rawValue): \(urlErr.localizedDescription)"
                }
                throw APIError(status: -1, message: hint)
            } catch is CancellationError {
                // Propaga sem encapsular: chamadores filtram com `catch is CancellationError`
                throw CancellationError()
            } catch {
                throw APIError(status: -1, message: "Falha de rede: \(error.localizedDescription)")
            }

            // 5xx em request idempotente = provável cold start / instabilidade
            // momentânea do backend: vale repetir com backoff.
            if let http = response as? HTTPURLResponse,
               (500...599).contains(http.statusCode),
               idempotent, attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: BlaxxAPI.backoffNanos(attempt))
                continue
            }
            break
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError(status: 0, message: "Resposta inválida do servidor")
        }
        if !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? "HTTP \(http.statusCode)"
            throw APIError(status: http.statusCode, message: msg)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let decErr as DecodingError {
            throw APIError(status: http.statusCode,
                           message: "Resposta inesperada do backend: \(decErr.shortDescription)")
        }
    }

    // MARK: Auth

    /// Acorda o backend antes de um POST sensível (login/registro).
    ///
    /// O Render free tier hiberna a instância após ~15 min de inatividade; o
    /// primeiro request pode levar 30–60s só pra subir a VM. Como o POST de
    /// /auth/login NÃO faz retry (maxAttempts = 1), esse cold start estourava o
    /// timeout de 30s e o usuário via "Tempo esgotado". Este ping em /health é
    /// idempotente (GET), tem timeout generoso e várias tentativas com backoff,
    /// então absorve o cold start. É best-effort: se mesmo assim não acordar,
    /// o login seguinte segue e reporta o erro real normalmente.
    func warmUp() async {
        var req = URLRequest(url: makeURL(path: "/health"))
        req.httpMethod = "GET"
        req.timeoutInterval = 60
        req.cachePolicy = .reloadIgnoringLocalCacheData
        for attempt in 1...4 {
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 { return }
            } catch is CancellationError {
                return
            } catch {
                // Erro transitório (timeout durante boot): tenta de novo.
            }
            if attempt < 4 {
                try? await Task.sleep(nanoseconds: BlaxxAPI.backoffNanos(attempt))
            }
        }
    }

    func login(emailOrCPF: String, password: String) async throws -> LoginResponse {
        let body = try JSONEncoder().encode(["email": emailOrCPF, "password": password])
        return try await request(path: "/auth/login", method: "POST", body: body, as: LoginResponse.self)
    }

    /// Cadastra novo usuário e devolve token (auto-login no backend).
    func register(name: String, email: String, cpf: String,
                  password: String, pixKey: String? = nil) async throws -> LoginResponse {
        var payload: [String: String] = [
            "name": name,
            "email": email,
            "cpf": cpf,
            "password": password,
        ]
        if let pixKey, !pixKey.isEmpty { payload["pix_key"] = pixKey }
        let body = try JSONEncoder().encode(payload)
        return try await request(path: "/auth/register", method: "POST",
                                 body: body, as: LoginResponse.self)
    }

    func me() async throws -> BlaxxUser {
        try await request(path: "/auth/me", as: BlaxxUser.self)
    }

    /// Faz login no Blaxx usando um ID token JWT vindo do Google.
    /// Backend valida assinatura + audience + nonce e devolve JWT + user.
    /// Se for primeiro login Google, cria User + Wallet automaticamente.
    /// Nonce: anti-replay — gerado por GoogleAuthService.signIn() e validado
    /// pelo backend contra payload.nonce do id_token.
    func loginWithGoogle(idToken: String, nonce: String? = nil) async throws -> LoginResponse {
        var payload: [String: String] = ["id_token": idToken]
        if let nonce, !nonce.isEmpty { payload["nonce"] = nonce }
        let body = try JSONEncoder().encode(payload)
        return try await request(path: "/auth/google", method: "POST",
                                 body: body, as: LoginResponse.self)
    }

    // MARK: Auth · Onda 1

    struct OKResponse: Decodable { let ok: Bool? ; let revoked: Bool? }

    /// Revoga o JWT atual no backend (blacklist).
    func logout() async throws {
        _ = try await request(path: "/auth/logout", method: "POST",
                              body: Data("{}".utf8), as: OKResponse.self)
    }

    /// Pede e-mail de recuperação. Sempre 200 (anti-enumeração).
    func forgotPassword(email: String) async throws {
        let body = try JSONEncoder().encode(["email": email])
        _ = try await request(path: "/auth/forgot-password", method: "POST",
                              body: body, as: OKResponse.self)
    }

    /// Aplica nova senha usando token recebido por e-mail.
    func resetPassword(token: String, newPassword: String) async throws {
        let body = try JSONEncoder().encode(["token": token, "password": newPassword])
        _ = try await request(path: "/auth/reset-password", method: "POST",
                              body: body, as: OKResponse.self)
    }

    /// Troca senha estando logado. Exige senha atual.
    func changePassword(oldPassword: String, newPassword: String) async throws {
        let body = try JSONEncoder().encode([
            "old_password": oldPassword,
            "new_password": newPassword,
        ])
        _ = try await request(path: "/auth/change-password", method: "POST",
                              body: body, as: OKResponse.self)
    }

    /// Resposta de /auth/verify-email/send.
    ///
    /// Quando o backend roda com `MAILER=console` (modo dev — Render free tier
    /// sem provider de email real), ele devolve o código direto no campo
    /// `_dev_code` pra desbloquear teste sem precisar abrir Render Dashboard
    /// pra pegar do log. Em produção (MAILER=resend), esse campo é nil.
    ///
    /// `delivered` reflete o retorno do provider — `false` indica que o backend
    /// tentou enviar mas o Resend (ou similar) reportou falha (ex.: API key
    /// inválida, dominio não verificado). Útil pra mostrar warning no app.
    struct VerifySendResponse: Decodable {
        let ok: Bool?
        let expires_in_min: Int?
        let delivered: Bool?
        let _dev_code: String?
        let _dev_warning: String?
    }

    /// Reenvia código de 6 dígitos para confirmar e-mail.
    /// Em modo dev (MAILER=console), a resposta inclui `_dev_code` —
    /// frontend usa para auto-preencher e auto-submit, evitando precisar
    /// abrir Render Logs.
    func resendEmailVerification() async throws -> VerifySendResponse {
        return try await request(path: "/auth/verify-email/send", method: "POST",
                                 body: Data("{}".utf8), as: VerifySendResponse.self)
    }

    /// Confirma o e-mail enviando o código.
    func verifyEmail(code: String) async throws -> OKResponse {
        let body = try JSONEncoder().encode(["code": code])
        return try await request(path: "/auth/verify-email", method: "POST",
                                  body: body, as: OKResponse.self)
    }

    // MARK: Notifications

    func notifications() async throws -> NotificationsResponse {
        try await request(path: "/notifications/", as: NotificationsResponse.self)
    }

    func markNotificationRead(_ id: String) async throws {
        _ = try await request(path: "/notifications/\(id)/read", method: "PATCH",
                              body: nil, as: NotificationDTO.self)
    }

    struct ReadAllResponse: Decodable { let updated: Int }
    func markAllNotificationsRead() async throws {
        _ = try await request(path: "/notifications/read-all", method: "POST",
                              body: Data("{}".utf8), as: ReadAllResponse.self)
    }

    // MARK: Partners

    struct PartnersResponse: Decodable { let items: [PartnerDTO] }

    func partners(category: String? = nil) async throws -> [PartnerDTO] {
        var path = "/partners/"
        if let c = category, !c.isEmpty {
            let safe = c.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? c
            path += "?category=\(safe)"
        }
        let r = try await request(path: path, as: PartnersResponse.self)
        return r.items
    }

    struct CategoriesResponse: Decodable { let items: [String] }

    func partnerCategories() async throws -> [String] {
        let r = try await request(path: "/partners/categories", as: CategoriesResponse.self)
        return r.items
    }

    func partner(_ id: String) async throws -> PartnerDetailDTO {
        try await request(path: "/partners/\(id)", as: PartnerDetailDTO.self)
    }

    // MARK: Benefits & Vouchers

    struct BenefitsResponse: Decodable { let items: [BenefitDTO] }

    func benefits() async throws -> [BenefitDTO] {
        let r = try await request(path: "/benefits/", as: BenefitsResponse.self)
        return r.items
    }

    func benefit(_ id: String) async throws -> BenefitDTO {
        try await request(path: "/benefits/\(id)", as: BenefitDTO.self)
    }

    func redeemBenefit(_ id: String) async throws -> VoucherDTO {
        _ = id  // path interpola abaixo
        let body = Data("{}".utf8)
        return try await request(path: "/benefits/\(id)/redeem", method: "POST",
                                  body: body, as: VoucherDTO.self)
    }

    struct VouchersResponse: Decodable { let items: [VoucherDTO] }

    func myVouchers() async throws -> [VoucherDTO] {
        let r = try await request(path: "/vouchers/", as: VouchersResponse.self)
        return r.items
    }

    // MARK: Carteira

    func wallet() async throws -> WalletDTO {
        try await request(path: "/wallet/", as: WalletDTO.self)
    }

    func transactions(limit: Int = 50) async throws -> [TransactionDTO] {
        let r = try await request(path: "/wallet/transactions?limit=\(limit)", as: TransactionsResponse.self)
        return r.items
    }

    // MARK: Cartão Blaxx + níveis + Apple Wallet

    /// Estado do cartão: saldo, lifetime, nível atual, progresso e os 4 níveis.
    func card() async throws -> CardStateDTO {
        try await request(path: "/card/", as: CardStateDTO.self)
    }

    /// Catálogo público dos níveis (sem dados do usuário).
    func tiers() async throws -> [TierDTO] {
        struct Resp: Decodable { let tiers: [TierDTO] }
        return (try await request(path: "/card/tiers", as: Resp.self)).tiers
    }

    /// Baixa o .pkpass assinado (Apple Wallet). Lança APIError(503) quando o
    /// Wallet ainda não está configurado no servidor — a UI usa pra mostrar
    /// "em breve". Retorna os bytes crus do pacote .pkpass.
    func walletPass() async throws -> Data {
        var req = URLRequest(url: makeURL(path: "/card/pass"))
        req.httpMethod = "GET"
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(status: 0, message: "Resposta inválida do servidor")
        }
        if !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? "HTTP \(http.statusCode)"
            throw APIError(status: http.statusCode, message: msg)
        }
        return data
    }

    // MARK: PIX (compra)

    func packages() async throws -> [PointPackageDTO] {
        // O backend devolve um dict {key: {label, points, price_brl}} — convertemos para array.
        var req = URLRequest(url: makeURL(path: "/pix/packages"))
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return []
        }
        let preferredOrder = ["start", "plus", "prime", "black"]
        return dict
            .map { (key, v) -> PointPackageDTO in
                PointPackageDTO(
                    key: key,
                    label: v["label"] as? String ?? key.capitalized,
                    points: v["points"] as? Int ?? 0,
                    price_brl: (v["price_brl"] as? Double) ?? Double(v["price_brl"] as? Int ?? 0)
                )
            }
            .sorted { a, b in
                let ia = preferredOrder.firstIndex(of: a.key) ?? .max
                let ib = preferredOrder.firstIndex(of: b.key) ?? .max
                return ia < ib
            }
    }

    func createCharge(package: String) async throws -> PixChargeDTO {
        let body = try JSONEncoder().encode(["package": package])
        return try await request(path: "/pix/charge", method: "POST", body: body, as: PixChargeDTO.self)
    }

    /// Cria charge MP com valor livre (não-pacote). Backend integra com Mercado
    /// Pago e devolve QR Code real + BR Code copia-e-cola. Confirmação automática
    /// via webhook MP → cliente faz polling em GET /pix/charge/<id>.
    func createCharge(amountBRL: Double) async throws -> PixChargeDTO {
        struct Body: Encodable { let amount_brl: Double }
        let body = try JSONEncoder().encode(Body(amount_brl: amountBRL))
        return try await request(path: "/pix/charge", method: "POST", body: body, as: PixChargeDTO.self)
    }

    /// Consulta status de uma charge. Usado pelo polling pós-criação pra
    /// detectar confirmação automática via webhook MP.
    func getCharge(id: String) async throws -> PixChargeDTO {
        return try await request(path: "/pix/charge/\(id)", as: PixChargeDTO.self)
    }

    func providerInfo() async throws -> PixProviderInfo {
        try await request(path: "/pix/provider", as: PixProviderInfo.self)
    }

    func simulatePayment(chargeId: String) async throws {
        struct SimResponse: Decodable { let ok: Bool }
        let body = try JSONEncoder().encode(["charge_id": chargeId])
        _ = try await request(path: "/pix/simulate-payment", method: "POST", body: body, as: SimResponse.self)
    }

    // MARK: Envio P2P

    func transfer(to: String, amountPts: Int, message: String?, password: String) async throws -> TransferResponse {
        let body = try JSONEncoder().encode(TransferRequest(to: to, amount_pts: amountPts, message: message, password: password))
        return try await request(path: "/transfer/", method: "POST", body: body, as: TransferResponse.self)
    }

    // MARK: Resgate

    func redeemQuote(points: Int) async throws -> RedeemQuoteDTO {
        try await request(path: "/redeem/quote?points=\(points)", as: RedeemQuoteDTO.self)
    }

    func redeem(points: Int, pixKey: String, password: String) async throws -> RedeemResponse {
        let body = try JSONEncoder().encode(RedeemRequest(points: points, pix_key: pixKey, password: password))
        return try await request(path: "/redeem/", method: "POST", body: body, as: RedeemResponse.self)
    }

    // MARK: - Admin

    func adminStats() async throws -> AdminStatsDTO {
        try await request(path: "/admin/stats", as: AdminStatsDTO.self)
    }

    func adminListUsers(query: String = "", role: String = "", vip: String = "",
                       limit: Int = 50, offset: Int = 0) async throws -> AdminUsersResponse {
        var parts = ["limit=\(limit)", "offset=\(offset)"]
        if !query.isEmpty {
            let safe = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            parts.append("q=\(safe)")
        }
        if !role.isEmpty { parts.append("role=\(role)") }
        if !vip.isEmpty { parts.append("vip=\(vip)") }
        return try await request(path: "/admin/users?\(parts.joined(separator: "&"))",
                                 as: AdminUsersResponse.self)
    }

    func adminGetUser(_ id: String) async throws -> AdminUserDetailDTO {
        try await request(path: "/admin/users/\(id)", as: AdminUserDetailDTO.self)
    }

    struct AdminVipResponse: Decodable { let id: String; let is_vip: Bool }

    /// Toggle VIP. Se isVip for nil, alterna; senão seta o valor.
    func adminSetVip(_ userId: String, isVip: Bool? = nil) async throws -> Bool {
        var bodyDict: [String: Bool] = [:]
        if let v = isVip { bodyDict["is_vip"] = v }
        let body = try JSONEncoder().encode(bodyDict)
        let r = try await request(path: "/admin/users/\(userId)/vip", method: "PATCH",
                                  body: body, as: AdminVipResponse.self)
        return r.is_vip
    }

    struct AdminRoleResponse: Decodable { let id: String; let role: String }
    func adminSetRole(_ userId: String, role: String) async throws -> String {
        let body = try JSONEncoder().encode(["role": role])
        let r = try await request(path: "/admin/users/\(userId)/role", method: "PATCH",
                                  body: body, as: AdminRoleResponse.self)
        return r.role
    }

    func adminTransactions(type: String = "", userId: String = "",
                          limit: Int = 100, offset: Int = 0) async throws -> AdminTransactionsResponse {
        var parts = ["limit=\(limit)", "offset=\(offset)"]
        if !type.isEmpty { parts.append("type=\(type)") }
        if !userId.isEmpty { parts.append("user_id=\(userId)") }
        return try await request(path: "/admin/transactions?\(parts.joined(separator: "&"))",
                                 as: AdminTransactionsResponse.self)
    }

    // MARK: - PIX manual (QR estático + valor livre)

    /// Cria charge com valor livre. Backend retorna info pra mostrar QR + valor exato.
    func createCustomCharge(amountBRL: Double) async throws -> CustomChargeDTO {
        let body = try JSONEncoder().encode(["amount_brl": amountBRL])
        return try await request(path: "/pix/custom-charge", method: "POST",
                                 body: body, as: CustomChargeDTO.self)
    }

    /// Cliente avisa que pagou → admin precisa confirmar.
    func claimChargePaid(chargeId: String) async throws {
        struct OK: Decodable { let ok: Bool? ; let status: String? }
        _ = try await request(path: "/pix/custom-charge/\(chargeId)/claim-paid",
                              method: "POST", body: Data("{}".utf8), as: OK.self)
    }

    func myCharges() async throws -> [PixChargeDTO] {
        struct Resp: Decodable { let items: [PixChargeDTO] }
        return (try await request(path: "/pix/my-charges", as: Resp.self)).items
    }

    // Admin (charges pendentes)
    struct PendingChargesResponse: Decodable {
        let items: [AdminPendingChargeDTO]
        let total: Int
    }
    func adminPendingCharges() async throws -> PendingChargesResponse {
        try await request(path: "/admin/charges/pending", as: PendingChargesResponse.self)
    }

    func adminConfirmCharge(_ chargeId: String) async throws {
        struct OK: Decodable { let ok: Bool? }
        _ = try await request(path: "/admin/charges/\(chargeId)/confirm", method: "POST",
                              body: Data("{}".utf8), as: OK.self)
    }

    func adminRejectCharge(_ chargeId: String, reason: String) async throws {
        struct OK: Decodable { let ok: Bool? }
        let body = try JSONEncoder().encode(["reason": reason])
        _ = try await request(path: "/admin/charges/\(chargeId)/reject", method: "POST",
                              body: body, as: OK.self)
    }
}

// MARK: - PIX manual DTOs

struct CustomChargeDTO: Decodable {
    let id: String
    let user_id: String
    let amount_brl: Double
    let points_to_credit: Int
    let txid: String
    let br_code: String
    let qr_code_image: String?
    let qr_image_url: String?      // path no servidor pro PNG estático
    let status: String
    let flow: String?
    let expires_at: String
    let instructions: String?
}

struct AdminPendingChargeDTO: Decodable, Identifiable {
    let id: String
    let user_id: String
    let user_name: String?
    let user_email: String?
    let amount_brl: Double
    let points_to_credit: Int
    let status: String
    let claimed_paid_at: String?
    let created_at: String?
}

// MARK: - Admin DTOs

struct AdminStatsDTO: Decodable {
    let total_users: Int
    let total_admins: Int
    let total_vips: Int
    let email_verified_users: Int
    let total_balance_pts: Int
    let volume_last_30d_by_type: [String: Int]
}

struct AdminUserDTO: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let cpf: String?
    let pix_key: String?
    let role: String
    let is_vip: Bool
    let email_verified: Bool
    let email_verified_at: String?
    let created_at: String?
    let password_changed_at: String?
    let google_linked: Bool
    let balance_pts: Int

    var isAdmin: Bool { role == "admin" }
}

struct AdminUsersResponse: Decodable {
    let total: Int
    let limit: Int
    let offset: Int
    let items: [AdminUserDTO]
}

struct AdminUserDetailDTO: Decodable {
    let id: String
    let name: String
    let email: String
    let cpf: String?
    let role: String
    let is_vip: Bool
    let email_verified: Bool
    let balance_pts: Int
    let recent_transactions: [TransactionDTO]?
}

struct AdminTransactionDTO: Decodable, Identifiable {
    let id: String
    let type: String
    let status: String
    let amount_pts: Int
    let description: String
    let reference: String?
    let created_at: String
    let user_name: String?
    let user_email: String?
}

struct AdminTransactionsResponse: Decodable {
    let total: Int
    let limit: Int
    let offset: Int
    let items: [AdminTransactionDTO]
}
