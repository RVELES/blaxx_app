//
//  ContentView.swift
//  BlaxxPontos
//
//  View raiz. Roteia para tela de login OU para a shell adequada
//  (Mobile no iPhone/iPad compact, Sidebar no macOS/iPad regular).
//
//  ⚠️ LEGADO — LEIA ANTES DE AUDITAR OU CORRIGIR ALGO AQUI.
//
//  No iOS, `body` devolve `BXRaiz()` (redesenho "Embarque", 22/10/2026). O roteamento antigo é
//  `legacyBody`, usado só fora do iOS — logo, no iPhone estas telas NÃO estão no app:
//
//      BuyView · RedeemView · MobileShell · HomeView · AuthenticatedShell
//
//  A árvore VIVA é `Rewards/Telas/` + `Rewards/Embarque/`: BXRaiz → BXVisitanteCasca / BXCasca →
//  BXRoteador → BXTelas<Grupo>. O mundo `Rewards*.swift` antigo está desativado (#if BX_LEGADO_REWARDS).
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
        // Redesenho "Embarque" (22/10/2026): a raiz do app no iOS é `BXRaiz` (Rewards/Telas/Casca).
        // O mundo antigo de `Rewards/` (RewardsRoot…) foi desativado com `#if BX_LEGADO_REWARDS` (D14).
        // Outras plataformas (macOS/visionOS) continuam com o `legacyBody`.
        #if os(iOS)
        #if DEBUG
        // `-BXGaleria` abre a galeria do design system (só DEBUG).
        if BXDemo.galeria {
            BXGaleria()
        } else {
            BXRaiz()
        }
        #else
        BXRaiz()
        #endif
        #else
        legacyBody
        #endif
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
