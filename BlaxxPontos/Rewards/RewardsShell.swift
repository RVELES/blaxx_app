//
//  RewardsShell.swift
//  BlaxxPontos
//
//  Root of the "BlaXx Rewards" experience. Hosts the screen router, the custom
//  tab bar (with elevated FAB), and the bottom-sheet overlays (trade / offer /
//  program). Self-contained and prefixed so nothing collides with the app.
//

import SwiftUI

enum RWScreen { case home, carteira, parceiros, enviar }

/// Which overlay sheet is presented (nil = none).
enum RWSheet: Identifiable {
    case trade(RWTradeConfig)
    case offer(String)
    case program(String)

    // Real backend flows (live PIX / cashback / P2P) layered over the mock world.
    case buy
    case sell
    case transfer

    var id: String {
        switch self {
        case .trade: return "trade"
        case .offer(let id): return "offer-\(id)"
        case .program(let id): return "program-\(id)"
        case .buy: return "buy"
        case .sell: return "sell"
        case .transfer: return "transfer"
        }
    }
}

struct RewardsShell: View {
    @State private var store = RewardsStore()
    // Real-data session behind the mock world: silent login + live wallet. If it
    // fails (account missing / offline) the mock data keeps showing — additive.
    @State private var backend = RewardsBackend()
    @State private var screen: RWScreen = .home
    @State private var sheet: RWSheet?
    @State private var sendReset = 0
    /// Área logada (Conta, Extrato, Cartão, Perfil, Campanhas…). Vem por cima
    /// da shell, com roteador próprio — ver `RewardsAccountViews.swift`.
    @State private var account: RWAccountRoute?

