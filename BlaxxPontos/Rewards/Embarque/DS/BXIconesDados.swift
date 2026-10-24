//
//  BXIconesDados.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Os 57 desenhos de ícone do tema: as 51 entradas de docs/redesenho/icones.json
//  (objeto ICONES de blaxx/assets/blaxx-nav.js + `menu` da barra de abas) e os 6 desenhos
//  inline do web listados no Anexo A de 02-inventario-web-mobile.md.
//  viewBox 0 0 24 24, fill none, stroke currentColor, traço 1,8 (menu e setas do extrato: 2), round.
//

import SwiftUI

nonisolated enum BXIconeNome: String, CaseIterable, Sendable, Hashable {
    case inicio, carteira, extrato, parceiros, resgates, voucher, campanhas, comprar, enviar, receber,
         indique, perfil, seguranca, ajuda, sair, notificacoes, cartao, check, alerta, erro, info, estrela,
         email, chat, documento, anexo, festa, raio, carrinho, aviao, hotel, posto, farmacia, supermercado,
         filme, moda, local, loja, mais, seta, grafico, relogio, calendario, tag, favorito, celular, busca,
         configuracoes, trocar, usuarioMais = "usuario_mais", menu,
         setaCima, setaBaixo, visto, chave, semMensalidade, prancheta
}

