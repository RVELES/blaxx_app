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

    // Verde neon Blaxx — verde OFICIAL da marca (acento institucional)
    static let lime        = Color(red: 0.349, green: 0.992, blue: 0.153)   // #59FD27
    static let limeDark    = Color(red: 0.353, green: 0.722, blue: 0.000)   // #5AB800
    static let limeLight   = Color(red: 0.941, green: 0.980, blue: 0.851)   // #F0FAD9

    // Cinzas — neutros quentes (substituem a rampa Zinc fria, tell de template)
    static let white       = Color.white
    static let gray50      = Color(red: 0.969, green: 0.969, blue: 0.957)   // #F7F7F4
    static let gray100     = Color(red: 0.937, green: 0.937, blue: 0.918)   // #EFEFEA
    static let gray200     = Color(red: 0.886, green: 0.882, blue: 0.859)   // #E2E1DB
    static let gray400     = Color(red: 0.604, green: 0.596, blue: 0.557)   // #9A988E
    static let gray600     = Color(red: 0.349, green: 0.341, blue: 0.314)   // #595750
    static let gray800     = Color(red: 0.137, green: 0.133, blue: 0.125)   // #232220

    // Semânticas
    static let negative    = Color(red: 0.863, green: 0.149, blue: 0.149)   // #DC2626
    static let warning     = Color(red: 0.961, green: 0.620, blue: 0.043)   // #F59E0B
    static let positive    = Color(red: 0.086, green: 0.639, blue: 0.290)   // #16A34A (verde real)

    // Tema light — superfícies e bordas (neutros quentes)
    static let appBg       = Color(red: 0.957, green: 0.957, blue: 0.941)   // #F4F4F0
    static let border      = Color(red: 0.894, green: 0.890, blue: 0.867)   // #E4E3DD

    // Sidebar clara (tema light)
    static let sidebarBg        = white
    static let sidebarBorder    = Color(red: 0.929, green: 0.929, blue: 0.929) // #EDEDED
    static let sidebarItem      = gray600
    static let sidebarItemHover = Color(red: 0.957, green: 0.961, blue: 0.945)  // #F4F5F1

    // MARK: Tema CLARO Neo-Brutal (área logada)
    //
    // Extraído de design/blaxx-area-logada-prototipo.html. A ideia: fundo "papel"
    // creme, superfícies brancas com borda preta GROSSA + sombra dura deslocada
    // (sem blur) e cantos quase retos. O neon (#59FD27) segue como acento; o verde
    // do wordmark (#5AB800 / #F0FAD9) permanece intocado (regra da marca).
    // Tokens novos e aditivos — nada aqui altera as cores já usadas em outras telas.
    static let paper       = Color(red: 0.910, green: 0.902, blue: 0.867)   // #E8E6DD  fundo papel
    static let ink         = Color(red: 0.039, green: 0.043, blue: 0.055)   // #0A0B0E  linha/texto brutal (preto oficial)
    static let brutalLine  = ink                                            // alias semântico p/ bordas
    static let paperLine   = Color(red: 0.847, green: 0.835, blue: 0.784)   // #D8D5C8  divisória sutil sobre papel
    static let brutalMuted = Color(red: 0.357, green: 0.376, blue: 0.345)   // #5B6058  microlabel/mono sobre papel
    static let brutalPos   = Color(red: 0.122, green: 0.478, blue: 0.071)   // #1F7A12  valor positivo
    static let brutalNeg   = Color(red: 0.659, green: 0.204, blue: 0.090)   // #A83417  valor negativo
}

enum BlaxxFont {
    /// Space Grotesk embarcada em Resources/Fonts/SpaceGrotesk.ttf (UIAppFonts /
    /// ATSApplicationFontsPath no Info.plist). O TTF é variável com instância
    /// default Light: família "Space Grotesk Light", PostScript
    /// "SpaceGrotesk-Light", família tipográfica "Space Grotesk" — por isso
    /// tentamos os nomes em ordem. Se nada resolver, cai pro system sans (SF Pro).
    /// "Grotesque técnico": display/números em grotesca, NUNCA serifada (o serif
    /// era o tell genérico).
    private static let displayFontName: String? = {
        let candidates = ["Space Grotesk", "SpaceGrotesk-Light", "Space Grotesk Light"]
        for name in candidates {
            #if canImport(AppKit)
            if NSFont(name: name, size: 17) != nil { return name }
            #elseif canImport(UIKit)
            if UIFont(name: name, size: 17) != nil { return name }
            #endif
        }
        return nil
    }()

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if let name = displayFontName {
            return Font.custom(name, size: size).weight(weight)
        }
        return Font.system(size: size, weight: weight, design: .default)
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

// MARK: - Neo-Brutal: card e botão reutilizáveis (tema claro da área logada)

/// Card brutalista: borda preta grossa + sombra dura DESLOCADA (sem blur).
/// A "sombra" é um retângulo sólido `ink` atrás, deslocado — replica o
/// `box-shadow: Npx Npx 0 var(--black)` do protótipo, que o `.shadow` do
/// SwiftUI (sempre com blur) não reproduz fielmente.
struct BrutalCardModifier: ViewModifier {
    var background: Color = BlaxxColor.white
    var padding: CGFloat = 20
    var shadow: CGFloat = 6
    var border: CGFloat = 3
    var corner: CGFloat = 2

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous).fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(BlaxxColor.ink, lineWidth: border)
            )
            .background(
                // Bloco de sombra sólido, deslocado — sem blur.
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(BlaxxColor.ink)
                    .offset(x: shadow, y: shadow)
            )
    }
}

