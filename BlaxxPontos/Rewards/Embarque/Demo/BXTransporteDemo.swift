//
//  BXTransporteDemo.swift
//  BlaxxPontos · Modo demonstração "Embarque" (§4.2 da spec) · SÓ DEBUG
//
//  Transporte falso do `BXAPI` com `-BXDemo` / `-BXDemoVisitante`: NUNCA abre conexão. Responde com os
//  dados de BXDemoDados no formato exato do backend e guarda estado em memória para os fluxos funcionarem
//  nas fotos: compra paga credita o saldo; envio tira do saldo e põe em "em processamento", "Desfazer"
//  devolve, depois de 60 s efetiva; resgate cria voucher e debita; marcar como lida zera a bolinha;
//  participar muda a campanha. Rota sem resposta definida → 404 local (e log).
//
//  `-BXDemoEstado`: carregando (nunca termina) · vazio (listas vazias) · erro (500; a compra devolve o
//  400 do provedor PIX fora) · offline (falha de rede) · pixIndisponivel (só a compra falha).
//  /auth/me e /auth/refresh respondem em todos os estados (o usuário não muda).
//
//  Contas de exemplo do login (qualquer senha não vazia; "errada" recusa):
//    2fa@exemplo.test → SMS (código 123456) · totp@exemplo.test → código do app (123456)
//    bloqueado@exemplo.test → 423 · existe@exemplo.test (cadastro) → 409 · senha "fraca" → política
//  Envio: destinatário amigo@exemplo.test ou AB12CD34; repetido@exemplo.test → 409; ≥ 20.000 pts → 2FA.
//

#if DEBUG
import Foundation

