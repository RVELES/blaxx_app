//
//  RewardsTheme.swift
//  BlaxxPontos
//
//  Theme tokens for the "BlaXx Rewards" native experience — literal colors
//  copied verbatim from the HTML prototype's :root CSS variables.
//  Self-contained / prefixed (RW…) so nothing collides with the existing app.
//

import SwiftUI

enum RWColor {
    // Neo-Brutal: neon oficial #59FD27 (Brand Book — corrige o typo #59FC27).
    static let neon       = Color(hex: 0x59FD27)   // --neon (oficial)
    static let neonA      = Color(hex: 0x6BFF3D)   // --neon-a (gradient top)
    static let neonB      = Color(hex: 0x34D60F)   // --neon-b (gradient bottom)
    static let ink        = Color(hex: 0x0A0B0E)   // --ink (preto oficial Brand Book)
    static let ink2       = Color(hex: 0x0A0B0E)   // --ink-2
    static let screenBg   = Color(hex: 0xE8E6DD)   // fundo PAPEL (Neo-Brutal)
    static let greenLight = Color(hex: 0x2BA014)   // --green-light
    static let bonus      = Color(hex: 0x2BA516)   // --bonus
    static let muted      = Color(hex: 0x9AA092)   // --muted
    static let amber      = Color(hex: 0xE8A317)   // --amber

    // Frequently used neutrals from the stylesheet.
    static let cardShadow = Color(hex: 0x0A0B0E).opacity(0.9) // Neo-Brutal: sombra dura (tinta sólida)
    static let heroSub    = Color(hex: 0x9DA39A)   // hero label / pts
    static let heroNum    = Color(hex: 0xB9BDB5)   // ",00" inside hero
    static let rowBrl     = Color(hex: 0x8A9082)
    static let rowExpiry  = Color(hex: 0xA8ACA2)
    static let chipBorder = Color(hex: 0xE6E8E3)
    static let chipSelBg  = Color(hex: 0xEBFFE2)
    static let pctBg      = Color(hex: 0xF1F3ED)
    static let pctFg      = Color(hex: 0x3C4038)
    static let fieldLabel = Color(hex: 0x8D9388)
    static let chipPts    = Color(hex: 0xA3A89D)
    static let segFg      = Color(hex: 0x8A9082)
    static let breakdownK = Color(hex: 0x7B8278)
    static let countdownBg = Color(hex: 0xFFF4DE)
    static let countdownFg = Color(hex: 0x9A6B00)
    static let simBg      = Color(hex: 0xF6F8F2)
    static let searchBg   = Color(hex: 0xF1F3ED)
    static let txDivider  = Color(hex: 0xF1F3ED)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x16181A), Color(hex: 0x0A0B0C)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let fabGradient = LinearGradient(
        colors: [neonA, neonB],
        startPoint: UnitPoint(x: 0.15, y: 0.0), endPoint: UnitPoint(x: 0.85, y: 1.0))
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// pt-BR number formatting helpers (thousands with ".", currency "R$").
enum RWFormat {
    static let nf: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        f.maximumFractionDigits = 0
        return f
    }()

    /// Equivalent of JS `fmt`: rounds and groups with pt-BR separators.
    static func n(_ value: Double) -> String {
        nf.string(from: NSNumber(value: value.rounded())) ?? "0"
    }
    static func n(_ value: Int) -> String { n(Double(value)) }
}

/// Neo-Brutal: sombra DURA deslocada (sem blur → radius 0), assinatura do estilo.
/// Cascateia para todo card que usa .rwCardShadow().
extension View {
    func rwCardShadow() -> some View {
        shadow(color: RWColor.cardShadow, radius: 0, x: 5, y: 5)
    }

    /// Cartão brutalista completo: borda tinta grossa + sombra dura + cantos quase retos.
    func rwBrutalCard(corner: CGFloat = 4, border: CGFloat = 2.5) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(RWColor.ink, lineWidth: border)
            )
            .rwCardShadow()
    }
}
