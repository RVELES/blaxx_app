//
//  Components.swift
//  BlaxxPontos
//
//  Componentes visuais reutilizáveis baseados no design system.
//

import SwiftUI

// MARK: - Eyebrow

struct Eyebrow: View {
    let text: String
    var color: Color = BlaxxColor.limeDark
    var body: some View {
        Text(text)
            .font(BlaxxFont.eyebrow())
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Card

struct BlaxxCard<Content: View>: View {
    var variant: Variant = .surface
    @ViewBuilder var content: () -> Content

    // `.brutal*` = tema claro Neo-Brutal (borda grossa + sombra dura). Opt-in:
    // as chamadas existentes continuam em `.surface` (macio) e nada muda nelas.
    enum Variant { case surface, dark, lime, brutal, brutalNeon }

    private var background: Color {
        switch variant {
        case .surface:    BlaxxColor.white
        case .dark:       BlaxxColor.black
        case .lime:       BlaxxColor.limeLight
        case .brutal:     BlaxxColor.white
        case .brutalNeon: BlaxxColor.lime
        }
    }
    private var border: Color {
        switch variant {
        case .surface: BlaxxColor.border
        case .dark:    .clear
        case .lime:    BlaxxColor.limeDark.opacity(0.4)
        case .brutal, .brutalNeon: BlaxxColor.ink
        }
    }
    private var isBrutal: Bool { variant == .brutal || variant == .brutalNeon }

    var body: some View {
        if isBrutal {
            content().brutalCard(background: background)
        } else {
            content()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(border, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Balance card (saldo destacado)

struct BalanceCard: View {
    let balancePts: Int
    let balanceBRL: Double

    private var formatted: String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: balancePts)) ?? "\(balancePts)"
    }
    private var formattedBRL: String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale(identifier: "pt_BR")
        return nf.string(from: NSNumber(value: balanceBRL)) ?? "R$ \(balanceBRL)"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Glow verde-limão atrás
            Circle()
                .fill(BlaxxColor.lime.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
                .offset(x: 40, y: -60)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Eyebrow(text: "Valor total estimado", color: BlaxxColor.gray400)
                    Spacer()
                    GrowthPill(text: "+8,42%", onDark: true)
                }
                Text(formattedBRL)
                    .font(BlaxxFont.display(44))
                    .foregroundStyle(BlaxxColor.lime)
                    .padding(.top, 2)
                Text("\(formatted) pontos · validade FIFO")
                    .font(.system(size: 13))
                    .foregroundStyle(BlaxxColor.gray400)
                    .padding(.top, 4)
            }
            .padding(28)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BlaxxColor.black)
        )
        .clipped()
    }
}

// MARK: - Métrica menor

struct MetricCard: View {
    let label: String
    let value: String
    var subtitle: String?
    var body: some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: label, color: BlaxxColor.gray400)
                Text(value)
                    .font(BlaxxFont.display(28))
                    .foregroundStyle(BlaxxColor.black)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(BlaxxColor.gray400)
                }
            }
        }
    }
}

// MARK: - Action tile (ícone + nome)

struct ActionTile: View {
    let icon: String
    let label: String
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Text(icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(BlaxxColor.limeLight)
                    .foregroundStyle(BlaxxColor.limeDark)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Eyebrow(text: label, color: BlaxxColor.gray400)
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BlaxxColor.black)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BlaxxColor.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(BlaxxColor.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Growth pill (+8,42%)

struct GrowthPill: View {
    let text: String
    var onDark: Bool = false
    var negative: Bool = false
    var body: some View {
        let fg: Color = onDark ? BlaxxColor.lime : (negative ? BlaxxColor.negative : BlaxxColor.positive)
        HStack(spacing: 3) {
            Image(systemName: negative ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                .font(.system(size: 8, weight: .bold))
            Text(text).font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(fg.opacity(onDark ? 0.16 : 0.12)))
    }
}

// MARK: - Section header (título + ação)

struct SectionHeader: View {
    let title: String
    var actionLabel: String?
    var action: (() -> Void)?
    var body: some View {
        HStack {
            Text(title)
                .font(BlaxxFont.display(18))
                .foregroundStyle(BlaxxColor.black)
            Spacer()
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.plain)
                    .foregroundStyle(BlaxxColor.limeDark)
                    .font(.system(size: 13))
            }
        }
    }
}

// MARK: - Tile row (campanha / parceiro)

struct TileRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    let meta: String
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(BlaxxColor.limeLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BlaxxColor.gray800)
                    Text(subtitle).font(.system(size: 12))
                        .foregroundStyle(BlaxxColor.gray400)
                }
                Spacer()
                Text(meta).font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BlaxxColor.limeDark)
            }
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(BlaxxColor.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Distribuição (barra)

struct DistRow: View {
    let name: String
    let pct: Int
    var fill: Color = BlaxxColor.lime
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BlaxxColor.gray800)
                Spacer()
                Text("\(pct)%").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BlaxxColor.gray400)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(BlaxxColor.gray100)
                    Capsule().fill(fill)
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Chip / Tag

