//
//  AdminView.swift
//  BlaxxPontos
//
//  Módulo Administrador. Acessível apenas para users com role="admin".
//  Mostra: KPIs do sistema, lista de usuários com toggle VIP, e tabela de
//  movimentações. Identidade visual = preta + lime (mantém o app atual).
//

import SwiftUI

struct AdminView: View {
    @Environment(Session.self) private var session

    @State private var tab: AdminTab = .users
    @State private var stats: AdminStatsDTO?
    @State private var loading = false
    @State private var error: String?

    enum AdminTab: String, CaseIterable {
        case users = "Usuários"
        case transactions = "Movimentações"
        case payments = "Pagamentos"
    }

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 24) {
                    if !isCompact {
                        Topbar(eyebrow: "Painel restrito", title: "Administrador",
                               userName: session.user?.name ?? "?")
                    }

                    // Guard visível — se não for admin, mostra mensagem
                    if !(session.user?.isAdmin ?? false) {
                        BlaxxCard {
                            VStack(spacing: 8) {
                                Image(systemName: "shield.slash")
                                    .font(.system(size: 36))
                                    .foregroundStyle(BlaxxColor.negative)
                                Text("Acesso restrito")
                                    .font(BlaxxFont.display(22))
                                Text("Esta área é apenas para administradores.")
                                    .foregroundStyle(BlaxxColor.gray600)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    } else {
                        statsSection
                        Picker("", selection: $tab) {
                            ForEach(AdminTab.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        switch tab {
                        case .users:        AdminUsersTable()
                        case .transactions: AdminTransactionsTable()
                        case .payments:     AdminPaymentsTable()
                        }
                    }
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Admin" : "")
            .task { await loadStats() }
            .refreshable { await loadStats() }
        }
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsSection: some View {
        if let s = stats {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                MetricCard(label: "Usuários", value: fmt(s.total_users), subtitle: "cadastrados")
                MetricCard(label: "Admins", value: fmt(s.total_admins), subtitle: "com acesso")
                MetricCard(label: "VIPs", value: fmt(s.total_vips), subtitle: "sem limite diário")
                MetricCard(label: "E-mail verificado",
                           value: fmt(s.email_verified_users), subtitle: "usuários ativos")
                MetricCard(label: "Saldo total",
                           value: "\(fmt(s.total_balance_pts)) pts",
                           subtitle: "em circulação")
                MetricCard(label: "Volume 30d",
                           value: "\(fmt(s.volume_last_30d_by_type.values.reduce(0, +))) pts",
                           subtitle: "movimentado")
            }
        } else if loading {
            ProgressView().padding()
        } else if let e = error {
            Text(e).foregroundStyle(BlaxxColor.negative).font(.system(size: 13))
        }
    }

    private func loadStats() async {
        loading = true; defer { loading = false }
        do {
            stats = try await BlaxxAPI.shared.adminStats()
            error = nil
        } catch is CancellationError { /* ignora */ }
        catch let apiErr as APIError {
            error = apiErr.message
        } catch let e {
            error = e.localizedDescription
        }
    }

    private func fmt(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Tabela de usuários

private struct AdminUsersTable: View {
    @State private var users: [AdminUserDTO] = []
    @State private var query = ""
    @State private var roleFilter = ""    // "", "user", "admin"
    @State private var vipFilter = ""      // "", "true", "false"
    @State private var total = 0
    @State private var offset = 0
    @State private var loading = false
    @State private var error: String?

    private let pageSize = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Filtros
            HStack(spacing: 8) {
                BlaxxField(label: "", value: $query, placeholder: "Buscar nome / email / CPF…")
                    .frame(maxWidth: 320)
                Picker("Papel", selection: $roleFilter) {
                    Text("Todos").tag("")
                    Text("Usuários").tag("user")
                    Text("Admins").tag("admin")
                }
                .pickerStyle(.menu)
                Picker("VIP", selection: $vipFilter) {
                    Text("Todos").tag("")
                    Text("VIPs").tag("true")
                    Text("Não VIPs").tag("false")
                }
                .pickerStyle(.menu)
            }

            BlaxxCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(spacing: 12) {
                        cell("NOME", width: 200)
                        cell("E-MAIL", width: 220)
                        cell("SALDO", width: 100, alignment: .trailing)
                        cell("STATUS", width: 140)
                        cell("VIP", width: 64, alignment: .center)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BlaxxColor.gray600)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(BlaxxColor.gray100)

                    if loading && users.isEmpty {
                        ProgressView().padding(24)
                    } else if let e = error {
                        Text("Erro: \(e)")
                            .foregroundStyle(BlaxxColor.negative)
                            .font(.system(size: 13))
                            .padding(16)
                    } else if users.isEmpty {
                        Text("Nenhum usuário encontrado.")
                            .foregroundStyle(BlaxxColor.gray400)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(24)
                    } else {
                        ForEach(users) { u in
                            row(u)
                            Divider()
                        }
                    }
                }
            }

            // Paginador
            HStack {
                Text("Mostrando \(users.isEmpty ? 0 : offset+1)–\(offset + users.count) de \(total)")
                    .font(.system(size: 12))
                    .foregroundStyle(BlaxxColor.gray600)
                Spacer()
                Button("‹ Anterior") {
                    offset = max(0, offset - pageSize)
                    Task { await load() }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(offset == 0)
                Button("Próxima ›") {
                    offset = offset + pageSize
                    Task { await load() }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(offset + pageSize >= total)
            }
            .padding(.top, 4)
        }
        .task(id: "\(query)|\(roleFilter)|\(vipFilter)") { await loadResetting() }
    }

    @ViewBuilder
    private func row(_ u: AdminUserDTO) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if u.isAdmin {
                    Text("ADMIN")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(BlaxxColor.black))
                        .foregroundStyle(BlaxxColor.lime)
                }
                Text(u.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)

            Text(u.email)
                .font(.system(size: 12))
                .foregroundStyle(BlaxxColor.gray600)
                .lineLimit(1)
                .frame(width: 220, alignment: .leading)

            Text("\(fmt(u.balance_pts)) pts")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 100, alignment: .trailing)

            HStack(spacing: 4) {
                if u.is_vip {
                    Chip(text: "VIP", variant: .success)
                }
                Chip(text: u.email_verified ? "✓" : "!",
                     variant: u.email_verified ? .success : .danger)
            }
            .frame(width: 140, alignment: .leading)

            Toggle("", isOn: Binding(
                get: { u.is_vip },
                set: { newValue in
                    Task { await toggleVip(u.id, to: newValue) }
                }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: BlaxxColor.lime))
            .frame(width: 64, alignment: .center)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }

    private func cell(_ text: String, width: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(text)
            .frame(width: width, alignment: alignment)
    }

    private func loadResetting() async {
        offset = 0
        await load()
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let r = try await BlaxxAPI.shared.adminListUsers(
                query: query, role: roleFilter, vip: vipFilter,
                limit: pageSize, offset: offset
            )
            users = r.items
            total = r.total
            error = nil
        } catch is CancellationError { /* ignora */ }
        catch let apiErr as APIError {
            error = apiErr.message
        } catch let e {
            error = e.localizedDescription
        }
    }

    private func toggleVip(_ userId: String, to newValue: Bool) async {
        do {
            _ = try await BlaxxAPI.shared.adminSetVip(userId, isVip: newValue)
            await load()
        } catch let e {
            error = "Falha ao atualizar VIP: \(e.localizedDescription)"
        }
    }

    private func fmt(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Tabela de transações

private struct AdminTransactionsTable: View {
    @State private var txs: [AdminTransactionDTO] = []
    @State private var typeFilter = ""
    @State private var total = 0
    @State private var offset = 0
    @State private var loading = false
    @State private var error: String?

    private let pageSize = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Tipo", selection: $typeFilter) {
                    Text("Todos os tipos").tag("")
                    Text("Compra").tag("purchase")
                    Text("Recebido").tag("transfer_in")
                    Text("Enviado").tag("transfer_out")
                    Text("Resgate").tag("redeem")
                    Text("Estorno").tag("refund")
                    Text("Bônus").tag("bonus")
                }
                .pickerStyle(.menu)
                Spacer()
            }

            BlaxxCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Text("DATA").frame(width: 130, alignment: .leading)
                        Text("USUÁRIO").frame(width: 220, alignment: .leading)
                        Text("TIPO").frame(width: 100, alignment: .leading)
                        Text("DESCRIÇÃO").frame(maxWidth: .infinity, alignment: .leading)
                        Text("VALOR").frame(width: 120, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BlaxxColor.gray600)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(BlaxxColor.gray100)

                    if loading && txs.isEmpty {
                        ProgressView().padding(24)
                    } else if let e = error {
                        Text(e).foregroundStyle(BlaxxColor.negative).padding(16)
                    } else if txs.isEmpty {
                        Text("Nenhuma transação.")
                            .foregroundStyle(BlaxxColor.gray400)
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(txs) { t in
                            row(t)
                            Divider()
                        }
                    }
                }
            }

            HStack {
                Text("Mostrando \(txs.isEmpty ? 0 : offset+1)–\(offset + txs.count) de \(total)")
                    .font(.system(size: 12))
                    .foregroundStyle(BlaxxColor.gray600)
                Spacer()
                Button("‹ Anterior") {
                    offset = max(0, offset - pageSize)
                    Task { await load() }
                }
                .buttonStyle(GhostButtonStyle()).disabled(offset == 0)
                Button("Próxima ›") {
                    offset += pageSize
                    Task { await load() }
                }
                .buttonStyle(GhostButtonStyle()).disabled(offset + pageSize >= total)
            }
        }
        .task(id: typeFilter) {
            offset = 0
            await load()
        }
    }

    @ViewBuilder
    private func row(_ t: AdminTransactionDTO) -> some View {
        HStack(spacing: 12) {
            Text(t.created_at.prefix(16).replacingOccurrences(of: "T", with: " "))
                .font(BlaxxFont.mono(11))
                .foregroundStyle(BlaxxColor.gray600)
                .frame(width: 130, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(t.user_name ?? "—")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(t.user_email ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(BlaxxColor.gray400)
                    .lineLimit(1)
            }
            .frame(width: 220, alignment: .leading)

            Chip(text: t.type, variant: .neutral)
                .frame(width: 100, alignment: .leading)

            Text(t.description.isEmpty ? "—" : t.description)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text((t.amount_pts > 0 ? "+" : "") + fmt(t.amount_pts))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(t.amount_pts > 0 ? BlaxxColor.limeDark : BlaxxColor.negative)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let r = try await BlaxxAPI.shared.adminTransactions(
                type: typeFilter, limit: pageSize, offset: offset
            )
            txs = r.items
            total = r.total
            error = nil
        } catch is CancellationError { /* ignora */ }
        catch let apiErr as APIError {
            error = apiErr.message
        } catch let e {
            error = e.localizedDescription
        }
    }

    private func fmt(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Tabela de pagamentos pendentes

private struct AdminPaymentsTable: View {
    @State private var pending: [AdminPendingChargeDTO] = []
    @State private var loading = false
    @State private var error: String?
    @State private var rejecting: AdminPendingChargeDTO?
    @State private var rejectReason: String = "PIX não localizado no extrato"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usuários que pagaram via PIX e estão aguardando confirmação. Confira no extrato bancário e libere os pontos.")
                .font(.system(size: 13))
                .foregroundStyle(BlaxxColor.gray600)

            BlaxxCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Text("CLICOU EM 'JÁ PAGUEI'").frame(width: 160, alignment: .leading)
                        Text("USUÁRIO").frame(width: 240, alignment: .leading)
                        Text("VALOR").frame(width: 100, alignment: .trailing)
                        Text("PONTOS").frame(width: 110, alignment: .trailing)
                        Spacer()
                        Text("AÇÃO").frame(width: 220, alignment: .center)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BlaxxColor.gray600)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(BlaxxColor.gray100)

                    if loading && pending.isEmpty {
                        ProgressView().padding(24)
                    } else if let e = error {
                        Text(e).foregroundStyle(BlaxxColor.negative).padding(16)
                    } else if pending.isEmpty {
                        Text("Nenhum pagamento aguardando.")
                            .foregroundStyle(BlaxxColor.gray400)
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(pending) { c in
                            payRow(c)
                            Divider()
                        }
                    }
                }
            }
        }
        .task { await load() }
        .sheet(item: $rejecting) { c in
            VStack(alignment: .leading, spacing: 16) {
                Text("Rejeitar pagamento de \(c.user_name ?? "—")")
                    .font(BlaxxFont.display(18))
                Text("Valor R$ \(String(format: "%.2f", c.amount_brl))")
                    .foregroundStyle(BlaxxColor.gray600)
                BlaxxField(label: "Motivo", value: $rejectReason,
                           placeholder: "PIX não localizado no extrato")
                HStack {
                    Button("Cancelar") { rejecting = nil }
                        .buttonStyle(GhostButtonStyle())
                    Spacer()
                    Button("Rejeitar") {
                        Task { await reject(c) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(24)
            .frame(width: 420)
        }
    }

    @ViewBuilder
    private func payRow(_ c: AdminPendingChargeDTO) -> some View {
        HStack(spacing: 12) {
            Text((c.claimed_paid_at ?? "—").prefix(16).replacingOccurrences(of: "T", with: " "))
                .font(BlaxxFont.mono(11))
                .frame(width: 160, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.user_name ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(c.user_email ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(BlaxxColor.gray400)
                    .lineLimit(1)
            }
            .frame(width: 240, alignment: .leading)
            Text("R$ \(String(format: "%.2f", c.amount_brl))")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 100, alignment: .trailing)
            Text("+\(payFmt(c.points_to_credit))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BlaxxColor.limeDark)
                .frame(width: 110, alignment: .trailing)
            Spacer()
            HStack(spacing: 8) {
                Button("Confirmar") {
                    Task { await confirm(c) }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Rejeitar") {
                    rejecting = c
                    rejectReason = "PIX não localizado no extrato"
                }
                .buttonStyle(GhostButtonStyle())
            }
            .frame(width: 220, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            let r = try await BlaxxAPI.shared.adminPendingCharges()
            pending = r.items
            error = nil
        } catch is CancellationError {} catch let e {
            error = e.localizedDescription
        }
    }

    private func confirm(_ c: AdminPendingChargeDTO) async {
        do {
            try await BlaxxAPI.shared.adminConfirmCharge(c.id)
            await load()
        } catch let e {
            error = "Falha ao confirmar: \(e.localizedDescription)"
        }
    }

    private func reject(_ c: AdminPendingChargeDTO) async {
        do {
            try await BlaxxAPI.shared.adminRejectCharge(c.id, reason: rejectReason)
            rejecting = nil
            await load()
        } catch let e {
            error = "Falha ao rejeitar: \(e.localizedDescription)"
        }
    }

    private func payFmt(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
