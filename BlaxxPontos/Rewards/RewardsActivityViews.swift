#if BX_LEGADO_REWARDS   // desativado no redesenho Embarque de 22/10/2026. Não apagar sem decisão do dono (D14).
//
//  RewardsActivityViews.swift
//  BlaxxPontos
//
//  Extrato e Notificações — as duas telas de "o que aconteceu na conta".
//
//  O extrato espelha `blaxx/extrato.html`: agrupa por dia com rótulo
//  Hoje/Ontem/"12 ago", filtra entradas e saídas e busca pela descrição.
//  As notificações espelham `blaxx/central-notificacoes.html`.
//
//  Ambas são somente leitura, exceto marcar notificação como lida.
//

import SwiftUI

// MARK: - Extrato

struct RWStatementView: View {
    @Environment(RewardsBackend.self) private var backend
    var onBack: () -> Void

    private enum Filtro: String, CaseIterable {
        case todos = "Tudo", entrada = "Entradas", saida = "Saídas"
    }

    @State private var items: [TransactionDTO] = []
    @State private var loading = true
    @State private var failed = false
    @State private var filtro: Filtro = .todos
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                RWScreenHeader(title: "Extrato", onBack: onBack)
                searchField
                segmented.padding(.top, 12)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 14)

            if loading {
                RWListState(kind: .loading, message: "Carregando extrato…")
                Spacer()
            } else if failed {
                RWListState(kind: .failed, message: "Não foi possível carregar o extrato.")
                Spacer()
            } else if grouped.isEmpty {
                RWListState(kind: .empty,
                            message: items.isEmpty
                            ? "Nenhum movimento ainda. Compre pontos para começar."
                            : "Nada encontrado com esse filtro.")
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(grouped, id: \.0) { dia, txs in
                            Text(dia)
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1.1)
                                .foregroundStyle(RWColor.fieldLabel)
                                .padding(.top, 16).padding(.bottom, 8)
                            VStack(spacing: 9) {
                                ForEach(txs) { t in row(t) }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
        }
        .task { await load() }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RWColor.muted)
            TextField("", text: $query,
                      prompt: Text("Buscar no extrato").foregroundColor(RWColor.muted))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RWColor.ink)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rwBrutalCard()
    }

    private var segmented: some View {
        HStack(spacing: 8) {
            ForEach(Filtro.allCases, id: \.rawValue) { f in
                let on = filtro == f
                Button { filtro = f } label: {
                    Text(f.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(on ? RWColor.ink : RWColor.segFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(on ? RWColor.neon : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(RWColor.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Aplica filtro + busca e agrupa por dia, preservando a ordem do backend
    /// (mais recente primeiro).
    private var grouped: [(String, [TransactionDTO])] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = items.filter { t in
            switch filtro {
            case .todos: break
            case .entrada: if t.amount_pts < 0 { return false }
            case .saida: if t.amount_pts >= 0 { return false }
            }
            if q.isEmpty { return true }
            return t.description.lowercased().contains(q)
        }
        var order: [String] = []
        var map: [String: [TransactionDTO]] = [:]
        for t in filtered {
            let key = RWDate.parse(t.created_at).map { RWDate.dayKey($0) } ?? "Sem data"
            if map[key] == nil { order.append(key); map[key] = [] }
            map[key]?.append(t)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private func row(_ t: TransactionDTO) -> some View {
        let entrada = t.amount_pts >= 0
        let hora = RWDate.parse(t.created_at).map { RWDate.hhmm($0) } ?? ""
        return HStack(spacing: 12) {
            Image(systemName: entrada ? "arrow.up" : "arrow.down")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(entrada ? RWColor.greenLight : RWColor.ink)
                .frame(width: 36, height: 36)
                .background(entrada ? RWColor.chipSelBg : RWColor.pctBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(t.description.isEmpty ? "Movimento" : t.description)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RWColor.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(hora)
                    if t.status.lowercased() != "confirmed" && !t.status.isEmpty {
                        Text("· \(statusLabel(t.status))")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RWColor.rowExpiry)
            }
            Spacer(minLength: 8)
            Text("\(entrada ? "+" : "")\(RWFormat.n(t.amount_pts))")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(entrada ? RWColor.bonus : RWColor.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rwBrutalCard()
    }

    private func statusLabel(_ s: String) -> String {
        switch s.lowercased() {
        case "pending": return "pendente"
        case "reversed": return "estornado"
        case "failed": return "falhou"
        default: return s
        }
    }

    private func load() async {
        loading = true; failed = false
        defer { loading = false }
        do {
            items = try await backend.transactions(limit: 100)
        } catch {
            failed = true
        }
    }
}

// MARK: - Notificações

struct RWNotificationsView: View {
    @Environment(RewardsBackend.self) private var backend
    var onBack: () -> Void

    @State private var items: [NotificationDTO] = []
    @State private var loading = true
    @State private var failed = false
    @State private var busy = false

    private var unread: Int { items.filter { !$0.is_read }.count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                RWScreenHeader(title: "Notificações", onBack: onBack)
                if unread > 0 {
                    Button {
                        Task { await markAll() }
                    } label: {
                        Text(busy ? "Marcando…" : "Marcar todas como lidas")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(RWColor.greenLight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            if loading {
                RWListState(kind: .loading, message: "Carregando…")
                Spacer()
            } else if failed {
                RWListState(kind: .failed, message: "Não foi possível carregar as notificações.")
                Spacer()
            } else if items.isEmpty {
                RWListState(kind: .empty, message: "Nenhuma notificação por aqui.")
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        ForEach(items) { n in row(n) }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
        }
        .task { await load() }
    }

    private func row(_ n: NotificationDTO) -> some View {
        Button {
            Task { await markRead(n) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(n.is_read ? RWColor.chipBorder : RWColor.neon)
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(n.title)
                        .font(.system(size: 14, weight: n.is_read ? .semibold : .bold))
                        .foregroundStyle(RWColor.ink)
                        .multilineTextAlignment(.leading)
                    if let b = n.body, !b.isEmpty {
                        Text(b)
                            .font(.system(size: 13))
                            .foregroundStyle(RWColor.breakdownK)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let d = RWDate.parse(n.created_at) {
                        Text(RWDate.short(d))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RWColor.rowExpiry)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .rwBrutalCard()
        }
        .buttonStyle(.plain)
        .disabled(n.is_read)
    }

    private func load() async {
        loading = true; failed = false
        defer { loading = false }
        do {
            items = try await backend.notifications()
        } catch {
            failed = true
        }
    }

    private func markRead(_ n: NotificationDTO) async {
        guard !n.is_read else { return }
        // Otimista: a lista reflete na hora; se o PATCH falhar, o reload
        // seguinte devolve o estado do servidor.
        try? await backend.markNotificationRead(n.id)
        await load()
    }

    private func markAll() async {
        busy = true
        defer { busy = false }
        try? await backend.markAllNotificationsRead()
        await load()
    }
}

#endif
