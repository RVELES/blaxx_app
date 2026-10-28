//
//  BXMedidas.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Raios, espaçamentos, alvos de toque, sombras e curvas de movimento do tema Embarque
//  (blaxx-embarque.css: --bx-r-*, --bx-sh*, --bx-ease; medidas a 375 px).
//  Nada de sombra dura deslocada (Neo-Brutal antigo): o Embarque usa sombra macia.
//

import SwiftUI

nonisolated enum BXRaio {
    /// Cartão de embarque e painel no celular (28 no web desktop).
    static let xl: CGFloat = 24
    /// Cartões, bilhetes, quadro, recibo, convite.
    static let lg: CGFloat = 18
    /// FAQ, toast.
    static let md: CGFloat = 14
    /// Botão, campo, ícone 44, CTA do cartão.
    static let sm: CGFloat = 12
    /// Item da gaveta, item da aba, ícone 36.
    static let xs: CGFloat = 10
    /// Pílula do kit, ícone da aba (30).
    static let xxs: CGFloat = 8
    static let pilula: CGFloat = 999
}

nonisolated enum BXEspaco {
    /// Margem lateral única (o web varia 16/22/40; o app usa 16).
    static let margem: CGFloat = 16
    /// Espaço entre seções.
    static let secao: CGFloat = 40
    /// Espaço abaixo do cabeçalho de seção.
    static let cabecalhoSecao: CGFloat = 24
    /// Padding interno de cartão.
    static let cartao: CGFloat = 18
    /// Gap de grade de cartões.
    static let grade: CGFloat = 12
    /// Coluna central máxima em paisagem, iPad e visionOS. No iPad a coluna
    /// de 560 ocupava pouco mais da metade de um 13" em pé; 680 aproveita a
    /// tela sem esticar as linhas de texto demais.
    static let colunaMax: CGFloat = {
        #if os(iOS)
        if MainActor.assumeIsolated({ UIDevice.current.userInterfaceIdiom == .pad }) { return 680 }
        #endif
        return 560
    }()
}

nonisolated enum BXToque {
    static let botao: CGFloat = 48
    static let chip: CGFloat = 44
    static let itemGaveta: CGFloat = 48
    static let itemAba: CGFloat = 52
}

nonisolated enum BXSombra: Sendable {
    /// `0 18 40 rgba(10,11,14,.08)`
    case padrao
    /// `0 24 48 rgba(10,11,14,.12)`
    case grande
    /// `0 6 16 rgba(10,11,14,.05)`
    case leve
    /// `drop-shadow(0 18 30 rgba(10,11,14,.12))` do recibo (segue o recorte).
    case recibo

    var opacidade: Double {
        switch self {
        case .padrao: return 0.08
        case .grande, .recibo: return 0.12
        case .leve: return 0.05
        }
    }
    /// Raio do desfoque do SwiftUI (≈ metade do blur do CSS).
    var raio: CGFloat {
        switch self {
        case .padrao: return 20
        case .grande: return 24
        case .leve: return 8
        case .recibo: return 15
        }
    }
    var y: CGFloat {
        switch self {
        case .padrao, .recibo: return 18
        case .grande: return 24
        case .leve: return 6
        }
    }
}

extension View {
    /// Sombra macia do tema. Aplicar depois do fundo (ou de `.compositingGroup()` para seguir recortes).
    func bxSombra(_ s: BXSombra) -> some View {
        shadow(color: BXCor.tinta.opacity(s.opacidade), radius: s.raio, x: 0, y: s.y)
    }
}

nonisolated enum BXMovimento {
    /// `--bx-ease` (cubic-bezier(.2,.75,.2,1)), 0,22 s.
    static let ease = Animation.timingCurve(0.2, 0.75, 0.2, 1, duration: 0.22)
    /// Gaveta: ease-out 0,2 s.
    static let gaveta = Animation.easeOut(duration: 0.2)
    /// Letreiro da capa: 0,55 s.
    static let letreiro = Animation.timingCurve(0.2, 0.75, 0.2, 1, duration: 0.55)
    /// Mola curta para seleção (bilhete, pílula, aba).
    static let mola = Animation.spring(response: 0.36, dampingFraction: 0.82)

    /// Devolve `nil` (sem animação) quando "Reduzir movimento" está ligado.
    static func ou(_ a: Animation, reduzido: Bool) -> Animation? {
        reduzido ? nil : a
    }
}