actor BXTransporteDemo: BXTransporte {
    nonisolated static let shared = BXTransporteDemo()

    private let estadoForcado = BXDemo.estado
    private var saldo = BXDemoDados.saldoInicial
    private var pendente = BXDemoDados.pendenteInicial
    private var emailVerificado = !BXDemo.emailPendente
    private var mfaAtivo = false
    private var lancamentos = BXDemoDados.lancamentos()
    private var notificacoes = BXDemoDados.notificacoes()
    private var vouchers = BXDemoDados.vouchers()
    private var campanhas = BXDemoDados.campanhas()
    private var sessoes = BXDemoDados.sessoes()
    private var consentimentos = BXDemoDados.consentimentos()
    private var cobrancas: [[String: Any]] = BXDemoDados.historicoCobrancas()
    private var consultasCobranca: [String: Int] = [:]
    private var envios: [String: (dados: [String: Any], pontos: Int, efetiva: Date)] = [:]
    private var respostasIdempotentes: [String: Data] = [:]
    private var contador = 0

    private var listasVazias: Bool { estadoForcado == "vazio" }

    // MARK: - Entrada

    func executar(_ r: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = r.url ?? URL(string: "demo://")!
        var caminho = url.path
        while caminho.count > 1 && caminho.hasSuffix("/") { caminho.removeLast() }
        let metodo = (r.httpMethod ?? "GET").uppercased()
        let consulta = Dictionary(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { a, _ in a })
        let corpo = (r.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
        let bearer = r.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
        let chave = r.value(forHTTPHeaderField: "Idempotency-Key")

        // Estados forçados (o usuário e a renovação não mudam).
        let sempreResponde = caminho == "/auth/me" || caminho == "/auth/refresh"
        if !sempreResponde {
            switch estadoForcado {
            case "offline":
                try await Task.sleep(for: .milliseconds(200))
                throw URLError(.notConnectedToInternet)
            case "carregando":
                try await Task.sleep(for: .seconds(3_600))
            default: break
            }
        }
        try await Task.sleep(for: .milliseconds(caminho == "/health" ? 30 : 140))

        if (estadoForcado == "erro" || estadoForcado == "pixIndisponivel"), metodo == "POST", caminho == "/pix/charge" {
            return responder(r, 400, ["error": "Não foi possível gerar a cobrança PIX agora. Tente de novo em alguns minutos."])
        }
        if estadoForcado == "erro", !sempreResponde, caminho != "/health", !caminho.hasPrefix("/auth/") {
            return responder(r, 500, ["error": "Erro interno do servidor"])
        }

        // Rotas que exigem sessão.
        if exigeSessao(metodo, caminho) {
            guard let b = bearer, b.hasPrefix("demo-acesso") else { return responder(r, 401, ["error": "unauthorized"]) }
        }

        // Idempotência (envio, resgate de benefício, cartão): mesma chave → mesma resposta.
        if let chave, metodo == "POST", let anterior = respostasIdempotentes[chave] {
            return responderDados(r, 200, anterior)
        }
        let (status, resposta) = rotear(metodo, caminho, consulta, corpo, bearer)
        let (dados, http) = responder(r, status, resposta)
        if let chave, metodo == "POST", (200..<300).contains(status) { respostasIdempotentes[chave] = dados }
        return (dados, http)
    }

    private func exigeSessao(_ m: String, _ c: String) -> Bool {
        let publicos = ["/health", "/auth/login", "/auth/login/2fa", "/auth/register", "/auth/google", "/auth/refresh",
                        "/auth/forgot-password", "/auth/reset-password", "/auth/terms/current",
                        "/pix/packages", "/pix/provider", "/card/tiers", "/payments/card/config"]
        if publicos.contains(c) { return false }
        if m == "GET", c.hasPrefix("/partners") || c.hasPrefix("/benefits") || c == "/campaigns" { return false }
        return true
    }

    // MARK: - Roteador

    private func rotear(_ m: String, _ c: String, _ q: [String: String], _ b: [String: Any], _ bearer: String?) -> (Int, Any) {
        let p = c.split(separator: "/").map(String.init)      // ["wallet", "transactions"]
        switch (m, c) {
        case ("GET", "/health"): return (200, ["status": "ok", "service": "demo"])

        // Acesso
        case ("POST", "/auth/login"): return login(b)
        case ("POST", "/auth/login/2fa"):
            if (b["challenge_token"] as? String) == "desafio-demo", (b["code"] as? String) == "123456" { return (200, sessaoNova()) }
            return (400, ["error": "Código não confere", "code": "wrong_code"])
        case ("POST", "/auth/register"): return cadastro(b)
        case ("POST", "/auth/google"): return (503, ["error": "Login Google indisponível no modo demonstração."])
        case ("POST", "/auth/refresh"):
            guard let r = bearer, r.hasPrefix("demo-renovacao") else { return (401, ["msg": "Token has been revoked"]) }
            contador += 1
            return (200, ["access_token": "demo-acesso-\(contador)", "token": "demo-acesso-\(contador)",
                          "refresh_token": "demo-renovacao-\(contador)", "token_type": "Bearer"])
        case ("GET", "/auth/me"): return (200, usuario())
        case ("POST", "/auth/logout"): return (200, ["ok": true, "revoked": true])
        case ("POST", "/auth/forgot-password"): return (200, ["ok": true])
        case ("POST", "/auth/reset-password"):
            if (b["token"] as? String) == "expirado" { return (400, ["error": "Token expirado. Peça um novo link."]) }
            if (b["password"] as? String) == "fraca" { return politicaSenha() }
            return (200, ["ok": true])
        case ("POST", "/auth/change-password"):
            if (b["old_password"] as? String) == "errada" { return (401, ["error": "Senha atual incorreta"]) }
            if (b["new_password"] as? String) == "fraca" { return politicaSenha() }
            return (200, ["ok": true])
        case ("POST", "/auth/verify-email/send"):
            if emailVerificado { return (400, ["error": "E-mail já verificado"]) }
            return (200, ["ok": true, "expires_in_min": 10])
        case ("POST", "/auth/verify-email"):
            if emailVerificado { return (200, ["ok": true, "already_verified": true]) }
            guard (b["code"] as? String) == "123456" else { return (400, ["error": "Código incorreto", "attempts_left": 2]) }
            emailVerificado = true
            return (200, ["ok": true, "verified_at": BXDemoDados.iso(.now)])
        case ("POST", "/auth/mfa/setup"):
            if mfaAtivo { return (400, ["error": "MFA já está ativado"]) }
            return (200, ["secret": "JBSWY3DPEHPK3PXP",
                          "uri": "otpauth://totp/BlaXx:cliente.demo%40exemplo.test?secret=JBSWY3DPEHPK3PXP&issuer=BlaXx"])
        case ("POST", "/auth/mfa/enable"):
            guard let cod = b["code"] as? String, cod.count == 6 else { return (400, ["error": "Código ausente"]) }
            guard cod == "123456" else { return (401, ["error": "Código inválido"]) }
            mfaAtivo = true
            return (200, ["ok": true, "mfa_enabled": true])
        case ("POST", "/auth/mfa/disable"):
            if (b["password"] as? String) == "errada" { return (401, ["error": "Senha incorreta"]) }
            mfaAtivo = false
            return (200, ["ok": true, "mfa_enabled": false])
        case ("POST", "/auth/sessions/revoke-all"): return (200, ["ok": true])
        case ("DELETE", "/auth/account"):
            guard (b["confirm"] as? String) == "EXCLUIR MINHA CONTA" else { return (400, ["error": "Confirmacao invalida"]) }
            if (b["password"] as? String) == "errada" { return (401, ["error": "Senha incorreta"]) }
            return (200, ["ok": true, "message": "Conta excluída."])
        case ("GET", "/auth/account/export"):
            return (200, ["profile": usuario(), "wallet": BXDemoDados.carteira(saldo: saldo, pendente: pendente),
                          "transactions": lancamentos, "vouchers": vouchers, "notifications": notificacoes,
                          "consents": consentimentos, "exported_at": BXDemoDados.iso(.now)])
        case ("GET", "/auth/terms/current"): return (200, ["version": "1.0"])
        case ("POST", "/auth/terms/reaccept"): return (200, ["ok": true, "version": "1.0"])

        // Segurança
        case ("POST", "/user/phone"): return (200, ["message": "Código enviado.", "phone_masked": "+55 (••) •••••-0000"])
        case ("POST", "/user/phone/verify"):
            guard (b["code"] as? String) == "123456" else { return (400, ["error": "Código não confere", "code": "wrong_code"]) }
            return (200, ["message": "Celular confirmado.", "user": usuario()])
        case ("DELETE", "/user/phone"): return (200, ["user": usuario()])
        case ("POST", "/user/2fa/sms/enable"), ("POST", "/user/2fa/sms/disable"):
            if (b["password"] as? String) == "errada" { return (400, ["error": "Senha incorreta", "code": "wrong_password"]) }
            return (200, ["message": "Pronto.", "user": usuario()])
        case ("GET", "/user/sessions"): return (200, ["sessions": listasVazias ? [] : sessoes])
        case ("GET", "/user/access-log"): return (200, ["items": listasVazias ? [] : BXDemoDados.historicoAcesso()])

        // Carteira e cartão
        case ("GET", "/wallet"):
            efetivarEnvios()
            return (200, BXDemoDados.carteira(saldo: saldo, pendente: pendente))
        case ("GET", "/wallet/transactions"):
            efetivarEnvios()
            let limite = Int(q["limit"] ?? "") ?? 20
            return (200, ["items": listasVazias ? [] : Array(lancamentosOrdenados().prefix(min(100, max(1, limite))))])
        case ("GET", "/card"): return (200, BXDemoDados.cartao(saldo: saldo))
        case ("GET", "/card/tiers"): return (200, ["tiers": BXDemoDados.niveis()])
        case ("GET", "/card/pass/status"): return (200, ["available": false])
        case ("GET", "/card/pass"): return (503, ["error": "wallet_not_configured"])

        // Compra
        case ("GET", "/pix/packages"): return (200, listasVazias ? [String: Any]() : BXDemoDados.pacotes())
        case ("GET", "/pix/provider"): return (200, ["name": "demo", "is_mock": true])
        case ("POST", "/pix/charge"): return criarCobranca(b)
        case ("GET", "/pix/my-charges"): return (200, ["items": listasVazias ? [] : cobrancas])
        case ("POST", "/pix/simulate-payment"):
            guard let id = b["charge_id"] as? String, let i = cobrancas.firstIndex(where: { ($0["id"] as? String) == id }) else {
                return (404, ["error": "not found"])
            }
            pagar(i)
            return (200, ["ok": true, "charge": cobrancas[i]])
        case ("GET", "/payments/card/config"):
            return (200, ["enabled": false, "provider": "stripe", "public_key": NSNull(), "max_installments": 1, "currency": "brl"])
        case ("POST", "/payments/card/charge"): return (503, ["error": "Pagamento por cartão desligado.", "code": "CARD_DISABLED"])
        case ("GET", "/payments/card/my-charges"): return (200, ["items": []])

        // Envio
        case ("POST", "/transfer"): return enviar(b)

        // Descobrir
        case ("GET", "/partners"): return (200, ["items": listasVazias ? [] : parceirosFiltrados(q)])
        case ("GET", "/partners/categories"):
            return (200, ["items": Array(Set(BXDemoDados.parceiros.map(\.categoria))).sorted()])
        case ("GET", "/benefits"):
            var lista = BXDemoDados.beneficios()
            if let cat = q["category"], !cat.isEmpty { lista = lista.filter { ($0["category"] as? String) == cat } }
            if let pid = q["partner_id"], !pid.isEmpty { lista = lista.filter { ($0["partner_id"] as? String) == pid } }
            return (200, ["items": listasVazias ? [] : lista])
        case ("GET", "/vouchers"): return (200, ["items": listasVazias ? [] : vouchers])
        case ("GET", "/campaigns"): return (200, ["items": listasVazias ? [] : campanhas])

        // Notificações e push
        case ("GET", "/notifications"):
            let itens = listasVazias ? [] : notificacoes
            return (200, ["items": itens, "unread_count": itens.filter { ($0["is_read"] as? Bool) == false }.count])
        case ("GET", "/notifications/unread-count"):
            return (200, ["count": listasVazias ? 0 : notificacoes.filter { ($0["is_read"] as? Bool) == false }.count])
        case ("POST", "/notifications/read-all"):
            let n = notificacoes.filter { ($0["is_read"] as? Bool) == false }.count
            for i in notificacoes.indices { marcarLida(i) }
            return (200, ["updated": n])
        case ("POST", "/push/devices/register"):
            return (201, ["id": "push-demo", "platform": "ios", "app_version": b["app_version"] ?? "", "revoked": false])

        // Privacidade
        case ("GET", "/privacy/consents"): return (200, ["items": listasVazias ? [] : consentimentos])
        case ("POST", "/privacy/consents"):
            contador += 1
            let novo: [String: Any] = ["id": "k-\(contador)", "type": b["type"] ?? "marketing", "version": b["version"] ?? "1.0",
                                       "accepted_at": BXDemoDados.iso(.now), "status": "accepted"]
            consentimentos.append(novo)
            return (201, novo)

        default:
            break
        }

        // Rotas com id no caminho.
        switch (m, p.count, p.first ?? "") {
        case ("POST", 3, "transfer") where p[2] == "cancel": return cancelarEnvio(p[1])
        case ("GET", 3, "pix") where p[1] == "charge": return consultarCobranca(p[2])
        case ("GET", 2, "partners"):
            guard let par = BXDemoDados.parceiros.first(where: { $0.id == p[1] }) else { return (404, ["error": "Parceiro não encontrado"]) }
            var d = BXDemoDados.parceiro(par)
            d["benefits"] = BXDemoDados.beneficios().filter { ($0["partner_id"] as? String) == par.id }
            return (200, d)
        case ("GET", 2, "benefits"):
            guard let x = BXDemoDados.beneficios().first(where: { ($0["id"] as? String) == p[1] }) else { return (404, ["error": "not found"]) }
            return (200, x)
        case ("POST", 3, "benefits") where p[2] == "redeem": return resgatar(p[1])
        case ("GET", 2, "vouchers"):
            guard let v = vouchers.first(where: { ($0["id"] as? String) == p[1] }) else { return (404, ["error": "not found"]) }
            return (200, v)
        case ("POST", 3, "campaigns") where p[2] == "join":
            guard let i = campanhas.firstIndex(where: { ($0["id"] as? String) == p[1] }) else { return (404, ["error": "not found"]) }
            let ja = (campanhas[i]["joined"] as? Bool) == true
            campanhas[i]["joined"] = true
            return (ja ? 200 : 201, ["id": "uc-\(p[1])", "campaign_id": p[1], "campaign": campanhas[i], "progress_pct": campanhas[i]["progress_pct"] ?? 0,
                                     "joined_at": BXDemoDados.iso(.now)])
        case ("PATCH", 3, "notifications") where p[2] == "read":
            guard let i = notificacoes.firstIndex(where: { ($0["id"] as? String) == p[1] }) else { return (404, ["error": "not found"]) }
            marcarLida(i)
            return (200, notificacoes[i])
        case ("DELETE", 3, "push") where p[1] == "devices": return (200, ["ok": true])
        case ("DELETE", 3, "user") where p[1] == "sessions":
            guard sessoes.contains(where: { ($0["id"] as? String) == p[2] }) else {
                return (404, ["error": "Sessão não encontrada", "code": "session_not_found"])
            }
            sessoes.removeAll { ($0["id"] as? String) == p[2] }
            return (200, ["ok": true])
        case ("DELETE", 3, "privacy") where p[1] == "consents":
            guard let i = consentimentos.firstIndex(where: { ($0["id"] as? String) == p[2] }) else { return (404, ["error": "not found"]) }
            consentimentos[i]["status"] = "revoked"
            return (200, ["original": consentimentos[i], "revocation": ["id": "rev-\(p[2])"]])
        default:
            print("[BXTransporteDemo] rota sem resposta de exemplo: \(m) \(c)")
            return (404, ["error": "not found"])
        }
    }

    // MARK: - Acesso

    private func usuario() -> [String: Any] {
        var u = BXDemoDados.usuario(emailVerificado: emailVerificado)
        u["mfa_enabled"] = mfaAtivo
        return u
    }

    private func sessaoNova() -> [String: Any] {
        contador += 1
        return ["token": "demo-acesso-\(contador)", "access_token": "demo-acesso-\(contador)",
                "refresh_token": "demo-renovacao-\(contador)", "token_type": "Bearer", "user": usuario()]
    }

    private func login(_ b: [String: Any]) -> (Int, Any) {
        let login = ((b["email"] as? String) ?? "").lowercased()
        let senha = (b["password"] as? String) ?? ""
        let codigo = (b["mfa_code"] as? String) ?? ""
        if login == "bloqueado@exemplo.test" {
            return (423, ["error": "Conta temporariamente bloqueada. Tente novamente mais tarde.",
                          "locked_until": BXDemoDados.adiante(minutos: 15)])
        }
        if login.isEmpty || senha.isEmpty || senha == "errada" { return (401, ["error": "Credenciais inválidas"]) }
        if login == "2fa@exemplo.test" {
            return (200, ["mfa_required": true, "mfa_method": "sms", "mfa_challenge_token": "desafio-demo",
                          "mfa_phone_hint": "***0000", "expires_in": 300])
        }
        if login == "totp@exemplo.test" {
            if codigo.isEmpty { return (401, ["mfa_required": true, "mfa_method": "totp", "error": "Código MFA necessário"]) }
            if codigo != "123456" { return (401, ["error": "Código MFA inválido"]) }
        }
        return (200, sessaoNova())
    }

    private func politicaSenha() -> (Int, Any) {
        (400, ["error": "A senha não atende à política.",
               "issues": [["code": "min_length", "message": "Use pelo menos 10 caracteres."],
                          ["code": "digit", "message": "Inclua pelo menos um número."]]])
    }

    private func cadastro(_ b: [String: Any]) -> (Int, Any) {
        let email = ((b["email"] as? String) ?? "").lowercased()
        guard (b["accept_terms"] as? Bool) == true, (b["accept_privacy"] as? Bool) == true, (b["accept_lgpd"] as? Bool) == true else {
            return (400, ["error": "É preciso aceitar os termos, a política de privacidade e a LGPD."])
        }
        if email == "existe@exemplo.test" { return (409, ["error": "Este e-mail já está cadastrado"]) }
        if (b["password"] as? String) == "fraca" { return politicaSenha() }
        emailVerificado = false
        return (201, sessaoNova())
    }

    // MARK: - Extrato

    private func lancamentosOrdenados() -> [[String: Any]] {
        lancamentos.sorted { ($0["created_at"] as? String ?? "") > ($1["created_at"] as? String ?? "") }
    }

    private func lancar(_ tipo: String, _ status: String, _ pts: Int, _ desc: String, _ ref: String?) {
        contador += 1
        lancamentos.append(["id": "t-n\(contador)", "type": tipo, "status": status, "amount_pts": pts, "description": desc,
                            "reference": ref ?? NSNull(), "created_at": BXDemoDados.iso(.now)])
    }

    private func notificar(_ tipo: String, _ titulo: String, _ corpo: String, _ ref: String?) {
        contador += 1
        notificacoes.insert(["id": "n-n\(contador)", "type": tipo, "title": titulo, "body": corpo, "icon": NSNull(),
                             "reference": ref ?? NSNull(), "read_at": NSNull(), "is_read": false,
                             "created_at": BXDemoDados.iso(.now)], at: 0)
    }

    private func marcarLida(_ i: Int) {
        guard (notificacoes[i]["is_read"] as? Bool) == false else { return }
        notificacoes[i]["is_read"] = true
        notificacoes[i]["read_at"] = BXDemoDados.iso(.now)
    }

    // MARK: - Compra

    private func criarCobranca(_ b: [String: Any]) -> (Int, Any) {
        let pacotes = BXDemoDados.pacotes()
        let id: String
        let chave: String
        let valor: Double
        let pontos: Int
        contador += 1
        if let k = b["package"] as? String {
            guard let pac = pacotes[k] as? [String: Any] else { return (400, ["error": "Pacote desconhecido."]) }
            chave = k
            valor = pac["price_brl"] as? Double ?? 0
            pontos = pac["points"] as? Int ?? 0
        } else if let v = (b["amount_brl"] as? NSNumber)?.doubleValue {
            if v < 10 { return (400, ["error": "O valor mínimo é R$ 10,00."]) }
            if v > 100_000 { return (400, ["error": "O valor máximo por compra é R$ 100.000,00."]) }
            chave = "custom"
            valor = v
            pontos = Int((v * 11).rounded(.down))
        } else {
            return (400, ["error": "Informe o pacote ou o valor."])
        }
        id = "demo-pix-\(contador)"
        let jaPaga = BXDemo.subtela == "pago"
        cobrancas.insert(BXDemoDados.cobranca(id: id, pacote: chave, valor: valor, pontos: pontos, status: "pending",
                                              expira: BXDemoDados.adiante(minutos: 30)), at: 0)
        if jaPaga { pagar(0) }
        return (201, cobrancas[0])
    }

    /// Pendente nas duas primeiras consultas, paga na terceira.
    private func consultarCobranca(_ id: String) -> (Int, Any) {
        guard let i = cobrancas.firstIndex(where: { ($0["id"] as? String) == id }) else { return (404, ["error": "not found"]) }
        if (cobrancas[i]["status"] as? String) == "pending" {
            let n = (consultasCobranca[id] ?? 0) + 1
            consultasCobranca[id] = n
            if n >= 3 && id != "demo-pix-pendente" { pagar(i) }
        }
        return (200, cobrancas[i])
    }

    private func pagar(_ i: Int) {
        guard (cobrancas[i]["status"] as? String) != "paid" else { return }
        cobrancas[i]["status"] = "paid"
        cobrancas[i]["paid_at"] = BXDemoDados.iso(.now)
        let pontos = cobrancas[i]["points_to_credit"] as? Int ?? 0
        let id = cobrancas[i]["id"] as? String
        saldo += pontos
        lancar("purchase", "confirmed", pontos, "Compra de pontos", id)
        notificar("purchase", "Compra confirmada", "Seus \(BXFormato.pontos(pontos)) pontos já estão na conta.", id)
    }

    // MARK: - Envio

    private func enviar(_ b: [String: Any]) -> (Int, Any) {
        guard emailVerificado else {
            return (403, ["error": "E-mail não verificado", "code": "EMAIL_NOT_VERIFIED",
                          "action": "Confirme seu e-mail antes de operar com pontos."])
        }
        let para = ((b["to"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
        let pontos = (b["amount_pts"] as? NSNumber)?.intValue ?? 0
        let senha = (b["password"] as? String) ?? ""
        let codigo = (b["mfa_code"] as? String) ?? ""
        if senha.isEmpty || senha == "errada" { return (400, ["error": "senha incorreta"]) }
        if pontos < 100 { return (400, ["error": "valor mínimo é 100 pts"]) }
        let normal = para.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        if normal == "repetido@exemplo.test" {
            return (409, ["error": "Parece um envio repetido.", "code": "DUPLICATE_SUSPECTED",
                          "previous_transfer_id": "env-demo-1", "hint": "Envie com uma nova chave para confirmar."])
        }
        guard ["amigo@exemplo.test", "ab12cd34"].contains(normal) else { return (400, ["error": "destinatário não encontrado"]) }
        if pontos >= 20_000 && codigo.isEmpty {
            return (401, ["error": "código 2FA necessário para esta operação", "mfa_required": true])
        }
        if pontos > saldo { return (400, ["error": "Pontos insuficientes."]) }
        contador += 1
        let id = "env-n\(contador)"
        let efetiva = Date.now.addingTimeInterval(60)
        let dados: [String: Any] = ["id": id, "sender_id": BXDemoDados.idUsuario, "recipient_id": "u-amigo", "amount_pts": pontos,
                                    "message": (b["message"] as? String) ?? NSNull(),
                                    "receipt_code": String(format: "ENV-2026-DEMO-%08d", contador),
                                    "created_at": BXDemoDados.iso(.now), "status": "pending",
                                    "committed_at": BXDemoDados.iso(efetiva), "cancelled_at": NSNull(), "is_cancellable": true]
        envios[id] = (dados, pontos, efetiva)
        saldo -= pontos
        pendente += pontos
        lancar("transfer_out", "pending", -pontos, "Envio (pending) para Amigo Exemplo", id)
        return (201, dados)
    }

    private func cancelarEnvio(_ id: String) -> (Int, Any) {
        guard var e = envios[id] else { return (404, ["error": "not found"]) }
        guard (e.dados["status"] as? String) == "pending", Date.now < e.efetiva else {
            return (400, ["error": "já efetivada (janela de 60s expirada)"])
        }
        e.dados["status"] = "cancelled"
        e.dados["cancelled_at"] = BXDemoDados.iso(.now)
        e.dados["is_cancellable"] = false
        envios[id] = e
        saldo += e.pontos
        pendente -= e.pontos
        if let i = lancamentos.firstIndex(where: { ($0["reference"] as? String) == id }) { lancamentos[i]["status"] = "reversed" }
        lancar("transfer_in", "confirmed", e.pontos, "Reversão de envio cancelado #\(id)", id)
        return (200, e.dados)
    }

    /// Efetivação "preguiçosa" como no backend: na leitura da carteira/extrato.
    private func efetivarEnvios() {
        for (id, e) in envios where (e.dados["status"] as? String) == "pending" && Date.now >= e.efetiva {
            var novo = e
            novo.dados["status"] = "committed"
            novo.dados["is_cancellable"] = false
            envios[id] = novo
            pendente -= e.pontos
            if let i = lancamentos.firstIndex(where: { ($0["reference"] as? String) == id }) { lancamentos[i]["status"] = "confirmed" }
        }
    }

    // MARK: - Descobrir

    private func parceirosFiltrados(_ q: [String: String]) -> [[String: Any]] {
        var lista = BXDemoDados.parceiros
        if let cat = q["category"], !cat.isEmpty { lista = lista.filter { $0.categoria == cat } }
        if let t = q["q"]?.lowercased(), !t.isEmpty {
            lista = lista.filter { $0.nome.lowercased().contains(t) || $0.descricao.lowercased().contains(t) }
        }
        return lista.map(BXDemoDados.parceiro)
    }

    private func resgatar(_ id: String) -> (Int, Any) {
        guard emailVerificado else {
            return (403, ["error": "E-mail não verificado", "code": "EMAIL_NOT_VERIFIED",
                          "action": "Confirme seu e-mail antes de operar com pontos."])
        }
        guard let b = BXDemoDados.beneficios().first(where: { ($0["id"] as? String) == id }) else { return (404, ["error": "not found"]) }
        if (b["stock"] as? Int) == 0 { return (409, ["error": "Sem estoque disponível"]) }
        let custo = b["cost_pts"] as? Int ?? 0
        if custo > saldo { return (402, ["error": "Saldo insuficiente"]) }
        saldo -= custo
        contador += 1
        let vid = "v-n\(contador)"
        let validade = Double(b["expires_in_days"] as? Int ?? 30)
        let v: [String: Any] = ["id": vid, "user_id": BXDemoDados.idUsuario, "benefit_id": id, "benefit_name": b["name"] ?? "Benefício",
                                "code": String(format: "BX-DEMO-%04d", contador), "points_spent": custo,
                                "expires_at": BXDemoDados.adiante(dias: validade), "used_at": NSNull(),
                                "status": "active", "created_at": BXDemoDados.iso(.now)]
        vouchers.insert(v, at: 0)
        lancar("redeem", "confirmed", -custo, "Resgate de benefício", vid)
        notificar("voucher", "Voucher emitido", "Seu voucher está pronto.", vid)
        return (201, v)
    }

    // MARK: - Resposta

    private func responder(_ r: URLRequest, _ status: Int, _ obj: Any) -> (Data, HTTPURLResponse) {
        let dados = (try? JSONSerialization.data(withJSONObject: obj, options: [])) ?? Data("{}".utf8)
        return responderDados(r, status, dados)
    }

    private func responderDados(_ r: URLRequest, _ status: Int, _ dados: Data) -> (Data, HTTPURLResponse) {
        let http = HTTPURLResponse(url: r.url ?? URL(string: "demo://")!, statusCode: status, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        return (dados, http)
    }
}
#endif
