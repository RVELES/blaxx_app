//
//  Sidebar.swift
//  BlaxxPontos
//

import SwiftUI

enum Tab: Hashable, Sendable {
    case dashboard, wallet, card, statement, buy, send, redeem,
         partners, benefits, notifications, profile, admin
    // Icones SF Symbols com versao "fill" — mais alegres/coloridos por padrao
    // e melhor renderizacao em sidebar dark. Sao o equivalente nativo aos
    // emojis usados no web/Electron.
    var icon: String {
        switch self {
        case .dashboard:     "house.fill"
        case .wallet:        "creditcard.fill"
        case .card:          "person.text.rectangle.fill"
        case .statement:     "chart.bar.fill"
        case .buy:           "dollarsign.circle.fill"
        case .send:          "paperplane.fill"
        case .redeem:        "briefcase.fill"
        case .partners:      "building.2.fill"
        case .benefits:      "gift.fill"
        case .notifications: "bell.fill"
        case .profile:       "person.crop.circle.fill"
        case .admin:         "shield.lefthalf.filled"
        }
    }
    var label: String {
        switch self {
        case .dashboard:     "Início"
        case .wallet:        "Carteira"
        case .card:          "Cartão Blaxx"
        case .statement:     "Extrato"
        case .buy:           "Comprar pontos"
        case .send:          "Enviar pontos"
        case .redeem:        "Resgatar"
        case .partners:      "Parceiros"
        case .benefits:      "Benefícios"
        case .notifications: "Notificações"
        case .profile:       "Perfil"
        case .admin:         "Administrador"
        }
    }
}

#if os(macOS)
struct BlaxxSidebar: View {
    @Binding var selection: Tab
    let userName: String
    var isAdmin: Bool = false   // mostra a aba "Administrador" só se true
    var onLogout: () -> Void

    private let programTabs: [Tab] = [.dashboard, .wallet, .card, .statement, .buy, .send, .redeem, .partners, .benefits, .notifications]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Logo oficial Blaxx (XX duplo) — variante dark-ink sobre a
            // sidebar clara (paridade com web/Windows/SVG da marca).
            BlaxxWordmark(size: 30, tone: .dark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 32)

            sectionLabel("Programa")
            ForEach(programTabs, id: \.self) { tab in
                NavItem(tab: tab, isActive: selection == tab) {
                    selection = tab
                }
            }

            if isAdmin {
                sectionLabel("Admin").padding(.top, 16)
                NavItem(tab: .admin, isActive: selection == .admin) {
                    selection = .admin
                }
            }

            sectionLabel("Conta").padding(.top, 16)
            NavItem(tab: .profile, isActive: selection == .profile) {
                selection = .profile
            }
            Button(action: onLogout) {
                HStack(spacing: 14) {
                    // Icone 1.5x maior + door SF Symbol (paridade com 🚪
                    // do web/Electron) — Sair fica visualmente claro
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BlaxxColor.limeDark)
                        .frame(width: 20, height: 20)
                    Text("Sair")
                        .font(.system(size: 15))
                }
                .foregroundStyle(BlaxxColor.sidebarItem)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Avatar(name: userName)
                    .scaleEffect(0.65)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName).font(.system(size: 11)).foregroundStyle(BlaxxColor.gray800)
                    Text("BlaXx · v0.1").font(.system(size: 10)).foregroundStyle(BlaxxColor.gray400)
                }
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(width: 248)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(BlaxxColor.sidebarBg)
        .overlay(alignment: .trailing) {
            Rectangle().fill(BlaxxColor.sidebarBorder).frame(width: 1)
        }
    }

    @ViewBuilder
    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(BlaxxColor.gray400)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

private struct NavItem: View {
    let tab: Tab
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icone 1.5x maior (era ~16, agora ~24) + colorido pra
                // destaque visual conforme pedido "icones mais alegres".
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isActive ? BlaxxColor.black : BlaxxColor.limeDark)
                    .frame(width: 20, height: 20)
                Text(tab.label)
                    .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                Spacer()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .foregroundStyle(isActive ? BlaxxColor.black : BlaxxColor.sidebarItem)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? BlaxxColor.lime : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
