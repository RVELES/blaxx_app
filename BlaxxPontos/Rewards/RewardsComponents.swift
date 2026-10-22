//
//  RewardsComponents.swift
//  BlaxxPontos
//
//  Reusable building blocks for the BlaXx Rewards experience.
//

import SwiftUI

// MARK: - Program logo badge

/// Colored rounded badge with the program "logo" text (matches .logo / .plogo CSS).
struct RWProgramLogo: View {
    let program: RWProgram
    var size: CGFloat = 46
    var corner: CGFloat? = nil   // nil => circle

    private var fontSize: CGFloat { program.logo.count > 2 ? size * 0.28 : size * 0.42 }

    var body: some View {
        Text(program.logo)
            .font(BlaxxFont.display(fontSize, weight: .black))
            .foregroundStyle(program.fg)
            .frame(width: size, height: size)
            .background(program.bg)
            .clipShape(RoundedRectangle(cornerRadius: corner ?? size / 2, style: .continuous))
    }
}

// MARK: - Program chip (De / Para / origem do envio)

struct RWProgramChip: View {
    let program: RWProgram
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(program.logo)
                    .font(.system(size: program.logo.count > 2 ? 8 : 13, weight: .heavy))
                    .foregroundStyle(program.fg)
                    .frame(width: 30, height: 30)
                    .background(program.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(program.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                        .fixedSize()
                    Text(RWFormat.n(program.balance))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(RWColor.chipPts)
                }
            }
            .padding(.leading, 7)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(selected ? RWColor.chipSelBg : .white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? RWColor.neon : RWColor.ink, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

// MARK: - Field label (uppercase tracked)

struct RWFieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(RWColor.fieldLabel)
    }
}

// MARK: - Primary CTA / ghost CTA

struct RWCTA: View {
    let title: String
    var ghost: Bool = false
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ghost ? RWColor.ink : RWColor.neon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(ghost ? Color.white : RWColor.ink2)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RWColor.ink, lineWidth: 3)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .shadow(color: disabled ? .clear : RWColor.cardShadow, radius: 0, x: 5, y: 5)
    }
}

// MARK: - Percentage shortcut buttons (25 / 50 / Máx)

struct RWPctRow: View {
    var onPick: (Double) -> Void
    var body: some View {
        HStack(spacing: 8) {
            pct("25%", 0.25)
            pct("50%", 0.5)
            pct("Máx", 1)
        }
    }
    private func pct(_ label: String, _ value: Double) -> some View {
        Button { onPick(value) } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(RWColor.pctFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RWColor.pctBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Grabber + sheet header

struct RWGrabber: View {
    var body: some View {
        Capsule().fill(Color(hex: 0xE2E4DE))
            .frame(width: 42, height: 4)
            .padding(.bottom, 16)
    }
}

struct RWSheetHeader: View {
    let title: String
    var onClose: () -> Void
    var body: some View {
        HStack {
            Text(title)
                .font(BlaxxFont.display(21, weight: .bold))
                .foregroundStyle(RWColor.ink)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(RWColor.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar")
        }
        .padding(.bottom, 18)
    }
}

struct RWBackHeader: View {
    let title: String
    var onBack: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(RWColor.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")
            Text(title)
                .font(BlaxxFont.display(21, weight: .bold))
                .foregroundStyle(RWColor.ink)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Success badge (pop-in)

struct RWSuccessBadge: View {
    @State private var pop = false
    var body: some View {
        ZStack {
            Circle().fill(RWColor.fabGradient)
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(RWColor.ink2)
        }
        .frame(width: 88, height: 88)
        .shadow(color: Color(hex: 0x40D210).opacity(0.4), radius: 15, x: 0, y: 12)
        .scaleEffect(pop ? 1 : 0.5)
        .opacity(pop ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Operação concluída com sucesso")
    }
}

// MARK: - Range slider styled to match the prototype

struct RWSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1000

    var body: some View {
        Slider(value: $value, in: range, step: step)
            .tint(RWColor.neonB)
            .padding(.vertical, 12)
    }
}

// MARK: - Dark hero "Você recebe" card

struct RWReceiveCard: View {
    let total: String
    let toName: String
    let rateText: String
    let bonusLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Você recebe")
                .font(.system(size: 12))
                .foregroundStyle(RWColor.heroSub)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(total)
                    .font(BlaxxFont.display(30, weight: .bold))
                    .foregroundStyle(RWColor.neon)
                Text(toName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xCFD3CB))
            }
            .padding(.top, 2)
            HStack {
                Text(rateText)
                    .font(.system(size: 12))
                    .foregroundStyle(RWColor.heroSub)
                Spacer()
                Text(bonusLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RWColor.neon)
            }
            .padding(.top, 12)
        }
        .padding(18)
        .background(RWColor.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(RWColor.ink, lineWidth: 3))
        .rwCardShadow()
    }
}

// MARK: - Breakdown list

struct RWBreakdownRow: View {
    let key: String
    let value: String
    var green: Bool = false
    var last: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(key)
                    .font(.system(size: 14))
                    .foregroundStyle(RWColor.breakdownK)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: green ? .bold : .semibold))
                    .foregroundStyle(green ? RWColor.bonus : RWColor.ink)
            }
            .padding(.vertical, 13)
            if !last { Rectangle().fill(RWColor.txDivider).frame(height: 1) }
        }
    }
}
