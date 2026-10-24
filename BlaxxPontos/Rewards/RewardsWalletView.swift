#if BX_LEGADO_REWARDS   // desativado no redesenho Embarque de 22/10/2026. Não apagar sem decisão do dono (D14).
//
//  RewardsWalletView.swift
//  BlaxxPontos
//
//  Carteira screen: dark summary, period segmented control + evolution chart,
//  programs list. Tapping a program opens the program-detail sheet.
//

import SwiftUI

struct RewardsWalletView: View {
    @Environment(RewardsStore.self) private var store
    @Environment(RewardsBackend.self) private var backend
    var onProgram: (String) -> Void

    @State private var period = "mes"
    @State private var cardCopied = false

    // Chart data from prototype CHARTS.
    private let charts: [String: [Double]] = [
        "mes": [60, 52, 58, 40, 46, 28, 36, 14, 22],
        "6m":  [78, 70, 64, 58, 40, 46, 30, 24, 18],
        "ano": [90, 72, 80, 55, 60, 38, 44, 26, 20]
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Carteira")
                        .font(BlaxxFont.display(24, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: 0x15161A))
                        .frame(width: 38, height: 38)
                        .background(.white)
                        .clipShape(Circle())
                        .rwCardShadow()
                }

                // BlaXx Card
                rwBlaxxCard

                // Summary
                VStack(alignment: .leading, spacing: 0) {
                    Text("Patrimônio total").font(.system(size: 13)).foregroundStyle(RWColor.heroSub)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("R$ \(RWFormat.n(store.totalBRL))")
                            .font(BlaxxFont.display(36, weight: .bold))
                            .foregroundStyle(.white)
                        Text(",00").font(BlaxxFont.display(20, weight: .bold)).foregroundStyle(RWColor.heroNum)
                    }
                    .padding(.top, 4)
                    Text("\(RWFormat.n(store.totalPts)) pontos BlaXx")
                        .font(.system(size: 13)).foregroundStyle(RWColor.heroSub).padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(RWColor.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Segmented period
                HStack(spacing: 6) {
                    seg("Mês", "mes"); seg("6 meses", "6m"); seg("Ano", "ano")
                }
                .padding(5)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .rwCardShadow()

                // Chart
                RWAreaChart(values: charts[period] ?? [])
                    .frame(height: 110)
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .rwCardShadow()
                    .animation(.easeInOut, value: period)

                Text("Seus programas")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RWColor.ink)

                VStack(spacing: 11) {
                    ForEach(store.programs) { p in
                        Button { onProgram(p.id) } label: {
                            HStack(spacing: 13) {
                                RWProgramLogo(program: p, size: 46)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.system(size: 15, weight: .bold)).foregroundStyle(RWColor.ink)
                                    if let ex = p.expiring {
                                        Text(ex).font(.system(size: 11, weight: .semibold)).foregroundStyle(RWColor.amber)
                                    } else {
                                        Text("Pontos sem previsão de expiração")
                                            .font(.system(size: 11, weight: .medium)).foregroundStyle(RWColor.rowExpiry)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(RWFormat.n(p.balance)).font(BlaxxFont.display(15, weight: .bold)).foregroundStyle(RWColor.ink)
                                    Text("R$ \(RWFormat.n(p.brl))").font(.system(size: 12, weight: .semibold)).foregroundStyle(RWColor.rowBrl)
                                }
                            }
                            .padding(.init(top: 13, leading: 15, bottom: 13, trailing: 15))
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .rwCardShadow()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 18)
        }
    }

    // MARK: BlaXx Card

    private var rwBlaxxCard: some View {
        let name = backend.user?.name ?? "—"
        let cardNum = backend.cardIdFormatted ?? "—— —— —— ——"
        let pts = backend.balancePts.map { RWFormat.n($0) }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image("BlaxxSymbol")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .foregroundStyle(RWColor.neon)
                    .frame(width: 16, height: 18)
                (Text("Bla").foregroundColor(.white)
                 + Text("Xx").foregroundColor(RWColor.neon))
                    .font(BlaxxFont.display(14, weight: .bold))
                Spacer()
                Text("REWARDS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(RWColor.heroSub)
            }

            Text(cardNum)
                .font(BlaxxFont.mono(26))
                .foregroundStyle(.white)
                .tracking(3)
                .padding(.top, 22)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xCFD3CB))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let pts {
                        Text("\(pts) pontos")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RWColor.heroSub)
                    }
                }
                Spacer()
                Button {
                    if let id = backend.cardId {
                        UIPasteboard.general.string = id
                        withAnimation { cardCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { cardCopied = false }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: cardCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(cardCopied ? "Copiado" : "Copiar")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(RWColor.neon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RWColor.neon.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 18)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x0F1210), Color(hex: 0x0A0B0C)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RWColor.neon.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x40D210).opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private func seg(_ label: String, _ value: String) -> some View {
        Button { withAnimation { period = value } } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(period == value ? RWColor.neon : RWColor.segFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(period == value ? RWColor.ink2 : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Area chart (wallet evolution)

struct RWAreaChart: View {
    let values: [Double]   // 0..100 scale, like the prototype

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let n = max(values.count - 1, 1)
            let step = w / CGFloat(n)
            let pts = values.enumerated().map { i, v in
                CGPoint(x: CGFloat(i) * step, y: v * 1.1 / 120 * h)
            }
            ZStack {
                Path { path in
                    path.move(to: pts[0])
                    pts.dropFirst().forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [RWColor.neonB.opacity(0.28), RWColor.neonB.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                Path { path in
                    path.move(to: pts[0])
                    pts.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(RWColor.neonB, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

#endif
