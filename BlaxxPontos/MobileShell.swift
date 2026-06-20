//
//  MobileShell.swift
//  BlaxxPontos
//
//  Shell para iPhone (TabView na base). No macOS, usa-se AuthenticatedShell.
//

#if os(iOS)
import SwiftUI

struct MobileShell: View {
    @Environment(Session.self) private var session
    @State private var selection: Tab = .dashboard

    init() {
        // Configura o tab bar no estilo Blaxx (preto + acento lime)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(BlaxxColor.black)

        let normalColor = UIColor(BlaxxColor.gray400)
        let selectedColor = UIColor(BlaxxColor.lime)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = normalColor
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        itemAppearance.selected.iconColor = selectedColor
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Nav bar: também preta com texto branco/lime
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(BlaxxColor.black)
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(BlaxxColor.lime)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { DashboardView(selection: $selection) }
                .tabItem { Label("Início", systemImage: "house.fill") }
                .tag(Tab.dashboard)

            NavigationStack { BuyView() }
                .tabItem { Label("Comprar", systemImage: "plus.circle.fill") }
                .tag(Tab.buy)

            NavigationStack { SendView() }
                .tabItem { Label("Enviar", systemImage: "arrow.up.right.circle.fill") }
                .tag(Tab.send)

            NavigationStack { RedeemView() }
                .tabItem { Label("Resgatar", systemImage: "arrow.down.left.circle.fill") }
                .tag(Tab.redeem)

            NavigationStack { MobileMoreView(selection: $selection) }
                .tabItem { Label("Mais", systemImage: "ellipsis.circle.fill") }
                .tag(Tab.profile)
        }
        .tint(BlaxxColor.lime)
    }
}

/// Tab "Mais" — agrupa Carteira, Extrato, Parceiros e Perfil.
struct MobileMoreView: View {
    @Environment(Session.self) private var session
    @Binding var selection: Tab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Bloco do usuário
                HStack(spacing: 12) {
                    Avatar(name: session.user?.name ?? "?")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.user?.name ?? "")
                            .font(.system(size: 17, weight: .semibold))
                        Text(session.user?.email ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(BlaxxColor.gray600)
                    }
                    Spacer()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(BlaxxColor.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(BlaxxColor.gray200, lineWidth: 0.5)
                )

                Section {
                    NavigationLink {
                        WalletView(selection: $selection)
                    } label: { row(icon: "wallet.pass.fill", title: "Carteira", subtitle: "Saldo e movimentações") }

                    NavigationLink {
                        CardView()
                    } label: { row(icon: "person.text.rectangle.fill", title: "Cartão Blaxx", subtitle: "Seu nível e Apple Wallet") }

                    NavigationLink {
                        StatementView()
                    } label: { row(icon: "list.bullet.rectangle.fill", title: "Extrato", subtitle: "Histórico completo") }

                    NavigationLink {
                        PartnersView()
                    } label: { row(icon: "storefront.fill", title: "Parceiros", subtitle: "Rede Blaxx") }

                    NavigationLink {
                        BenefitsView()
                    } label: { row(icon: "gift.fill", title: "Benefícios", subtitle: "Marketplace de vouchers") }

                    NavigationLink {
                        NotificationsView()
                    } label: { row(icon: "bell.fill", title: "Notificações", subtitle: "Histórico de avisos") }
                }

                // Admin: aparece só se o usuário é admin
                if session.user?.isAdmin ?? false {
                    Section {
                        NavigationLink {
                            AdminView()
                        } label: { row(icon: "shield.lefthalf.filled",
                                       title: "Administrador",
                                       subtitle: "Painel restrito · usuários e movimentações") }
                    }
                }

                Section {
                    NavigationLink {
                        ProfileView()
                    } label: { row(icon: "person.circle.fill", title: "Perfil", subtitle: "Dados pessoais e LGPD") }

                    Button(role: .destructive) {
                        session.logout()
                    } label: {
                        row(icon: "rectangle.portrait.and.arrow.right",
                            title: "Sair",
                            subtitle: "Encerrar sessão",
                            tint: BlaxxColor.negative)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(BlaxxColor.gray50.ignoresSafeArea())
        .navigationTitle("Mais")
    }

    private func row(icon: String, title: String, subtitle: String,
                     tint: Color = BlaxxColor.limeDark) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(BlaxxColor.limeLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BlaxxColor.black)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(BlaxxColor.gray600)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BlaxxColor.gray400)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(BlaxxColor.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlaxxColor.gray200, lineWidth: 0.5)
        )
    }
}

#endif
