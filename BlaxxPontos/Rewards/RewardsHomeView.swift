#if BX_LEGADO_REWARDS   // desativado no redesenho Embarque de 22/10/2026. Não apagar sem decisão do dono (D14).
//
//  RewardsHomeView.swift
//  BlaxxPontos
//
//  Home screen: header, dark hero w/ sparkline, quick actions, featured offers.
//

import SwiftUI

struct RewardsHomeView: View {
    @Environment(RewardsBackend.self) private var backend
    var onTrade: () -> Void
    var onBuy: () -> Void
    var onSell: () -> Void
    var onTransfer: () -> Void
    var onBell: () -> Void
    var onAvatar: () -> Void
    var onCampaigns: () -> Void

    /// Campanhas reais do backend. Substituem a régua de "+120% de bônus" em
    /// programas de milhas, que era mock hardcoded ao lado de botões que
    /// operam contra o backend de verdade — o mesmo defeito que o PWA corrigiu
    /// na área logada em 02/08 (`Q05`).
    @State private var campaigns: [CampaignDTO] = []
    @State private var loadingCampaigns = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                hero
                quickActions
                HStack(alignment: .firstTextBaseline) {
                    Text("Campanhas")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                    Spacer()
                    Button(action: onCampaigns) {
                        Text("Ver todas")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RWColor.greenLight)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
                campaignList
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 18)
        }
        .task {
            campaigns = (try? await backend.campaigns()) ?? []
            loadingCampaigns = false
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    // Marca oficial. Superfície CLARA aqui, então a variante
                    // com "Bla" em tinta e "Xx" em lime-dark — a arte do pacote
                    // tem "Bla" branco e sumiria. A arte já inclui "REWARDS".
                    Image("BlaxxWordmarkClaro")
                        .resizable().scaledToFit()
                        .frame(height: 26)
                        .accessibilityLabel("BlaXx Rewards")
                }
            }
            Spacer()
            HStack(spacing: 14) {
                Button(action: onBell) {
                    Image(systemName: "bell")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: 0x15161A))
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notificações")

                Button(action: onAvatar) {
                    Text(String((backend.user?.name.prefix(1) ?? "R")).uppercased())
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(RWColor.neon)
                        .frame(width: 36, height: 36)
                        .background(RWColor.ink2)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Minha conta")
            }
        }
        .padding(.top, 2)
    }

    // MARK: Hero

    /// Saldo REAL da carteira. Antes o hero mostrava `store.totalBRL` /
    /// `store.totalPts` (mock) e um "+8,42% este mês" fixo no código, colados
    /// logo acima de botões que movem dinheiro de verdade. Sem sessão o hero
    /// mostra "—" em vez de número inventado.
    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Seu saldo")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RWColor.heroSub)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(brlText)
                        .font(BlaxxFont.display(34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
                Text(ptsText)
                    .font(.system(size: 13))
                    .foregroundStyle(RWColor.heroSub)
                    .padding(.top, 2)
                if let age = cacheNote {
                    Text(age)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RWColor.countdownFg)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(RWColor.countdownBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RWSparkline()
                .frame(width: 150, height: 74)
                .opacity(backend.wallet == nil ? 0.25 : 1)
        }
        .padding(.init(top: 20, leading: 20, bottom: 16, trailing: 20))
        .background(RWColor.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var brlText: String {
        guard let w = backend.wallet else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: w.balance_brl_equiv)) ?? "R$ 0,00"
    }

    private var ptsText: String {
        guard let w = backend.wallet else { return "Entre na sua conta para ver o saldo" }
        if w.pending_pts > 0 {
            return "\(RWFormat.n(w.balance_pts)) pontos · \(RWFormat.n(w.pending_pts)) a confirmar"
        }
        return "\(RWFormat.n(w.balance_pts)) pontos BlaXx"
    }

    /// O `RewardsBackend` mantém o último wallet conhecido em cache por 1h para
    /// a tela não abrir vazia. Quando o número exibido vem do cache, dizer isso
    /// é mais honesto que exibi-lo como se fosse fresco.
    private var cacheNote: String? {
        backend.wallet != nil && !backend.ready ? "Saldo do último acesso" : nil
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: primary ? Color(hex: 0x40C814).opacity(0.25) : RWColor.cardShadow,
                    radius: primary ? 8 : 5, x: 0, y: primary ? 6 : 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Campanhas

    @ViewBuilder
    private var campaignList: some View {
        if loadingCampaigns {
            RWListState(kind: .loading, message: "Carregando campanhas…")
        } else if campaigns.isEmpty {
            RWListState(kind: .empty,
                        message: "Nenhuma campanha ativa agora. Quando houver, ela aparece aqui.")
        } else {
            VStack(spacing: 11) {
                ForEach(campaigns.prefix(3)) { c in
                    Button(action: onCampaigns) {
                        HStack(spacing: 13) {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(RWColor.ink)
                                .frame(width: 46, height: 46)
                                .background(RWColor.neon)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(RWColor.ink)
                                    .multilineTextAlignment(.leading)
                                Text("+\(RWFormat.n(c.reward_pts)) pontos")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(RWColor.bonus)
                                Text(c.isJoined
                                     ? (c.isCompleted ? "Concluída" : "Participando · \(c.progressPct)%")
                                     : "Toque para participar")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(RWColor.rowExpiry)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: 0xC2C6BC))
                        }
                        .padding(.init(top: 13, leading: 15, bottom: 13, trailing: 15))
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .rwBrutalCard()
                    }
                    .buttonStyle(.plain)
                }
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

#endif
