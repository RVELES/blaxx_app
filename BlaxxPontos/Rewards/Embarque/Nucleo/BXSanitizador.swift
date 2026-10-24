//
//  BXSanitizador.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  Filtros de texto vindos da API (seção 6 de 02-inventario-web-mobile.md, regras do dono) e os mapas
//  de categoria, ícone e rótulo (§1.7.6 da spec). Vale em TODAS as builds: nada de "Parceiro Livelo",
//  "fictícia", PIX fora da compra, valor do ponto ou emoji chega à tela.
//

import Foundation

nonisolated enum BXSanitizador {

    /// Descrição de parceiro/benefício e mensagens livres: `nil` se casar com
    /// /parceiro\s+livelo|fict[ií]ci|\bpix\b|a\s+cada\s+R\$|pts?\s*\/\s*R\$/i ou se ficar vazia.
    /// Acréscimo do núcleo: "R$ 1.000 em pontos" (equivalência em reais de pontos, ex. o benefício
    /// "Sorteio" de produção) também cai. Tira emoji e símbolos decorativos (U+2600–U+27BF e emoji).
    static func textoSeguro(_ s: String?) -> String? {
        guard let s else { return nil }
        let padrao = #"parceiro\s+livelo|fict[ií]ci|\bpix\b|a\s+cada\s+R\$|pts?\s*/\s*R\$|R\$\s*[\d.,]+\s*(?:mil\s+)?em\s+pontos"#
        if s.range(of: padrao, options: [.regularExpression, .caseInsensitive]) != nil { return nil }
        let limpo = semSimbolos(s).trimmingCharacters(in: .whitespacesAndNewlines)
        return limpo.isEmpty ? nil : limpo
    }

    /// Nome e descrição de campanha: `nil` se casar com /R\$|\/\s*R\$|\bpix\b/i.
    static func textoCampanhaSeguro(_ s: String?) -> String? {
        guard let s else { return nil }
        if s.range(of: #"R\$|/\s*R\$|\bpix\b"#, options: [.regularExpression, .caseInsensitive]) != nil { return nil }
        let limpo = semSimbolos(s).trimmingCharacters(in: .whitespacesAndNewlines)
        return limpo.isEmpty ? nil : limpo
    }

    /// Parceiro fictício (descrição com "fictícia"): escondido em TODAS as builds.
    static func ehFicticio(descricao: String?) -> Bool {
        guard let d = descricao else { return false }
        return d.range(of: #"fict[ií]ci"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Marca de terceiro importada sem contrato (descrição "Parceiro Livelo · …"), D05.
    static func ehSemContrato(descricao: String?) -> Bool {
        guard let d = descricao else { return false }
        return d.range(of: #"parceiro\s+livelo"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Minúsculas e sem acento (busca).
    static func normalizar(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
    }

    /// Remove emoji e símbolos pictográficos (mantém letras, números, pontuação comum e "→").
    static func semSimbolos(_ s: String) -> String {
        var r = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            let v = u.value
            let pictografico = u.properties.isEmojiPresentation
                || (0x2600...0x27BF).contains(v)       // símbolos diversos e dingbats (estrela, visto, alerta)
                || (0x1F000...0x1FAFF).contains(v)     // emoji
                || (0x2B00...0x2BFF).contains(v)       // setas e símbolos (estrela grande)
                || v == 0xFE0F || v == 0x200D          // seletor de variação e ZWJ
            if !pictografico { r.append(u) }
        }
        return String(r).replacingOccurrences(of: "  ", with: " ")
    }

    // MARK: - Mensagens do servidor

    /// Onde a mensagem vai aparecer. Só `.compra` (telas de Movimentar ligadas à compra) pode dizer "PIX".
    enum Contexto: String, Sendable, Equatable {
        case geral, acesso, compra, envio, resgate, conta
    }

    /// Mensagem do servidor adaptada ao contexto (melhor esforço; nunca vazia):
    /// fora da compra, "PIX" vira "transferência"; tira dica técnica e símbolos.
    static func mensagemServidor(_ s: String, contexto: Contexto) -> String {
        mensagemServidorSegura(s, contexto: contexto) ?? "Algo deu errado. Tente de novo."
    }

    /// Igual a `mensagemServidor`, mas `nil` quando a mensagem não pode ir para a tela
    /// (texto técnico, valor do ponto, parceiro de exemplo). Usado por `BXErro.mensagemParaUsuario`.
    static func mensagemServidorSegura(_ s: String?, contexto: Contexto) -> String? {
        guard var t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        // Dica técnica / mensagem de desenvolvedor: não vai para a tela.
        let tecnico = #"traceback|exception|sqlalchemy|flask|werkzeug|<html|<!doctype|https?://|localhost|127\.0\.0\.1|\b[a-z]+_[a-z_]+\b|token has expired|signature|jwt"#
        if t.range(of: tecnico, options: [.regularExpression, .caseInsensitive]) != nil { return nil }
        if contexto != .compra {
            t = t.replacingOccurrences(of: #"\bvia\s+pix\b"#, with: "por transferência", options: [.regularExpression, .caseInsensitive])
            t = t.replacingOccurrences(of: #"\bchave\s+pix\b"#, with: "chave de transferência", options: [.regularExpression, .caseInsensitive])
            t = t.replacingOccurrences(of: #"\bpix\b"#, with: "transferência", options: [.regularExpression, .caseInsensitive])
        }
        // Valor do ponto e parceiros de exemplo nunca, em nenhum contexto.
        let proibido = #"parceiro\s+livelo|fict[ií]ci|a\s+cada\s+R\$|pts?\s*/\s*R\$|1\s*pt\s*=\s*R|≈"#
        if t.range(of: proibido, options: [.regularExpression, .caseInsensitive]) != nil { return nil }
        let limpo = semSimbolos(t).trimmingCharacters(in: .whitespacesAndNewlines)
        return limpo.isEmpty ? nil : limpo
    }

    // MARK: - Categorias de parceiro (mapa CANON e ICONE_CAT de blaxx/parceiros.html)

    private static let canon: [String: String] = [
        "Combustível": "Postos", "Posto": "Postos", "Postos": "Postos",
        "Supermercado": "Supermercados", "Mercados": "Supermercados", "Supermercados": "Supermercados",
        "Farmácia": "Farmácias", "Farmácias": "Farmácias",
        "Casa & Decoração": "Casa", "Tech": "Eletrônicos",
        "Moda Plus": "Moda", "Moda Infantil": "Moda", "Moda Esportiva": "Moda", "Moda Íntima": "Moda",
        "Moda Sustentável": "Moda",
    ]

    /// As categorias que viram pílula fixa na lista de parceiros (as três verticais + Viagens, Moda, Beleza).
    static let categoriasPrincipais = ["Postos", "Supermercados", "Farmácias", "Viagens", "Moda", "Beleza"]

    /// Junta as irmãs ("Farmácia"/"Farmácias", "Casa & Decoração"/"Casa"…). Vazio → "Outros".
    static func categoriaCanonica(_ c: String?) -> String {
        let t = (c ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "Outros" }
        return canon[t] ?? t
    }

    private static let iconeCategoria: [String: BXIconeNome] = [
        "Postos": .posto, "Automotivo": .posto, "Mobilidade": .local,
        "Supermercados": .supermercado, "Alimentação": .supermercado, "Bebidas": .supermercado,
        "Café": .supermercado, "Restaurantes": .loja,
        "Farmácias": .farmacia, "Saúde": .farmacia,
        "Viagens": .aviao,
        "Moda": .moda, "Calçados": .moda, "Acessórios": .moda, "Joias & Relógios": .moda, "Esportes": .moda,
        "Beleza": .tag,
        "Eletrônicos": .celular, "Telecom": .celular,
        "Streaming": .filme, "Entretenimento": .filme, "Música": .filme,
        "E-commerce": .carrinho, "Compras": .carrinho, "Presentes": .resgates,
        "Casa": .inicio, "Construção": .inicio,
        "Seguros": .seguranca, "Consórcio": .comprar, "Finanças": .comprar, "Câmbio": .comprar,
        "Energia": .raio, "Educação": .documento, "Pet": .loja, "Serviços": .configuracoes, "Outros": .tag,
    ]

    /// Ícone da marca pela categoria do parceiro (nunca `logo_emoji`). Viagens de hospedagem → hotel.
    static func icone(categoriaParceiro: String, nome: String) -> BXIconeNome {
        let c = categoriaCanonica(categoriaParceiro)
        if c == "Viagens",
           nome.range(of: #"hot[eé]|hosped|resort|pousada|hostel|accor|ibis|marriott|hilton"#,
                      options: [.regularExpression, .caseInsensitive]) != nil {
            return .hotel
        }
        return iconeCategoria[c] ?? .loja
    }

    // MARK: - Categorias de benefício (BENEFICIO e ROTULO de blaxx/detalhe-parceiro.html)

    static func icone(categoriaBeneficio: String) -> BXIconeNome {
        switch normalizar(categoriaBeneficio) {
        case "voucher": return .voucher
        case "desconto": return .tag
        case "assinatura": return .filme
        case "sorteio": return .estrela
        case "social": return .indique
        case "educacao": return .documento
        case "experiencia": return .festa
        case "viagem": return .aviao
        case "produto": return .resgates
        default: return .resgates
        }
    }

    /// Rótulo acentuado ("educacao" → "Educação"). Desconhecida → primeira letra maiúscula.
    static func rotulo(categoriaBeneficio: String) -> String {
        switch normalizar(categoriaBeneficio) {
        case "voucher": return "Voucher"
        case "desconto": return "Desconto"
        case "assinatura": return "Assinatura"
        case "sorteio": return "Sorteio"
        case "social": return "Social"
        case "educacao": return "Educação"
        case "experiencia": return "Experiência"
        case "viagem": return "Viagem"
        case "produto": return "Produto"
        default:
            let t = categoriaBeneficio.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? "Benefício" : t.prefix(1).uppercased() + t.dropFirst()
        }
    }

    // MARK: - Notificações

    /// purchase→comprar, transfer→trocar, expiration→relogio, campaign→campanhas, system→info,
    /// redeem→resgates, voucher→voucher, outro→notificacoes (nunca o `icon` do servidor).
    static func icone(tipoNotificacao: String) -> BXIconeNome {
        switch tipoNotificacao.lowercased() {
        case "purchase": return .comprar
        case "transfer": return .trocar
        case "expiration": return .relogio
        case "campaign": return .campanhas
        case "system": return .info
        case "redeem": return .resgates
        case "voucher": return .voucher
        default: return .notificacoes
        }
    }

    /// Título neutro pelo tipo, quando o título do servidor não pode ir para a tela.
    static func tituloPadrao(tipoNotificacao: String) -> String {
        switch tipoNotificacao.lowercased() {
        case "purchase": return "Compra de pontos"
        case "transfer": return "Envio de pontos"
        case "expiration": return "Validade dos pontos"
        case "campaign": return "Campanha"
        case "redeem": return "Resgate"
        case "voucher": return "Voucher"
        default: return "Aviso da BlaXx"
        }
    }

    // MARK: - Extrato

    /// Rótulo do lançamento montado pelo TIPO (nunca a descrição crua do servidor).
    static func rotulo(tipo: BXTipoLancamento, descricao: String?) -> String {
        switch tipo {
        case .purchase: return "Compra de pontos"
        case .transferOut: return "Pontos enviados"
        case .transferIn:
            if let d = descricao, normalizar(d).hasPrefix("reversao de envio") { return "Envio desfeito" }
            return "Pontos recebidos"
        case .redeem: return "Resgate de benefício"
        case .refund: return "Estorno"
        case .bonus: return "Bônus"
        case .expire: return "Pontos expirados"
        case .accrual: return "Pontos acumulados"
        case .desconhecido: return "Movimento"
        }
    }

    /// Complemento do extrato: a descrição só se for segura e sem marcas internas ("(pending)", "via PIX", "→").
    static func detalheLancamento(_ descricao: String?) -> String? {
        guard let d = descricao else { return nil }
        if d.range(of: #"\(pending\)|\bpix\b|→|cód\.|#\w+|ENV-"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return nil
        }
        return textoSeguro(d)
    }

    // MARK: - Busca por cidade (mapa CIDADES de blaxx/parceiros.html)

    private static let cidades: [String: String] = [
        "sao paulo": "São Paulo", "sp": "São Paulo", "sampa": "São Paulo",
        "rio de janeiro": "Rio de Janeiro", "rio": "Rio de Janeiro", "rj": "Rio de Janeiro",
        "belo horizonte": "Belo Horizonte", "bh": "Belo Horizonte", "brasilia": "Brasília", "campinas": "Campinas",
        "curitiba": "Curitiba", "fortaleza": "Fortaleza", "goiania": "Goiânia", "manaus": "Manaus",
        "porto alegre": "Porto Alegre", "recife": "Recife", "salvador": "Salvador",
    ]

    /// Cidade reconhecida na busca (para o aviso "Rede em expansão nesta cidade"), ou nil.
    static func cidade(daBusca q: String) -> String? {
        var s = normalizar(q).replacingOccurrences(of: #"[^a-z\s]"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if let c = cidades[s] { return c }
        let semUF = s.replacingOccurrences(of: #"\s+[a-z]{2}$"#, with: "", options: .regularExpression)
        return semUF != s ? cidades[semUF] : nil
    }

    // MARK: - Segurança e privacidade

    /// IP para a tela: só o começo ("189.40.•••.•••"; IPv6: primeiros dois blocos). Já mascarado → como veio.
    static func ipMascarado(_ ip: String?) -> String? {
        guard let ip = ip?.trimmingCharacters(in: .whitespaces), !ip.isEmpty else { return nil }
        if ip.contains("*") || ip.contains("•") || ip.contains("x") { return ip }
        if ip.contains(".") {
            let p = ip.split(separator: ".")
            guard p.count == 4 else { return ip }
            return "\(p[0]).\(p[1]).•••.•••"
        }
        let p = ip.split(separator: ":")
        return p.count >= 2 ? "\(p[0]):\(p[1]):••••" : ip
    }

    /// Evento do histórico de acesso em linguagem simples.
    static func rotulo(eventoAcesso e: String) -> String {
        switch e {
        case "login_success": return "Entrada na conta"
        case "login_fail": return "Tentativa de entrada recusada"
        case "account_locked": return "Conta bloqueada temporariamente"
        case "account_unlocked": return "Conta desbloqueada"
        case "logout": return "Saída da conta"
        case "sessions_revoked_all": return "Todas as sessões encerradas"
        case "session_revoked": return "Sessão encerrada"
        case "password_change": return "Senha alterada"
        case "password_reset_request": return "Pedido de nova senha"
        case "mfa_enabled": return "Verificação em duas etapas ativada"
        case "mfa_disabled": return "Verificação em duas etapas desativada"
        case "mfa_challenge_issued": return "Código de verificação enviado"
        case "mfa_challenge_success": return "Código de verificação confirmado"
        case "mfa_challenge_fail": return "Código de verificação recusado"
        case "phone_verified": return "Celular confirmado"
        case "phone_removed": return "Celular removido"
        case "email_verified": return "E-mail confirmado"
        case "email_changed": return "E-mail alterado"
        case "google_login_ok": return "Entrada com Google"
        case "register": return "Conta criada"
        default: return "Atividade na conta"
        }
    }

    /// Tipo de consentimento legível.
    static func rotulo(consentimento tipo: String) -> String {
        switch tipo {
        case "terms": return "Termos de uso"
        case "privacy": return "Política de privacidade"
        case "lgpd": return "LGPD"
        case "marketing": return "Ofertas e novidades"
        case "cookies_analytics": return "Cookies de análise"
        case "cookies_marketing": return "Cookies de marketing"
        default: return "Consentimento"
        }
    }
}
