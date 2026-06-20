//
//  NotificationsView.swift
//  BlaxxPontos
//

import SwiftUI

struct NotificationsView: View {
    @Environment(Session.self) private var session
    @State private var items: [NotificationDTO] = []
    @State private var unread = 0
    @State private var loading = false

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 24) {
                    if !isCompact {
                        Topbar(eyebrow: "Central", title: "Notificações",
                               userName: session.user?.name ?? "?")
                    }

                    HStack {
                        Eyebrow(text: "\(unread) não lidas")
                        Spacer()
                        if unread > 0 {
                            Button("Marcar tudo como lido") {
                                Task { await readAll() }
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                    }

                    if loading && items.isEmpty {
                        ProgressView().padding()
                    } else if items.isEmpty {
                        BlaxxCard {
                            Text("Sem notificações por enquanto.")
                                .foregroundStyle(BlaxxColor.gray400)
                                .frame(maxWidth: .infinity, minHeight: 80)
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(items) { n in
                                row(n)
                            }
                        }
                    }
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Notificações" : "")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func row(_ n: NotificationDTO) -> some View {
        Button {
            Task { await markRead(n) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(n.icon ?? "•")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BlaxxColor.lime)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(BlaxxColor.black))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(n.title)
                            .font(.system(size: 14, weight: n.is_read ? .regular : .semibold))
                            .foregroundStyle(BlaxxColor.black)
                        if !n.is_read {
                            Circle().fill(BlaxxColor.limeDark).frame(width: 6, height: 6)
                        }
                    }
                    if let body = n.body, !body.isEmpty {
                        Text(body)
                            .font(.system(size: 12))
                            .foregroundStyle(BlaxxColor.gray600)
                            .multilineTextAlignment(.leading)
                    }
                    Text(prettyDate(n.created_at))
                        .font(.system(size: 11))
                        .foregroundStyle(BlaxxColor.gray400)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(n.is_read ? BlaxxColor.white : BlaxxColor.limeLight.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BlaxxColor.gray200, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func prettyDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "pt_BR")
            fmt.dateFormat = "dd/MM 'às' HH:mm"
            return fmt.string(from: d)
        }
        return iso.prefix(16).replacingOccurrences(of: "T", with: " ")
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let r = try await BlaxxAPI.shared.notifications()
            items = r.items
            unread = r.unread_count
        } catch { /* silencioso */ }
    }

    private func markRead(_ n: NotificationDTO) async {
        guard !n.is_read else { return }
        try? await BlaxxAPI.shared.markNotificationRead(n.id)
        await load()
    }

    private func readAll() async {
        try? await BlaxxAPI.shared.markAllNotificationsRead()
        await load()
    }
}

#Preview { NotificationsView().environment(Session()) }
