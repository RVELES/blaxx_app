//
//  ContentView.swift
//  BlaxxPontos
//
//  View raiz. Roteia para tela de login OU para a shell adequada
//  (Mobile no iPhone/iPad compact, Sidebar no macOS/iPad regular).
//
//  ⚠️ LEGADO — LEIA ANTES DE AUDITAR OU CORRIGIR ALGO AQUI.
//
//  `body` devolve `RewardsRoot()`. Todo o roteamento antigo virou `legacyBody`,
//  que **ninguém referencia** — logo, estas telas NÃO estão no app:
//
//      BuyView · RedeemView · MobileShell · HomeView · AuthenticatedShell
//
//  A árvore VIVA é `Rewards/`: RewardsRoot → RewardsShell → RewardsBuySheet /
//  RewardsSellSheet / RewardsTransferSheet.
//
//  Isto já custou duas auditorias (20/07 e 01/08) avaliando `BuyView.swift` e
//  `RedeemView.swift`: os "✅" delas não valiam para o app real, e o achado N1
//  (botão "Simular pagamento" sem gate) sobreviveu escondido atrás desses ✅.
//  Ao corrigir um comportamento, corrija no sheet vivo — não aqui.
//

import SwiftUI

struct ContentView: View {
    @Environment(Session.self) private var session
    /// Pré-login: mostra a Home pública (marketing) primeiro; ao tocar em
    /// "Entrar"/"Criar conta" abre a LoginView (onde se credencia de fato).
    @State private var showLogin = false

    var body: some View {
        // Entry swapped to the new native "BlaXx Rewards" experience. RewardsRoot
        // is the mock login gate → RewardsShell. Reversible: use `RewardsShell()`
        // to skip the gate, or restore `legacyBody` to bring back the old app.
        RewardsRoot()
            .preferredColorScheme(.light)
    }

    /// Original root routing — preserved for a one-line revert.
    private var legacyBody: some View {
        Group {
            if session.isAuthenticated {
                #if os(iOS)
                MobileShell()
                #else
                AuthenticatedShell()
                #endif
            } else if showLogin {
                LoginView(onBack: { showLogin = false })
            } else {
                HomeView(onEnter: { showLogin = true })
            }
        }
        .preferredColorScheme(.light)
    }
}

#if os(macOS)
struct AuthenticatedShell: View {
    @Environment(Session.self) private var session
    @State private var selection: Tab = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            BlaxxSidebar(selection: $selection,
                         userName: session.user?.name ?? "?",
                         isAdmin: session.user?.isAdmin ?? false,
                         onLogout: { session.logout() })

            ZStack {
                BlaxxColor.gray50.ignoresSafeArea()
                switch selection {
                case .dashboard:     DashboardView(selection: $selection)
                case .wallet:        WalletView(selection: $selection)
                case .card:          CardView()
                case .statement:     StatementView()
                case .buy:           BuyView()
                case .send:          SendView()
                case .redeem:        RedeemView()
                case .partners:      PartnersView()
                case .benefits:      BenefitsView()
                case .notifications: NotificationsView()
                case .profile:       ProfileView()
                case .admin:
                    #if DEBUG
                    AdminView()
                    #else
                    // Release: rota admin não exposta no app.
                    Text("Indisponível")
                    #endif
                }
            }
        }
        .frame(minWidth: 1080, minHeight: 700)
    }
}
#endif

#Preview("Login") {
    ContentView().environment(Session())
}
