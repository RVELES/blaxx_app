//
//  BXFonte.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Tipografia com um ÚNICO ponto de troca de família (decisão D16 do dono):
//  - `.sistema` (padrão): SF Pro (condensado nos títulos de capa e de página) + SF Mono;
//  - `.embarcada`: Archivo variável (eixos wght/wdth) + Space Mono, as fontes do web,
//    já no bundle (Resources/Fonts) e registradas em UIAppFonts.
//  Trocar `BXFonte.modoPadrao` para `.embarcada` é a única mudança necessária.
//  Em DEBUG, o argumento `-BXFonteEmbarcada` liga o modo embarcado para comparar nas fotos.
//
//  Toda fonte acompanha o Dynamic Type (`@ScaledMetric(relativeTo:)` com o pt base do web).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

nonisolated enum BXFonte {
    enum Modo: Sendable { case sistema, embarcada }

    /// ← ÚNICA linha a trocar para Archivo + Space Mono (D16).
    // D16 (22/10): Archivo + Space Mono, as mesmas do web (OFL, em Resources/Fonts)
    static let modoPadrao: Modo = .embarcada

    /// Modo efetivo. Em DEBUG, `-BXFonteEmbarcada` força o modo embarcado (só para comparação).
    static var modo: Modo {
        #if DEBUG
        if BXDemo.fonteEmbarcada { return .embarcada }
        #endif
        return modoPadrao
    }

    enum Estilo: Sendable, Hashable, CaseIterable {
        // estilos do contrato (§1.3)
        case capa, linhaMarcada, tituloPagina, tituloSecao, h2, numeroGrande, numeroDestaque,
             saldoMono, pontosBilhete, totalRecibo, tituloBilhete, nomeParceiro, valorDado,
             corpo, corpoKit, lead, botao, botaoCartao, acaoRecibo, campo,
             rotulo, rotuloSecao, rotuloAba, recibo, legenda
        // estilos acrescentados pela fundação (medidas do web que o contrato não nomeava)
        /// Rótulo da grade do cartão de embarque e dos dados do canhoto (mono 10, .1em).
        case rotuloGrade
        /// Mono 12 MAIÚSC (rótulo de escala, legenda da cabeça do recibo, dica do painel).
        case rotuloMedio
        /// "pts" ao lado dos pontos do bilhete (18/600 cinza).
        case sufixoPontos
        /// Tarifa do bilhete (22/700).
        case tarifa
        /// Palavra da escala da rota (34/800).
        case palavraEscala
        /// Linha do quadro preto (mono 13 MAIÚSC).
        case quadro
        /// Título do rodapé do quadro e de bloco preto (20/800).
        case tituloQuadro
        /// Título do bloco "Pronto para embarcar?" (24/800).
        case tituloConvite
        /// Campo de busca grande (18/600).
        case campoBusca
        /// Mono 13/700 (chip de status, contador).
        case monoForte
        /// Texto 16/600 (item de gaveta, "Meus favoritos").
        case item
    }

    enum Familia: Sendable { case sans(largura: CGFloat), mono }

    struct Spec: Sendable {
        let tamanho: CGFloat
        /// Peso no eixo wght (400…900); o modo sistema mapeia para `Font.Weight`.
        let peso: Int
        let familia: Familia
        /// Tracking em em (−0,03 = −3 %).
        let tracking: CGFloat
        let maiusculas: Bool
        let relativo: Font.TextStyle
        /// Altura de linha como múltiplo do tamanho para textos de várias linhas (nil = natural).
        let entrelinha: CGFloat?
    }

    static func spec(_ e: Estilo) -> Spec {
        switch e {
        case .capa:           return Spec(tamanho: 54, peso: 900, familia: .sans(largura: 80), tracking: -0.03, maiusculas: false, relativo: .largeTitle, entrelinha: nil)
        case .linhaMarcada:   return Spec(tamanho: 54 * 0.66, peso: 900, familia: .sans(largura: 80), tracking: -0.03, maiusculas: false, relativo: .largeTitle, entrelinha: nil)
        case .tituloPagina:   return Spec(tamanho: 30, peso: 800, familia: .sans(largura: 88), tracking: -0.03, maiusculas: false, relativo: .title, entrelinha: 1.0)
        case .tituloSecao:    return Spec(tamanho: 32, peso: 800, familia: .sans(largura: 100), tracking: -0.03, maiusculas: false, relativo: .title, entrelinha: 1.0)
        case .h2:             return Spec(tamanho: 22, peso: 800, familia: .sans(largura: 100), tracking: -0.02, maiusculas: false, relativo: .title2, entrelinha: 1.1)
        case .numeroGrande:   return Spec(tamanho: 40, peso: 800, familia: .sans(largura: 100), tracking: -0.04, maiusculas: false, relativo: .largeTitle, entrelinha: nil)
        case .numeroDestaque: return Spec(tamanho: 44, peso: 900, familia: .sans(largura: 100), tracking: -0.02, maiusculas: false, relativo: .largeTitle, entrelinha: nil)
        case .saldoMono:      return Spec(tamanho: 44, peso: 700, familia: .mono, tracking: 0, maiusculas: false, relativo: .largeTitle, entrelinha: nil)
        case .pontosBilhete:  return Spec(tamanho: 34, peso: 800, familia: .sans(largura: 100), tracking: -0.02, maiusculas: false, relativo: .title, entrelinha: nil)
        case .totalRecibo:    return Spec(tamanho: 36, peso: 900, familia: .sans(largura: 100), tracking: -0.03, maiusculas: false, relativo: .title, entrelinha: nil)
        case .tituloBilhete:  return Spec(tamanho: 19, peso: 800, familia: .sans(largura: 100), tracking: -0.01, maiusculas: false, relativo: .headline, entrelinha: 1.15)
        case .nomeParceiro:   return Spec(tamanho: 17, peso: 800, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .headline, entrelinha: nil)
        case .valorDado:      return Spec(tamanho: 14, peso: 700, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .subheadline, entrelinha: 1.3)
        case .corpo:          return Spec(tamanho: 15, peso: 400, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .body, entrelinha: 1.5)
        case .corpoKit:       return Spec(tamanho: 16, peso: 400, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .body, entrelinha: 1.5)
        case .lead:           return Spec(tamanho: 16, peso: 400, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .body, entrelinha: 1.5)
        case .botao:          return Spec(tamanho: 15, peso: 700, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .body, entrelinha: nil)
        case .botaoCartao:    return Spec(tamanho: 16, peso: 700, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .body, entrelinha: nil)
        case .acaoRecibo:     return Spec(tamanho: 17, peso: 700, familia: .sans(largura: 100), tracking: 0.02, maiusculas: true, relativo: .body, entrelinha: nil)
        case .campo:          return Spec(tamanho: 16, peso: 500, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .body, entrelinha: nil)
        case .rotulo:         return Spec(tamanho: 11, peso: 400, familia: .mono, tracking: 0.10, maiusculas: true, relativo: .caption2, entrelinha: nil)
        case .rotuloSecao:    return Spec(tamanho: 13, peso: 400, familia: .mono, tracking: 0.08, maiusculas: true, relativo: .footnote, entrelinha: nil)
        case .rotuloAba:      return Spec(tamanho: 11, peso: 400, familia: .mono, tracking: 0.04, maiusculas: true, relativo: .caption2, entrelinha: nil)
        case .recibo:         return Spec(tamanho: 13, peso: 400, familia: .mono, tracking: 0, maiusculas: false, relativo: .footnote, entrelinha: nil)
        case .legenda:        return Spec(tamanho: 12, peso: 400, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .caption, entrelinha: 1.5)
        case .rotuloGrade:    return Spec(tamanho: 10, peso: 400, familia: .mono, tracking: 0.10, maiusculas: true, relativo: .caption2, entrelinha: nil)
        case .rotuloMedio:    return Spec(tamanho: 12, peso: 400, familia: .mono, tracking: 0.08, maiusculas: true, relativo: .caption, entrelinha: nil)
        case .sufixoPontos:   return Spec(tamanho: 18, peso: 600, familia: .sans(largura: 100), tracking: -0.02, maiusculas: false, relativo: .headline, entrelinha: nil)
        case .tarifa:         return Spec(tamanho: 22, peso: 700, familia: .sans(largura: 100), tracking: -0.01, maiusculas: false, relativo: .title2, entrelinha: nil)
        case .palavraEscala:  return Spec(tamanho: 34, peso: 800, familia: .sans(largura: 100), tracking: -0.02, maiusculas: false, relativo: .title, entrelinha: nil)
        case .quadro:         return Spec(tamanho: 13, peso: 400, familia: .mono, tracking: 0, maiusculas: true, relativo: .footnote, entrelinha: nil)
        case .tituloQuadro:   return Spec(tamanho: 20, peso: 800, familia: .sans(largura: 100), tracking: -0.02, maiusculas: false, relativo: .title3, entrelinha: 1.1)
        case .tituloConvite:  return Spec(tamanho: 24, peso: 800, familia: .sans(largura: 100), tracking: -0.02, maiusculas: false, relativo: .title2, entrelinha: 1.1)
        case .campoBusca:     return Spec(tamanho: 18, peso: 600, familia: .sans(largura: 100), tracking: -0.01, maiusculas: false, relativo: .body, entrelinha: nil)
        case .monoForte:      return Spec(tamanho: 11, peso: 700, familia: .mono, tracking: 0.08, maiusculas: true, relativo: .caption2, entrelinha: nil)
        case .item:           return Spec(tamanho: 16, peso: 600, familia: .sans(largura: 100), tracking: 0, maiusculas: false, relativo: .body, entrelinha: nil)
        }
    }

    // MARK: fonte concreta

    static func pesoSistema(_ wght: Int) -> Font.Weight {
        switch wght {
        case 900...: return .black
        case 800..<900: return .heavy
        case 700..<800: return .bold
        case 600..<700: return .semibold
        case 500..<600: return .medium
        default: return .regular
        }
    }

    /// Fonte do estilo num tamanho já escalado pelo Dynamic Type.
    static func fonte(_ e: Estilo, tamanho: CGFloat) -> Font {
        let s = spec(e)
        if modo == .embarcada, let f = fonteEmbarcada(s, tamanho: tamanho) {
            return f
        }
        switch s.familia {
        case .mono:
            return .system(size: tamanho, weight: pesoSistema(s.peso), design: .monospaced)
        case .sans(let largura):
            return .system(size: tamanho, weight: pesoSistema(s.peso))
                .width(largura < 95 ? .condensed : .standard)
        }
    }

    private static func fonteEmbarcada(_ s: Spec, tamanho: CGFloat) -> Font? {
        #if canImport(UIKit)
        guard let ui = uiFontEmbarcada(s, tamanho: tamanho) else { return nil }
        return Font(ui as CTFont)
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    private static func uiFontEmbarcada(_ s: Spec, tamanho: CGFloat) -> UIFont? {
        switch s.familia {
        case .mono:
            return UIFont(name: s.peso >= 700 ? "SpaceMono-Bold" : "SpaceMono-Regular", size: tamanho)
        case .sans(let largura):
            // Archivo variável: eixos 'wght' (0x77676874) e 'wdth' (0x77647468).
            let variacao = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
            let base = UIFontDescriptor(fontAttributes: [.family: "Archivo"])
            let desc = base.addingAttributes([variacao: [0x77676874: s.peso, 0x77647468: largura]])
            let f = UIFont(descriptor: desc, size: tamanho)
            return f.familyName == "Archivo" ? f : nil
        }
    }

    /// UIFont equivalente (para medir altura de linha).
    static func uiFont(_ e: Estilo, tamanho: CGFloat) -> UIFont {
        let s = spec(e)
        if modo == .embarcada, let f = uiFontEmbarcada(s, tamanho: tamanho) { return f }
        let w: UIFont.Weight
        switch pesoSistema(s.peso) {
        case .black: w = .black
        case .heavy: w = .heavy
        case .bold: w = .bold
        case .semibold: w = .semibold
        case .medium: w = .medium
        default: w = .regular
        }
        switch s.familia {
        case .mono: return .monospacedSystemFont(ofSize: tamanho, weight: w)
        case .sans(let largura): return .systemFont(ofSize: tamanho, weight: w, width: largura < 95 ? .condensed : .standard)
        }
    }
    #endif

    /// Altura natural da linha (ascendente + descendente + entrelinha) da fonte do estilo.
    static func alturaLinha(_ e: Estilo, tamanho: CGFloat) -> CGFloat {
        #if canImport(UIKit)
        return uiFont(e, tamanho: tamanho).lineHeight
        #else
        return tamanho * 1.2
        #endif
    }

    /// `true` quando a família embarcada foi encontrada no bundle (diagnóstico da galeria).
    static var familiaEmbarcadaDisponivel: Bool {
        #if canImport(UIKit)
        return UIFont(name: "SpaceMono-Regular", size: 12) != nil
            && UIFontDescriptor(fontAttributes: [.family: "Archivo"]).matchingFontDescriptors(withMandatoryKeys: nil).isEmpty == false
        #else
        return false
        #endif
    }
}

// MARK: - Modificador

/// Fonte + tracking + caixa + entrelinha, tudo escalado pelo Dynamic Type.
struct BXFonteModificador: ViewModifier {
    let estilo: BXFonte.Estilo
    @ScaledMetric private var tamanho: CGFloat

    init(_ estilo: BXFonte.Estilo) {
        self.estilo = estilo
        let s = BXFonte.spec(estilo)
        _tamanho = ScaledMetric(wrappedValue: s.tamanho, relativeTo: s.relativo)
    }

    func body(content: Content) -> some View {
        let s = BXFonte.spec(estilo)
        let espacamento: CGFloat = {
            guard let m = s.entrelinha else { return 0 }
            return max(0, m * tamanho - BXFonte.alturaLinha(estilo, tamanho: tamanho))
        }()
        return content
            .font(BXFonte.fonte(estilo, tamanho: tamanho))
            .tracking(s.tracking * tamanho)
            .modifier(BXCaixaAlta(ligada: s.maiusculas))
            .lineSpacing(espacamento)
    }
}

/// Só força MAIÚSCULAS quando o estilo pede; não anula uma caixa definida fora.
private struct BXCaixaAlta: ViewModifier {
    let ligada: Bool
    func body(content: Content) -> some View {
        if ligada { content.textCase(.uppercase) } else { content }
    }
}

extension View {
    /// Aplica um estilo tipográfico do tema (fonte + tracking + caixa + escala do Dynamic Type).
    func bxFonte(_ e: BXFonte.Estilo) -> some View {
        modifier(BXFonteModificador(e))
    }
}
