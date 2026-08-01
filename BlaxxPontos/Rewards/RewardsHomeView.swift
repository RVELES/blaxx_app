//
//  RewardsHomeView.swift
//  BlaxxPontos
//
//  Home screen: header, dark hero w/ sparkline, quick actions, featured offers.
//

import SwiftUI

struct RewardsHomeView: View {
    @Environment(RewardsStore.self) private var store
    var onTrade: () -> Void
    var onBuy: () -> Void
    var onSell: () -> Void
    var onTransfer: () -> Void
    var onOffer: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                hero
                quickActions
                HStack(alignment: .firstTextBaseline) {
                    Text("Destaques para você")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                    Spacer()
                    Text("Ver todas")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RWColor.greenLight)
                }
                .padding(.top, 2)
                offerList
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 18)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image("BlaxxSymbol")
                    .renderingMode(.template)            // mask by alpha → recolor to official brand neon
                    .resizable().scaledToFit()
                    .foregroundStyle(RWColor.neon)       // BlaXx Green #59FD27 (brand book) — not the legacy lime asset fill
                    .frame(width: 20, height: 22)
                    .frame(width: 36, height: 36)
                    .background(RWColor.ink2)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    (Text("Bla").foregroundColor(Color(hex: 0x111111))
                     + Text("Xx").foregroundColor(RWColor.greenLight))
                        .font(BlaxxFont.display(18, weight: .bold))
                    Text("REWARDS")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(RWColor.muted)
                }
            }
            Spacer()
            HStack(spacing: 14) {
                Image(systemName: "bell")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: 0x15161A))
                Text("R")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(RWColor.neon)
                    .frame(width: 36, height: 36)
                    .background(RWColor.ink2)
                    .clipShape(Circle())
            }
        }
        .padding(.top, 2)
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Seu patrimônio")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RWColor.heroSub)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("R$ \(RWFormat.n(store.totalBRL))")
                        .font(BlaxxFont.display(34, weight: .bold))
                        .foregroundStyle(.white)
                    Text(",00")
                        .font(BlaxxFont.display(20, weight: .bold))
                        .foregroundStyle(RWColor.heroNum)
                }
                .padding(.top, 4)
                Text("\(RWFormat.n(store.totalPts)) pontos BlaXx")
                    .font(.system(size: 13))
                    .foregroundStyle(RWColor.heroSub)
                    .padding(.top, 2)
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold))
                    Text("+8,42% este mês").font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(RWColor.neon)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(RWColor.neon.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RWSparkline()
                .frame(width: 150, height: 74)
        }
        .padding(.init(top: 20, leading: 20, bottom: 16, trailing: 20))
        .background(RWColor.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            qa("cart", "Comprar", primary: false) { onBuy() }
            qa("arrow.down.circle", "Vender", primary: false) { onSell() }
            qa("arrow.left.arrow.right", "Trocar", primary: true) { onTrade() }
            qa("paperplane", "Enviar", primary: false) { onTransfer() }
        }
    }

    private func qa(_ icon: String, _ label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 23))
                    .foregroundStyle(primary ? RWColor.neon : RWColor.greenLight)
                Text(label)
                    .font(.system(size: 12, weight: primary ? .bold : .semibold))
                    .foregroundStyle(primary ? RWColor.neon : Color(hex: 0x1B1C1A))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(primary ? RWColor.ink2 : .white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: primary ? Color(hex: 0x40C814).opacity(0.25) : RWColor.cardShadow,
                    radius: primary ? 8 : 5, x: 0, y: primary ? 6 : 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Offer list

    private var offerList: some View {
        VStack(spacing: 11) {
            ForEach(store.offerIds, id: \.self) { id in
                let p = store.program(id: id)
                Button { onOffer(id) } label: {
                    HStack(spacing: 13) {
                        RWProgramLogo(program: p, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.system(size: 15, weight: .bold)).foregroundStyle(RWColor.ink)
                            Text("+\(p.bonus)% de bônus").font(.system(size: 14, weight: .bold)).foregroundStyle(RWColor.bonus)
                            Text("Expira em \(store.offerExpiry(id)) dias").font(.system(size: 11, weight: .medium)).foregroundStyle(RWColor.rowExpiry)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color(hex: 0xC2C6BC))
                    }
                    .padding(.init(top: 13, leading: 15, bottom: 13, trailing: 15))
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .rwCardShadow()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Sparkline (matches the hero SVG path)

struct RWSparkline: View {
    // Points from the prototype SVG (viewBox 0 0 200 90).
    private let pts: [CGPoint] = [
        .init(x: 0, y: 68), .init(x: 25, y: 60), .init(x: 50, y: 66), .init(x: 75, y: 44),
        .init(x: 100, y: 52), .init(x: 125, y: 30), .init(x: 150, y: 40), .init(x: 175, y: 16),
        .init(x: 200, y: 24)
    ]

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / 200
            let sy = geo.size.height / 90
            let mapped = pts.map { CGPoint(x: $0.x * sx, y: $0.y * sy) }
            ZStack {
                // Filled area
                Path { path in
                    path.move(to: mapped[0])
                    mapped.dropFirst().forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [RWColor.neon.opacity(0.4), RWColor.neon.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                // Line
                Path { path in
                    path.move(to: mapped[0])
                    mapped.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(RWColor.neon, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                // End dot
                Circle().fill(RWColor.neon).frame(width: 8, height: 8)
                    .position(mapped.last!)
            }
        }
    }
}