extension View {
    /// Aplica o "card brutalista" (borda grossa + sombra dura deslocada).
    func brutalCard(background: Color = BlaxxColor.white,
                    padding: CGFloat = 20,
                    shadow: CGFloat = 6,
                    border: CGFloat = 3,
                    corner: CGFloat = 2) -> some View {
        modifier(BrutalCardModifier(background: background, padding: padding,
                                    shadow: shadow, border: border, corner: corner))
    }
}

/// Botão brutalista: preenchimento neon, borda preta grossa e sombra dura.
/// Ao pressionar "afunda" (desloca + reduz a sombra), como o `:active` da web.
struct BrutalButtonStyle: ButtonStyle {
    var fullWidth: Bool = false
    var background: Color = BlaxxColor.lime
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shadow: CGFloat = pressed ? 2 : 5
        return configuration.label
            .font(.system(size: 14, weight: .bold))
            .textCase(.uppercase)
            .kerning(0.4)
            .foregroundStyle(BlaxxColor.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Rectangle().fill(background))
            .overlay(Rectangle().stroke(BlaxxColor.ink, lineWidth: 3))
            .background(Rectangle().fill(BlaxxColor.ink).offset(x: shadow, y: shadow))
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

// MARK: - Wordmark da marca (nativo, sem "Pontos")

/// Wordmark "BlaXx" oficial — símbolo neon (blaxx_simbolo_color.svg) + texto duas cores.
/// Paridade 1:1 com o BlaxxBrand do app web (símbolo SVG oficial + "BlaXx"); o símbolo
/// neon vale para fundo claro e escuro, como na web.
/// tone .dark → fundo claro (ink + #5AB800);  tone .light → fundo escuro (branco + #59FD27).
struct BlaxxWordmark: View {
    enum Tone { case light, dark }

    var size: CGFloat = 28
    var tone: Tone = .dark

    private var blaColor: Color { tone == .light ? .white : BlaxxColor.black }
    private var xxColor: Color { tone == .light ? BlaxxColor.lime : BlaxxColor.limeDark }

    var body: some View {
        HStack(spacing: size * 0.30) {
            Image("BlaxxSymbol")
                .resizable()
                .scaledToFit()
                .frame(height: size * 1.22)
                .accessibilityHidden(true)
            (Text("Bla").foregroundColor(blaColor)
             + Text("Xx").foregroundColor(xxColor))
                .font(BlaxxFont.display(size, weight: .black))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BlaXx")
    }
}

/// Lockup vertical "BlaXx" — símbolo oficial EMPILHADO sobre o wordmark, como na
/// web. Use em heros/topo, onde a versão horizontal fica pequena demais.
/// O símbolo é neon: sobre fundo branco ele some, por isso o uso natural é
/// tone .light (sobre fundo escuro), onde a marca salta.
/// tone .light → fundo escuro (símbolo neon + "Bla" branco + "Xx" #59FD27).
/// tone .dark  → fundo claro (símbolo neon + "Bla" ink + "Xx" #5AB800).
struct BlaxxLockup: View {
    enum Tone { case light, dark }

    var symbolSize: CGFloat = 52
    var fontSize: CGFloat = 22
    var tone: Tone = .light

    private var blaColor: Color { tone == .light ? .white : BlaxxColor.black }
    private var xxColor: Color { tone == .light ? BlaxxColor.lime : BlaxxColor.limeDark }

    var body: some View {
        VStack(spacing: symbolSize * 0.18) {
            Image("BlaxxSymbol")
                .resizable()
                .scaledToFit()
                .frame(height: symbolSize)
                .accessibilityHidden(true)
            (Text("Bla").foregroundColor(blaColor)
             + Text("Xx").foregroundColor(xxColor))
                .font(BlaxxFont.display(fontSize, weight: .black))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BlaXx")
    }
}