nonisolated enum BXIconesDados {

    /// Traço em unidades do viewBox (1,8 por padrão).
    static func traco(_ n: BXIconeNome) -> CGFloat {
        switch n {
        case .menu, .setaCima, .setaBaixo: return 2
        default: return 1.8
        }
    }

    /// Conteúdo interno do `<svg>` de cada desenho, copiado sem alteração do web.
    static func svg(_ n: BXIconeNome) -> String {
        switch n {
        case .inicio: return #"<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V20h14V9.5"/><path d="M9.5 20v-5h5v5"/>"#
        case .carteira: return #"<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 9h18"/><circle cx="17" cy="13.5" r="1.4" fill="currentColor" stroke="none"/>"#
        case .extrato: return #"<path d="M4 20V4"/><path d="M4 20h16"/><rect x="7" y="12" width="3" height="5"/><rect x="12" y="8" width="3" height="9"/><rect x="17" y="5" width="3" height="12"/>"#
        case .parceiros: return #"<circle cx="8" cy="9" r="3"/><circle cx="16" cy="9" r="3"/><path d="M3 19c0-2.8 2.2-4.5 5-4.5s5 1.7 5 4.5"/><path d="M13.5 14.8c2.4-.4 4.5 1.2 4.5 4.2"/>"#
        case .resgates: return #"<rect x="3.5" y="9" width="17" height="11" rx="2"/><path d="M3 9h18M12 9v11"/><path d="M12 9C9 9 7 5 9.5 4.2 11 3.7 12 6.5 12 9c0-2.5 1-5.3 2.5-4.8C17 5 15 9 12 9Z"/>"#
        case .voucher: return #"<path d="M4 7h16v3a2 2 0 0 0 0 4v3H4v-3a2 2 0 0 0 0-4Z"/><path d="M14 7v10" stroke-dasharray="2 2.4"/>"#
        case .campanhas: return #"<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/>"#
        case .comprar: return #"<ellipse cx="9" cy="7" rx="5.5" ry="2.6"/><path d="M3.5 7v5c0 1.4 2.5 2.6 5.5 2.6s5.5-1.2 5.5-2.6V7"/><path d="M9 14.6v2.8c0 1.4 2.5 2.6 5.5 2.6s5.5-1.2 5.5-2.6V11"/>"#
        case .enviar: return #"<path d="M20 4 3.5 10.8c-.8.3-.8 1.5.1 1.7l6.4 1.6 1.6 6.4c.2.9 1.4.9 1.7.1L20 4Z"/><path d="m20 4-9.9 10.1"/>"#
        case .receber: return #"<path d="M12 4v11"/><path d="m7 10 5 5 5-5"/><path d="M4 19h16"/>"#
        case .indique: return #"<path d="M12 20S4 14.5 4 9.2A4.2 4.2 0 0 1 12 7a4.2 4.2 0 0 1 8 2.2C20 14.5 12 20 12 20Z"/>"#
        case .perfil: return #"<circle cx="12" cy="8" r="3.6"/><path d="M5 20c0-3.6 3.1-5.5 7-5.5s7 1.9 7 5.5"/>"#
        case .seguranca: return #"<path d="M12 3 5 6v6c0 4.3 3 7.2 7 9 4-1.8 7-4.7 7-9V6Z"/><path d="m9.2 12 2 2 3.6-3.8"/>"#
        case .ajuda: return #"<circle cx="12" cy="12" r="8.5"/><path d="M9.6 9.4a2.4 2.4 0 0 1 4.6.9c0 1.6-2.2 1.8-2.2 3.3"/><circle cx="12" cy="16.6" r="0.6" fill="currentColor" stroke="none"/>"#
        case .sair: return #"<path d="M15 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h9"/><path d="M10 12h11m0 0-3.5-3.5M21 12l-3.5 3.5"/>"#
        case .notificacoes: return #"<path d="M6 16V10a6 6 0 0 1 12 0v6l1.5 2.2H4.5Z"/><path d="M10 19a2 2 0 0 0 4 0"/>"#
        case .cartao: return #"<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="M3 10h18M7 15h4"/>"#
        case .check: return #"<path d="m5 12.5 4.5 4.5L19 7.5"/>"#
        case .alerta: return #"<path d="M12 4 2.8 19.5h18.4Z"/><path d="M12 10v4.2"/><circle cx="12" cy="16.8" r="0.6" fill="currentColor" stroke="none"/>"#
        case .erro: return #"<circle cx="12" cy="12" r="8.5"/><path d="m9 9 6 6M15 9l-6 6"/>"#
        case .info: return #"<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5"/><circle cx="12" cy="7.8" r="0.6" fill="currentColor" stroke="none"/>"#
        case .estrela: return #"<path d="m12 3.8 2.5 5.2 5.7.8-4.1 4 1 5.7-5.1-2.7-5.1 2.7 1-5.7-4.1-4 5.7-.8Z"/>"#
        case .email: return #"<rect x="3" y="5.5" width="18" height="13" rx="2"/><path d="m3.5 6.5 8.5 6.5 8.5-6.5"/>"#
        case .chat: return #"<path d="M4 5h16v11H9l-5 4Z"/><path d="M8 9.5h8M8 12.5h5"/>"#
        case .documento: return #"<path d="M6 3h8l4 4v14H6Z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>"#
        case .anexo: return #"<path d="M20 11.5 12 19.5a5 5 0 0 1-7-7l8.5-8.5a3.3 3.3 0 0 1 4.7 4.7L9.8 17.1a1.7 1.7 0 0 1-2.4-2.4L15 7"/>"#
        case .festa: return #"<path d="M4 20 9 7l8 8Z"/><path d="M14 4.5v.5M19 9.5h.5M16.5 6.5l1-1M12.5 8.5c1-1.5.5-3-.5-4M15.5 11.5c1.5-1 3-.5 4 .5"/>"#
        case .raio: return #"<path d="M13 3 5 13.5h6L10 21l8-10.5h-6Z"/>"#
        case .carrinho: return #"<circle cx="9" cy="19.5" r="1.4"/><circle cx="17" cy="19.5" r="1.4"/><path d="M3 4h2.5l2.2 11h10.8l2-7.5H6.6"/>"#
        case .aviao: return #"<path d="M21 15.5 13.5 11V5.5a1.5 1.5 0 0 0-3 0V11L3 15.5V17l7.5-2.2V19l-2 1.5V22l3.5-1 3.5 1v-1.5l-2-1.5v-4.2L21 17Z"/>"#
        case .hotel: return #"<path d="M3 19V6M21 19v-5a3 3 0 0 0-3-3h-8v5"/><path d="M3 14h18"/><circle cx="6.5" cy="10.5" r="1.8"/>"#
        case .posto: return #"<path d="M5 20V5a1.5 1.5 0 0 1 1.5-1.5h6A1.5 1.5 0 0 1 14 5v15M3.5 20h12"/><path d="M5 10h9M14 8l3 3v6.5a1.5 1.5 0 0 0 3 0V9l-2.5-2.5"/>"#
        case .farmacia: return #"<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M12 8v8M8 12h8"/>"#
        case .supermercado: return #"<path d="M4 9h16l-1.5 10.5h-13Z"/><path d="M8.5 9 11 4.5M15.5 9 13 4.5"/>"#
        case .filme: return #"<rect x="3.5" y="5" width="17" height="14" rx="2"/><path d="M7.5 5v14M16.5 5v14M3.5 9.5h4M3.5 14.5h4M16.5 9.5h4M16.5 14.5h4"/>"#
        case .moda: return #"<path d="M4.5 12.5 12 5h7.5v7.5L12 20Z"/><circle cx="15.5" cy="8.5" r="1.2"/>"#
        case .local: return #"<path d="M12 21s-6.5-6.1-6.5-11a6.5 6.5 0 0 1 13 0c0 4.9-6.5 11-6.5 11Z"/><circle cx="12" cy="10" r="2.4"/>"#
        case .loja: return #"<path d="M4 9.5 5.5 4h13L20 9.5"/><path d="M4 9.5a2.7 2.7 0 0 0 5.3 0 2.7 2.7 0 0 0 5.4 0 2.7 2.7 0 0 0 5.3 0"/><path d="M5.5 11.5V20h13v-8.5M10 20v-5h4v5"/>"#
        case .mais: return #"<path d="M12 5v14M5 12h14"/>"#
        case .seta: return #"<path d="M5 12h14m0 0-5-5m5 5-5 5"/>"#
        case .grafico: return #"<path d="M4 19 9.5 12l4 3.5L20 6.5"/><path d="M15.5 6.5H20V11"/>"#
        case .relogio: return #"<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>"#
        case .calendario: return #"<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>"#
        case .tag: return #"<path d="M3.5 12.5 12 4h8v8l-8.5 8.5Z"/><circle cx="16" cy="8" r="1.2"/>"#
        case .favorito: return #"<path d="M12 20S4 14.5 4 9.2A4.2 4.2 0 0 1 12 7a4.2 4.2 0 0 1 8 2.2C20 14.5 12 20 12 20Z"/>"#
        case .celular: return #"<rect x="6.5" y="2.5" width="11" height="19" rx="2.5"/><path d="M10.5 18.5h3"/>"#
        case .busca: return #"<circle cx="11" cy="11" r="6"/><path d="m20 20-4.5-4.5"/>"#
        case .configuracoes: return #"<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M5.5 18.5l1.7-1.7M16.8 7.2l1.7-1.7"/>"#
        case .trocar: return #"<path d="M4 8h13m0 0-3.5-3.5M17 8l-3.5 3.5"/><path d="M20 16H7m0 0 3.5-3.5M7 16l3.5 3.5"/>"#
        case .usuarioMais: return #"<circle cx="10" cy="8" r="3.6"/><path d="M3.5 20c0-3.6 2.9-5.5 6.5-5.5 1.6 0 3 .4 4.1 1"/><path d="M18 14v6M15 17h6"/>"#
        case .menu: return #"<path d="M4 7h16M4 12h16M4 17h16"/>"#
        // Anexo A: desenhos inline do web
        case .setaCima: return #"<path d="M12 19V5M5 12l7-7 7 7"/>"#
        case .setaBaixo: return #"<path d="M12 5v14M5 12l7 7 7-7"/>"#
        case .visto: return #"<path d="M4 12.5 9.5 18 20 6"/>"#
        case .chave: return #"<circle cx="8" cy="15" r="4"/><path d="M11 12 20 3"/><path d="M16 7l3 3M13 10l2.5 2.5"/>"#
        case .semMensalidade: return #"<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/><path d="m9.5 13.5 5 5M14.5 13.5l-5 5"/>"#
        case .prancheta: return #"<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 3h6v3H9Z"/><path d="M9 11h6M9 15h6"/>"#
        }
    }

    /// Desenhos já convertidos em `Path`, montados uma vez (static let é preguiçoso e seguro entre threads).
    static let elementos: [BXIconeNome: [BXSVG.Elemento]] = {
        var r: [BXIconeNome: [BXSVG.Elemento]] = [:]
        for n in BXIconeNome.allCases { r[n] = BXSVG.elementos(svg(n), tracoPadrao: true) }
        return r
    }()

    static let caixa = CGRect(x: 0, y: 0, width: 24, height: 24)
}
