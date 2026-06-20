//
//  ContentView.swift
//  BlaxxPontos
//
//  View raiz. Roteia para tela de login OU para a shell adequada
//  (Mobile no iPhone/iPad compact, Sidebar no macOS/iPad regular).
//

import SwiftUI

struct ContentView: View {
    @Environment(Session.self) private var session
    /// Pré-login: mostra a Home pública (marketing) primeiro; ao tocar em
    /// "Entrar"/"Criar conta" abre a LoginView (onde se credencia de fato).
    @State private var showLogin = false

    var body: some View {
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
                case .admin:         AdminView()
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