struct Chip: View {
    let text: String
    var variant: Variant = .neutral

    enum Variant { case neutral, success, warning, danger, dark }

    private var bg: Color {
        switch variant {
        case .neutral: BlaxxColor.gray100
        case .success: BlaxxColor.limeLight
        case .warning: Color(red: 1, green: 0.95, blue: 0.78)
        case .danger:  Color(red: 1, green: 0.89, blue: 0.89)
        case .dark:    BlaxxColor.black
        }
    }
    private var fg: Color {
        switch variant {
        case .neutral: BlaxxColor.gray600
        case .success: BlaxxColor.limeDark
        case .warning: Color(red: 0.57, green: 0.26, blue: 0.05)
        case .danger:  BlaxxColor.negative
        case .dark:    BlaxxColor.lime
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
    }
}

// MARK: - Campo de formulário Blaxx

struct BlaxxField: View {
    let label: String
    @Binding var value: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: label, color: BlaxxColor.gray600)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $value)
                } else {
                    TextField(placeholder, text: $value)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .padding(12)
            .background(BlaxxColor.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BlaxxColor.border, lineWidth: 0.5)
            )
            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(BlaxxColor.gray400)
            }
        }
    }
}

// MARK: - Topbar

struct Topbar: View {
    let eyebrow: String
    let title: String
    let userName: String
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: eyebrow, color: BlaxxColor.gray400)
                Text(title)
                    .font(BlaxxFont.display(28))
                    .foregroundStyle(BlaxxColor.black)
            }
            Spacer()
            // Chip de usuário à direita (paridade com web/EXE): avatar +
            // primeiro nome + nível.
            let firstName = userName
                .split(separator: " ")
                .first
                .map(String.init) ?? userName
            HStack(spacing: 12) {
                Avatar(name: userName)
                VStack(alignment: .leading, spacing: 2) {
                    Text(firstName.isEmpty ? "Você" : firstName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BlaxxColor.gray800)
                    Text("Nível Black")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(BlaxxColor.gray400)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 14)
            .padding(.vertical, 4)
            .overlay(
                Capsule().stroke(BlaxxColor.border, lineWidth: 1)
            )
        }
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 40
    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.35, weight: .semibold))
            .foregroundStyle(BlaxxColor.lime)
            .frame(width: size, height: size)
            .background(Circle().fill(BlaxxColor.black))
    }
}

// MARK: - Tick de sucesso

struct SuccessTick: View {
    var color: Color = BlaxxColor.lime
    var icon: String = "checkmark"
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(BlaxxColor.black)
            .frame(width: 80, height: 80)
            .background(Circle().fill(color))
    }
}

// MARK: - Marca na nav bar (iPhone)

extension View {
    /// Centraliza o wordmark BlaXx na nav bar — igual à aba "Início". Antes só o
    /// Dashboard tinha o logo e as demais abas mostravam só um título de texto,
    /// dando a sensação de que a marca "sumia". No macOS é no-op: lá a marca
    /// vive no hero da sidebar.
    func blaxxBrandNavBar() -> some View {
        modifier(BrandNavBarModifier())
    }
}

#if os(iOS)
private struct BrandNavBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BlaxxWordmark(size: 20, tone: .light)
                        .fixedSize()
                }
            }
    }
}
#else
private struct BrandNavBarModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}
#endif
