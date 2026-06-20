//
//  Theme.swift
//  BlaxxPontos
//
//  Design system Blaxx — paleta oficial extraída de Blaxx_Pontos_Projeto.pdf (seção 11.2).
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

enum BlaxxColor {
    // Pretos
    static let black       = Color(red: 0.039, green: 0.039, blue: 0.039)   // #0A0A0A
    static let blackSoft   = Color(red: 0.102, green: 0.102, blue: 0.102)   // #1A1A1A

    // Verde-limão Blaxx (acento institucional)
    static let lime        = Color(red: 0.486, green: 1.000, blue: 0.000)   // #7CFF00
    static let limeDark    = Color(red: 0.353, green: 0.722, blue: 0.000)   // #5AB800
    static let limeLight   = Color(red: 0.941, green: 0.980, blue: 0.851)   // #F0FAD9

    // Cinzas
    static let white       = Color.white
    static let gray50      = Color(red: 0.980, green: 0.980, blue: 0.980)   // #FAFAFA
    static let gray100     = Color(red: 0.957, green: 0.957, blue: 0.961)   // #F4F4F5
    static let gray200     = Color(red: 0.898, green: 0.898, blue: 0.898)   // #E5E5E5
    static let gray400     = Color(red: 0.631, green: 0.631, blue: 0.667)   // #A1A1AA
    static let gray600     = Color(red: 0.322, green: 0.322, blue: 0.322)   // #525252
    static let gray800     = Color(red: 0.149, green: 0.149, blue: 0.149)   // #262626

    // Semânticas
    static let negative    = Color(red: 0.863, green: 0.149, blue: 0.149)   // #DC2626
    static let warning     = Color(red: 0.961, green: 0.620, blue: 0.043)   // #F59E0B
    static let positive    = Color(red: 0.086, green: 0.639, blue: 0.290)   // #16A34A (verde real)

    // Tema light — superfícies e bordas
    static let appBg       = Color(red: 0.965, green: 0.969, blue: 0.957)   // #F6F7F4
    static let border      = Color(red: 0.925, green: 0.925, blue: 0.925)   // #ECECEC

    // Sidebar clara (tema light)
    static let sidebarBg        = white
    static let sidebarBorder    = Color(red: 0.929, green: 0.929, blue: 0.929) // #EDEDED
    static let sidebarItem      = gray600
    static let sidebarItemHover = Color(red: 0.957, green: 0.961, blue: 0.945)  // #F4F5F1
}

enum BlaxxFont {
    /// Playfair Display se estiver instalada, senão cai pro system serif (New York no macOS).
    /// Em produção, embarcar a fonte Playfair Display nos resources do app.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        #if canImport(AppKit)
        let installed = NSFont(name: "Playfair Display", size: size) != nil
        #elseif canImport(UIKit)
        let installed = UIFont(name: "Playfair Display", size: size) != nil
        #else
        let installed = false
        #endif
        if installed {
            return Font.custom("Playfair Display", size: size).weight(weight)
        }
        return Font.system(size: size, weight: weight, design: .serif)
    }

    /// Sans-serif para corpo — SF Pro (nativo do sistema).
    static func body(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    /// Para microlabels em caixa alta com tracking.
    static func eyebrow() -> Font {
        Font.system(size: 11, weight: .semibold, design: .default)
    }

    static func mono(_ size: CGFloat = 12) -> Font {
        Font.system(size: size, weight: .regular, design: .monospaced)
    }
}

// MARK: - Modificadores reutilizáveis

struct EyebrowModifier: ViewModifier {
    var color: Color = BlaxxColor.limeDark
    func body(content: Content) -> some View {
        content
            .font(BlaxxFont.eyebrow())
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    func eyebrow(_ color: Color = BlaxxColor.limeDark) -> some View {
        modifier(EyebrowModifier(color: color))
    }
}

// MARK: - Estilos de botão

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(BlaxxColor.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Capsule().fill(configuration.isPressed
                               ? BlaxxColor.limeDark
                               : BlaxxColor.lime)
            )
    }
}

struct DarkButtonStyle: ButtonStyle {
    var fullWidth: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(BlaxxColor.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Capsule().fill(configuration.isPressed
                               ? BlaxxColor.blackSoft
                               : BlaxxColor.black)
            )
    }
}

struct GhostButtonStyle: ButtonStyle {
    var onDark: Bool = false
    var fullWidth: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(onDark ? BlaxxColor.white : BlaxxColor.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Capsule().stroke(onDark
                                 ? Color.white.opacity(0.18)
                                 : BlaxxColor.gray200, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Wordmark da marca (nativo, sem "Pontos")

/// Wordmark "BlaXx" em duas cores — substitui o antigo Image("BlaxxLogoDark").
/// Paridade com o BlaxxBrand (SVG) do app web: "Bla" neutro + acento neon em "Xx".
/// tone .dark → fundo claro (ink + #5AB800);  tone .light → fundo escuro (branco + #7CFF00).
struct BlaxxWordmark: View {
    enum Tone { case light, dark }

    var size: CGFloat = 28
    var tone: Tone = .dark

    private var blaColor: Color { tone == .light ? .white : BlaxxColor.black }
    private var xxColor: Color { tone == .light ? BlaxxColor.lime : BlaxxColor.limeDark }

    var body: some View {
        (Text("Bla").foregroundColor(blaColor)
         + Text("Xx").foregroundColor(xxColor))
            .font(BlaxxFont.display(size, weight: .black))
            .accessibilityLabel("BlaXx")
    }
}