    var body: some View {
        ZStack {
            RWColor.screenBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Screens
                ZStack {
                    switch screen {
                    case .home:
                        RewardsHomeView(
                            onTrade: { openTrade() },
                            onBuy: { sheet = .buy },
                            onSell: { sheet = .sell },
                            onTransfer: { sheet = .transfer },
                            onBell: { account = .notificacoes },
                            onAvatar: { account = .menu },
                            onCampaigns: { account = .campanhas })
                    case .carteira:
                        RewardsWalletView(onProgram: { sheet = .program($0) })
                    case .parceiros:
                        RewardsPartnersView(onTrade: { openPartnerTrade($0) })
                    case .enviar:
                        RewardsSendView(resetToken: sendReset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)

                RWTabBar(
                    screen: screen,
                    onSelect: { select($0) },
                    onFab: { openTrade() })
            }
            .ignoresSafeArea(edges: .bottom)

            // Área logada em tela cheia (Conta e tudo que sai dela).
            if let route = account {
                RewardsAccountView(
                    initialRoute: route,
                    onClose: { account = nil },
                    onOpenBuy: { account = nil; sheet = .buy },
                    onOpenSell: { account = nil; sheet = .sell },
                    onOpenTransfer: { account = nil; sheet = .transfer },
                    onOpenWallet: { account = nil; screen = .carteira },
                    onOpenPartners: { account = nil; screen = .parceiros })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(15)
            }

            // Bottom-sheet overlays with scrim
            if let sheet {
                RWSheetContainer(onScrimTap: { self.sheet = nil }) {
                    sheetContent(sheet)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }

            // Email verification gate (RELEASE only) — bloqueia uso até
            // o usuário confirmar o e-mail. Em DEBUG o RewardsBackend faz
            // auto-verify via devVerifyEmail, então essa cobertura nunca
            // aparece em build de desenvolvimento.
            #if !DEBUG
            if backend.ready && backend.user != nil && !backend.emailVerified {
                EmailVerifyGate(backend: backend)
                    .transition(.opacity)
                    .zIndex(20)
            }
            #endif
        }
        .environment(store)
        .environment(backend)
        .task { await backend.start() }
        .animation(.easeInOut(duration: 0.25), value: screen)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: sheet?.id)
        .animation(.easeInOut(duration: 0.22), value: account)
    }

    // MARK: Routing

    private func select(_ s: RWScreen) {
        if s == .enviar { goSend() } else { screen = s }
    }
    private func goSend() {
        sendReset += 1
        screen = .enviar
    }
    private func openTrade(_ config: RWTradeConfig = RWTradeConfig()) {
        sheet = .trade(config)
    }
    /// "Trocar" from a partner card: that program seeds the trade as origin.
    private func openPartnerTrade(_ id: String) {
        let fromIdx = store.index(ofId: id)
        var toIdx = 3
        if toIdx == fromIdx { toIdx = (fromIdx + 1) % store.programs.count }
        let config = RWTradeConfig(
            fromIdx: fromIdx,
            toIdx: toIdx,
            amount: min(120000, store.programs[fromIdx].balance),
            bonusRate: store.bonusDefault,
            bonusLabel: "+8% bônus")
        sheet = .trade(config)
    }

    // MARK: Sheet content

    @ViewBuilder
    private func sheetContent(_ sheet: RWSheet) -> some View {
        switch sheet {
        case .trade(let config):
            RewardsTradeSheet(config: config, onClose: { self.sheet = nil })
        case .offer(let id):
            RewardsOfferSheet(
                programId: id,
                onClose: { self.sheet = nil },
                onTrade: { progId, amount in
                    // Open trade: this program as destination, offer bonus applied.
                    let p = store.program(id: progId)
                    let toIdx = store.index(ofId: progId)
                    // Seed from default trade fromIdx (0); auto-swap if equal (JS rule).
                    var fromIdx = 0
                    if fromIdx == toIdx { fromIdx = (toIdx + 1) % store.programs.count }
                    let config = RWTradeConfig(
                        fromIdx: fromIdx,
                        toIdx: toIdx,
                        amount: min(amount, store.programs[fromIdx].balance),
                        bonusRate: Double(p.bonus) / 100,
                        bonusLabel: "+\(p.bonus)% bônus")
                    self.sheet = .trade(config)
                })
        case .program(let id):
            RewardsProgramSheet(
                programId: id,
                onClose: { self.sheet = nil },
                onTrade: { progId in
                    let fromIdx = store.index(ofId: progId)
                    var toIdx = 3
                    if toIdx == fromIdx { toIdx = (fromIdx + 1) % store.programs.count }
                    let config = RWTradeConfig(
                        fromIdx: fromIdx,
                        toIdx: toIdx,
                        amount: min(120000, store.programs[fromIdx].balance),
                        bonusRate: store.bonusDefault,
                        bonusLabel: "+8% bônus")
                    self.sheet = .trade(config)
                })
        case .buy:
            RewardsBuySheet(backend: backend, onClose: { self.sheet = nil })
        case .sell:
            RewardsSellSheet(backend: backend, onClose: { self.sheet = nil })
        case .transfer:
            RewardsTransferSheet(backend: backend, onClose: { self.sheet = nil })
        }
    }
}

// MARK: - Bottom sheet container (scrim + sheet)

struct RWSheetContainer<Content: View>: View {
    var onScrimTap: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 8/255, green: 10/255, blue: 6/255).opacity(0.52)
                .ignoresSafeArea()
                .onTapGesture(perform: onScrimTap)
            content()
                .frame(maxWidth: .infinity)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .frame(maxHeight: 720, alignment: .bottom)
                .shadow(color: .black.opacity(0.32), radius: 30, x: 0, y: -24)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Custom tab bar

struct RWTabBar: View {
    let screen: RWScreen
    var onSelect: (RWScreen) -> Void
    var onFab: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            tab("house", "Home", active: screen == .home) { onSelect(.home) }
            Spacer()
            tab("creditcard", "Carteira", active: screen == .carteira) { onSelect(.carteira) }
            Spacer()
            fab
            Spacer()
            tab("paperplane", "Enviar", active: screen == .enviar) { onSelect(.enviar) }
            Spacer()
            tab("square.grid.2x2", "Parceiros", active: screen == .parceiros) { onSelect(.parceiros) }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 26)
        .background(
            Color.white
                .overlay(Rectangle().fill(Color(hex: 0xEEF0EA)).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tab(_ icon: String, _ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(.system(size: 10, weight: active ? .bold : .semibold))
            }
            .foregroundStyle(active ? RWColor.greenLight : RWColor.muted)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private var fab: some View {
        Button(action: onFab) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(RWColor.ink2)
                .frame(width: 62, height: 62)
                .background(RWColor.fabGradient)
                .clipShape(Circle())
                .shadow(color: Color(hex: 0x40D210).opacity(0.45), radius: 11, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .offset(y: -22)
    }
}

#Preview {
    RewardsShell().preferredColorScheme(.light)
}
