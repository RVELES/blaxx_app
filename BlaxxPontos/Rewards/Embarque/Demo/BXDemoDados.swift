//
//  BXDemoDados.swift
//  BlaxxPontos · Modo demonstração "Embarque" (§4.3 da spec) · SÓ DEBUG
//
//  Dados de exemplo no formato EXATO do backend (as mesmas chaves JSON), para que o caminho de
//  decodificação e o sanitizador sejam os de verdade. Nomes inventados e genéricos, sem marca real.
//
//  ARMADILHAS de propósito (marcadas "armadilha"): textos e campos proibidos que o app tem de esconder
//  (valor do ponto, PIX fora da compra, "Parceiro Livelo", parceiro de exemplo, emoji, mechanic/target_brl,
//  perks com PIX, cor lima legada). Elas NÃO podem aparecer em nenhuma foto. Os emoji vão como escape
//  Unicode (\u{…}) para o código-fonte continuar sem emoji.
//

#if DEBUG
import Foundation

nonisolated enum BXDemoDados {

    // MARK: - Datas

    static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
    }
    static func atras(dias: Double = 0, horas: Double = 0, minutos: Double = 0, agora: Date = .now) -> String {
        iso(agora.addingTimeInterval(-(dias * 86_400 + horas * 3_600 + minutos * 60)))
    }
    static func adiante(dias: Double = 0, minutos: Double = 0, segundos: Double = 0, agora: Date = .now) -> String {
        iso(agora.addingTimeInterval(dias * 86_400 + minutos * 60 + segundos))
    }

    // MARK: - Usuário e carteira

    static let idUsuario = "de0a11c2-7f3b-4c1d-9a2e-5b6c7d8e9f01"   // Cartão BlaXx DE0A 11C2

    static func usuario(emailVerificado: Bool) -> [String: Any] {
        [
            "id": idUsuario,
            "name": "Cliente Demo",
            "email": "cliente.demo@exemplo.test",
            "cpf": "00000000191",
            "phone": "+5511900000000",
            "pix_key": "cliente.demo@exemplo.test",            // armadilha: não é decodificado (D03)
            "avatar_url": NSNull(),
            "auth_provider": "password",
            "email_verified_at": emailVerificado ? atras(dias: 30) : NSNull(),
            "role": "user",
            "is_vip": false,
            "mfa_enabled": false,
            "status": "active",
            "has_password": true,
            "google_linked": false,
        ]
    }

    static let saldoInicial = 32_480
    static let pendenteInicial = 1_000

    /// `balance_brl_equiv` é armadilha (valor do ponto): o DTO não decodifica.
    static func carteira(saldo: Int, pendente: Int) -> [String: Any] {
        ["id": "w-demo", "user_id": idUsuario, "balance_pts": saldo, "pending_pts": pendente,
         "balance_brl_equiv": Double(saldo) * 0.09]                        // armadilha
    }

    // MARK: - Extrato (14 lançamentos em 10 dias, 8 tipos, 3 status)

    static func lancamentos() -> [[String: Any]] {
        func l(_ id: String, _ tipo: String, _ status: String, _ pts: Int, _ desc: String, _ ref: String?, _ quando: String) -> [String: Any] {
            ["id": id, "type": tipo, "status": status, "amount_pts": pts, "description": desc,
             "reference": ref ?? NSNull(), "created_at": quando]
        }
        return [
            l("t01", "purchase", "confirmed", 5_500, "Compra de pontos — pacote plus", "demo-pix-pago", atras(horas: 2)),
            l("t02", "transfer_out", "pending", -1_000, "Envio (pending) para Amiga Exemplo", "env-demo-1", atras(minutos: 12)),
            l("t03", "transfer_in", "confirmed", 2_000, "Recebido (cód. ENV-2026-DEMO-0000AB12)", "env-demo-r", atras(dias: 1, horas: 3)),
            l("t04", "redeem", "confirmed", -353, "Resgate de benefício · Café expresso duplo", "v-ativo", atras(dias: 1, horas: 6)),
            l("t05", "bonus", "confirmed", 500, "Bônus de boas-vindas", nil, atras(dias: 2)),
            l("t06", "refund", "confirmed", 120, "Estorno de resgate", "v-estorno", atras(dias: 3)),
            l("t07", "expire", "confirmed", -200, "Expiracao automatica · lote antigo", nil, atras(dias: 4)),
            l("t08", "accrual", "confirmed", 80, "Compra em rede parceira", nil, atras(dias: 5, horas: 1)),
            l("t09", "transfer_in", "confirmed", 300, "Reversão de envio cancelado #env-demo-0", "env-demo-0", atras(dias: 5, horas: 2)),
            l("t10", "transfer_out", "reversed", -300, "Envio (pending) para Amigo Exemplo", "env-demo-0", atras(dias: 5, horas: 2, minutos: 1)),
            l("t11", "redeem", "confirmed", -1_200, "Resgate via PIX → chave cliente.demo@exemplo.test", nil, atras(dias: 6)),   // armadilha
            l("t12", "purchase", "confirmed", 2_000, "Compra de pontos — pacote start", "demo-pix-start", atras(dias: 7)),
            l("t13", "bonus", "confirmed", 800, "Campanha Semana dos parceiros", nil, atras(dias: 8)),
            l("t14", "transfer_out", "confirmed", -500, "Envio para Amiga Exemplo", "env-demo-2", atras(dias: 9)),
        ]
    }

    // MARK: - Cartão BlaXx

    static func niveis() -> [[String: Any]] {
        [
            ["key": "bronze", "label": "Bronze", "min_points": 0, "color": "#CD7F32", "text_color": "#FFFFFF",
             "perks": "Acesso ao programa, catálogo de benefícios e PIX."],             // armadilha (perks com PIX)
            ["key": "prata", "label": "Prata", "min_points": 5_000, "color": "#9AA0A6", "text_color": "#0B0B0C",
             "perks": "Ofertas exclusivas Prata."],
            ["key": "ouro", "label": "Ouro", "min_points": 20_000, "color": "#D4AF37", "text_color": "#0B0B0C",
             "perks": "Atendimento prioritário."],
            ["key": "black", "label": "Black", "min_points": 50_000, "color": "#0A0A0A", "text_color": "#C6FF00",   // armadilha (lima legado)
             "perks": "Benefícios Black."],
            ["key": "vip", "label": "BlaXx VIP", "min_points": 999_999_999, "color": "#0A0A0A", "text_color": "#C6FF00",
             "invite_only": true, "perks": "Exclusivo, apenas por convite."],
        ]
    }

    static func cartao(saldo: Int) -> [String: Any] {
        let n = niveis()
        return ["member": ["id": "DE0A11C2", "name": "Cliente Demo"],
                "balance_pts": saldo, "lifetime_points": 24_800,
                "tier": n[2], "next_tier": n[3], "points_to_next": 25_200, "progress_pct": 49,
                "tiers": n, "wallet_pass_available": false]
    }

    // MARK: - Compra

    static func pacotes() -> [String: Any] { [
        "start": ["label": "Start", "points": 2_000, "price_brl": 180.0],
        "plus": ["label": "Plus", "points": 5_500, "price_brl": 470.0],
        "prime": ["label": "Prime", "points": 12_000, "price_brl": 972.0],
        "black": ["label": "Black", "points": 28_000, "price_brl": 2_142.0],
    ] }

    static let brCodeExemplo = "00020101021226580014br.gov.bcb.pix0136exemplo-demo-blaxx-0000-000000000000520400005303986540510.005802BR5912BLAXX PONTOS6009SAO PAULO62070503***6304DEMO"

    static func cobranca(id: String, pacote: String, valor: Double, pontos: Int, status: String,
                         expira: String, pagaEm: String? = nil) -> [String: Any] {
        ["id": id, "user_id": idUsuario, "package": pacote, "amount_brl": valor, "points_to_credit": pontos,
         "txid": "TXDEMO\(id.count)", "br_code": brCodeExemplo, "qr_code_image": NSNull(), "status": status,
         "flow": "dynamic", "expires_at": expira, "paid_at": pagaEm ?? NSNull(), "claimed_paid_at": NSNull()]
    }

    static func historicoCobrancas() -> [[String: Any]] {
        [
            cobranca(id: "demo-pix-pendente", pacote: "prime", valor: 972, pontos: 12_000, status: "pending",
                     expira: adiante(minutos: 18)),
            cobranca(id: "demo-pix-pago", pacote: "plus", valor: 470, pontos: 5_500, status: "paid",
                     expira: atras(horas: 1, minutos: 40), pagaEm: atras(horas: 2)),
            cobranca(id: "demo-pix-expirado", pacote: "start", valor: 180, pontos: 2_000, status: "expired",
                     expira: atras(dias: 3)),
        ]
    }

    // MARK: - Parceiros (24, com duas armadilhas)

    struct Parceiro: Sendable { let id, nome, categoria, descricao: String }

    static let parceiros: [Parceiro] = [
        Parceiro(id: "mercado-aurora", nome: "Mercado Aurora", categoria: "Supermercado", descricao: "Supermercado de bairro com hortifrúti fresco."),
        Parceiro(id: "posto-rota-sul", nome: "Posto Rota Sul", categoria: "Combustível", descricao: "Posto com loja de conveniência."),
        Parceiro(id: "farmacia-bem-viver", nome: "Farmácia Bem Viver", categoria: "Farmácia", descricao: "Medicamentos e cuidados pessoais."),
        Parceiro(id: "drogaria-centro", nome: "Drogaria Centro", categoria: "Farmácias", descricao: "Drogaria no centro da cidade."),
        Parceiro(id: "cafe-ponto-doce", nome: "Café Ponto Doce", categoria: "Café", descricao: "Cafeteria com doces da casa."),
        Parceiro(id: "padaria-trigo-bom", nome: "Padaria Trigo Bom", categoria: "Alimentação", descricao: "Pães de fermentação natural."),
        Parceiro(id: "cine-lumen", nome: "Cine Lumen", categoria: "Streaming", descricao: "Filmes e séries por assinatura."),
        Parceiro(id: "hotel-vila-serena", nome: "Hotel Vila Serena", categoria: "Viagens", descricao: "Pousada com café da manhã."),
        Parceiro(id: "rumo-viagens", nome: "Rumo Viagens", categoria: "Viagens", descricao: "Pacotes e passeios."),
        Parceiro(id: "atelie-linha", nome: "Ateliê Linha", categoria: "Moda Plus", descricao: "Roupas sob medida."),
        Parceiro(id: "passo-firme", nome: "Passo Firme", categoria: "Calçados", descricao: "Calçados confortáveis."),
        Parceiro(id: "studio-brilho", nome: "Studio Brilho", categoria: "Beleza", descricao: "Salão e estética."),
        Parceiro(id: "volt-eletronicos", nome: "Volt Eletrônicos", categoria: "Tech", descricao: "Eletrônicos e acessórios."),
        Parceiro(id: "conecta-telecom", nome: "Conecta Telecom", categoria: "Telecom", descricao: "Internet e telefonia."),
        Parceiro(id: "casa-clara", nome: "Casa Clara", categoria: "Casa & Decoração", descricao: "Decoração e utilidades."),
        Parceiro(id: "pet-amigo", nome: "Pet Amigo", categoria: "Pet", descricao: "Tudo para o seu pet."),
        Parceiro(id: "livraria-pagina-9", nome: "Livraria Página 9", categoria: "Educação", descricao: "Livros e cursos."),
        Parceiro(id: "energia-viva", nome: "Energia Viva", categoria: "Energia", descricao: "Energia solar residencial."),
        Parceiro(id: "seguro-certo", nome: "Seguro Certo", categoria: "Seguros", descricao: "Seguros para casa e carro."),
        Parceiro(id: "loja-ponto-net", nome: "Loja Ponto Net", categoria: "E-commerce", descricao: "Loja online de variedades."),
        Parceiro(id: "sabor-da-vila", nome: "Sabor da Vila", categoria: "Restaurantes", descricao: "Comida caseira."),
        Parceiro(id: "otica-clara", nome: "Ótica Clara", categoria: "Acessórios", descricao: "Óculos e lentes."),
        Parceiro(id: "loja-exemplo", nome: "Loja Exemplo", categoria: "Compras", descricao: "Loja fictícia usada nos exemplos"),   // armadilha: some da lista
        Parceiro(id: "mercado-teste", nome: "Mercado Teste", categoria: "Supermercados", descricao: "Parceiro Livelo · mercado-teste"), // armadilha: aparece sem descrição
    ]

    /// `accrual_rule` e `logo_emoji` são armadilhas em todos.
    static func parceiro(_ p: Parceiro) -> [String: Any] {
        ["id": p.id, "name": p.nome, "category": p.categoria, "description": p.descricao,
         "logo_emoji": "\u{1F6CD}", "accrual_rule": "2 pts/R$", "city": NSNull(), "is_active": true]   // armadilha
    }

    // MARK: - Benefícios (10, um deles de parceiro de exemplo)

    static func beneficios() -> [[String: Any]] {
        func b(_ id: String, _ parceiro: String?, _ nomeParceiro: String?, _ nome: String, _ desc: String,
               _ cat: String, _ custo: Int, estoque: Int = -1, validade: Int = 30, tag: String? = nil) -> [String: Any] {
            ["id": id, "partner_id": parceiro ?? NSNull(), "partner_name": nomeParceiro ?? NSNull(), "name": nome,
             "description": desc, "category": cat, "cost_pts": custo, "image_emoji": "\u{2615}",   // armadilha (emoji)
             "stock": estoque, "expires_in_days": validade, "is_active": true, "tag": tag ?? NSNull()]
        }
        return [
            b("b-cafe-expresso", "cafe-ponto-doce", "Café Ponto Doce", "Café expresso duplo", "Um expresso duplo na hora.", "voucher", 353, validade: 60, tag: "Popular"),
            b("b-cafe-combo", "cafe-ponto-doce", "Café Ponto Doce", "Combo café e pão de queijo", "Café coado com pão de queijo.", "desconto", 600, validade: 30),
            b("b-otica", "otica-clara", "Ótica Clara", "Desconto de 15 % em óculos", "Vale para armações e lentes.", "desconto", 1_200),
            b("b-series", "cine-lumen", "Cine Lumen", "Mês de séries", "Um mês de assinatura.", "assinatura", 2_400),
            b("b-sorteio", nil, nil, "Sorteio de fim de ano", "Participe do sorteio da BlaXx.", "sorteio", 100, estoque: 1_000),
            b("b-doacao", nil, nil, "Doação para projeto social", "Pontos que viram doação para um projeto social.", "social", 500),
            b("b-curso", "livraria-pagina-9", "Livraria Página 9", "Curso online de fotografia", "Curso completo em vídeo.", "educacao", 6_000),
            b("b-escalada", "studio-brilho", "Studio Brilho", "Aula de escalada", "Uma aula experimental.", "experiencia", 4_500, estoque: 0),
            b("b-pousada", "hotel-vila-serena", "Hotel Vila Serena", "Diária em pousada", "Uma diária com café da manhã.", "viagem", 40_000, validade: 90),
            b("b-loja-exemplo", "loja-exemplo", "Loja Exemplo", "Vale-compras da Loja Exemplo", "Benefício de exemplo.", "voucher", 300),   // armadilha: some
        ]
    }

    // MARK: - Vouchers

    static func vouchers() -> [[String: Any]] {
        [
            ["id": "v-ativo", "user_id": idUsuario, "benefit_id": "b-cafe-expresso", "benefit_name": "Café expresso duplo",
             "code": "BX-7F3K-92QA", "points_spent": 353, "expires_at": adiante(dias: 60), "used_at": NSNull(),
             "status": "active", "created_at": atras(dias: 1, horas: 6)],
            ["id": "v-usado", "user_id": idUsuario, "benefit_id": "b-series", "benefit_name": "Mês de séries",
             "code": "BX-2M8D-41LP", "points_spent": 2_400, "expires_at": adiante(dias: 10), "used_at": atras(dias: 12),
             "status": "used", "created_at": atras(dias: 20)],
            ["id": "v-expirado", "user_id": idUsuario, "benefit_id": "b-otica", "benefit_name": "Desconto de 15 % em óculos",
             "code": "BX-9Q1Z-77TR", "points_spent": 1_200, "expires_at": atras(dias: 5), "used_at": NSNull(),
             "status": "expired", "created_at": atras(dias: 40)],
        ]
    }

    // MARK: - Campanhas

    static func campanhas() -> [[String: Any]] {
        [
            ["id": "c-boas-vindas", "name": "Boas-vindas BlaXx", "description": "Faça a sua primeira compra de pontos e ganhe um bônus.",
             "mechanic": "A cada R$ 100 movimentados você avança na meta.", "target_brl": 100.0,   // armadilha
             "reward_pts": 500, "period_start": atras(dias: 10), "period_end": adiante(dias: 20), "is_active": true,
             "joined": true, "progress_brl": 40.0, "progress_pct": 40, "completed_at": NSNull()],
            ["id": "c-tres-compras", "name": "Desafio de 3 compras", "description": "Faça três compras de pontos no mês.",
             "mechanic": "Três compras no período.", "target_brl": 0.0,
             "reward_pts": 1_000, "period_start": atras(dias: 18), "period_end": adiante(dias: 12), "is_active": true,
             "joined": false, "progress_brl": 0.0, "progress_pct": 0, "completed_at": NSNull()],
            ["id": "c-semana-parceiros", "name": "Semana dos parceiros", "description": "Resgate um benefício de parceiro na semana.",
             "mechanic": "Um resgate no período.", "target_brl": 0.0,
             "reward_pts": 800, "period_start": atras(dias: 15), "period_end": adiante(dias: 2), "is_active": true,
             "joined": true, "progress_brl": 0.0, "progress_pct": 100, "completed_at": atras(dias: 8)],
        ]
    }

    // MARK: - Notificações (6, 2 não lidas)

    static func notificacoes() -> [[String: Any]] {
        func n(_ id: String, _ tipo: String, _ titulo: String, _ corpo: String, _ ref: String?, lida: Bool, _ quando: String) -> [String: Any] {
            ["id": id, "user_id": idUsuario, "type": tipo, "title": titulo, "body": corpo, "icon": "\u{2605}",   // armadilha (glifo)
             "reference": ref ?? NSNull(), "read_at": lida ? quando : NSNull(), "is_read": lida, "created_at": quando]
        }
        return [
            n("n1", "purchase", "Compra confirmada", "Seus 5.500 pontos já estão na conta.", "demo-pix-pago", lida: false, atras(horas: 2)),
            n("n2", "transfer", "Você recebeu pontos", "Amiga Exemplo enviou 2.000 pontos para você.", "env-demo-r", lida: false, atras(dias: 1, horas: 3)),
            n("n3", "voucher", "Voucher emitido", "Seu voucher Café expresso duplo está pronto.", "v-ativo", lida: true, atras(dias: 1, horas: 6)),
            n("n4", "campaign", "Participando: Boas-vindas BlaXx", "Meta: R$ 100 · Bônus: 500 pts", "c-boas-vindas", lida: true, atras(dias: 9)),   // armadilha (R$)
            ["id": "n5", "user_id": idUsuario, "type": "system", "title": "Bem-vindo ao BlaXx",
             "body": "Complete seu CPF no Perfil para liberar resgates PIX.", "icon": "\u{1F4B8}",                       // armadilha (PIX + emoji)
             "reference": NSNull(), "read_at": atras(dias: 30), "is_read": true, "created_at": atras(dias: 30)],
            n("n6", "expiration", "Pontos expirados", "200 pontos do lote antigo expiraram.", nil, lida: true, atras(dias: 4)),
        ]
    }

    // MARK: - Segurança e privacidade

    static func sessoes() -> [[String: Any]] {
        [
            ["id": "s-atual", "device_name": "iPhone · BlaXx iOS", "ip_address": "189.40.12.7", "user_agent": "BlaxxPontos iOS",
             "created_at": atras(dias: 1), "last_used_at": atras(minutos: 1), "expires_at": adiante(dias: 29), "current": true],
            ["id": "s-mac", "device_name": "Safari · macOS", "ip_address": "189.40.12.9", "user_agent": "Safari",
             "created_at": atras(dias: 2), "last_used_at": atras(dias: 2), "expires_at": adiante(dias: 28), "current": false],
            ["id": "s-android", "device_name": "Chrome · Android", "ip_address": "201.17.88.3", "user_agent": "Chrome",
             "created_at": atras(dias: 9), "last_used_at": atras(dias: 9), "expires_at": adiante(dias: 21), "current": false],
        ]
    }

    static func historicoAcesso() -> [[String: Any]] {
        func e(_ ev: String, _ st: String, _ dispositivo: String, _ quando: String) -> [String: Any] {
            ["event": ev, "ip": "189.40.***.***", "user_agent": dispositivo, "device": dispositivo, "status": st,
             "reason": NSNull(), "metadata": NSNull(), "at": quando]
        }
        return [
            e("login_success", "ok", "iPhone · BlaXx iOS", atras(dias: 1)),
            e("login_fail", "warn", "Safari · macOS", atras(dias: 2)),
            e("password_change", "ok", "Safari · macOS", atras(dias: 6)),
            e("mfa_challenge_issued", "ok", "Chrome · Android", atras(dias: 9)),
            e("logout", "ok", "Chrome · Android", atras(dias: 9, horas: 2)),
            e("mfa_enabled", "ok", "iPhone · BlaXx iOS", atras(dias: 15)),
        ]
    }

    static func consentimentos() -> [[String: Any]] {
        func c(_ id: String, _ tipo: String, _ status: String, _ quando: String) -> [String: Any] {
            ["id": id, "type": tipo, "version": "1.0", "accepted_at": quando, "status": status,
             "ip": "189.40.***.***", "user_agent": "BlaxxPontos iOS", "text_hash": NSNull(), "revokes_consent_id": NSNull()]
        }
        return [
            c("k-terms", "terms", "accepted", atras(dias: 30)),
            c("k-privacy", "privacy", "accepted", atras(dias: 30)),
            c("k-lgpd", "lgpd", "accepted", atras(dias: 30)),
            c("k-marketing", "marketing", "revoked", atras(dias: 12)),
        ]
    }
}
#endif
