//
//  SecondaryViews.swift
//  BlaxxPontos
//
//  Telas secundárias: Extrato, Parceiros, Perfil.
//

import SwiftUI

// MARK: - Extrato

struct StatementView: View {
    @Environment(Session.self) private var session
    @State private var txs: [TransactionDTO] = []
    @State private var loading = true
    @State private var filter: String = ""
    @State private var loadError: String?
    @State private var lastFetchAt: Date?

    private var filtered: [TransactionDTO] {
        filter.isEmpty ? txs : txs.filter { $0.type == filter }
    }

    var body: some View {
        CompactReader { isCompact in
            statementBody(isCompact: isCompact)
        }
    }

    @ViewBuilder
    private func statementBody(isCompact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isCompact ? 16 : 24) {
                if !isCompact {
                    Topbar(eyebrow: "Movimentações", title: "Extrato",
                           userName: session.user?.name ?? "?")
                }

                BlaxxCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Eyebrow(text: "Histórico completo")
                                Text("Filtro")
                                    .font(BlaxxFont.display(isCompact ? 16 : 20))
                            }
                            Spacer()
                            Picker("", selection: $filter) {
                                Text("Todos").tag("")
                                Text("Compra").tag("purchase")
                                Text("Recebido").tag("transfer_in")
                                Text("Enviado").tag("transfer_out")
                                Text("Resgate").tag("redeem")
                                Text("Estorno").tag("refund")
                                Text("Bônus").tag("bonus")
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: isCompact ? 130 : 180)
                        }
                        if let loadError {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(BlaxxColor.negative)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Não foi possível carregar o extrato")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(loadError)
                                        .font(.system(size: 12))
                                        .foregroundStyle(BlaxxColor.gray600)
                                    Button("Tentar novamente") {
                                        Task { await load() }
                                    }
                                    .buttonStyle(GhostButtonStyle())
                                    .padding(.top, 4)
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(BlaxxColor.gray100))
                        }
                        if loading {
                            ProgressView().padding()
                        } else if filtered.isEmpty && loadError == nil {
                            Text("Sem movimentações neste filtro.")
                                .foregroundStyle(BlaxxColor.gray400).padding()
                        } else {
                            ForEach(filtered) { tx in
                                TransactionRow(tx: tx)
                                if tx.id != filtered.last?.id { Divider() }
                            }
                        }
                        if let lastFetchAt, loadError == nil, !txs.isEmpty {
                            Text("Atualizado às \(lastFetchAt.formatted(date: .omitted, time: .shortened)) · \(txs.count) movimentações")
                                .font(.system(size: 11))
                                .foregroundStyle(BlaxxColor.gray400)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(isCompact ? 16 : 40)
        }
        .background(BlaxxColor.appBg)
        .navigationTitle(isCompact ? "Extrato" : "")
        // Recarrega o extrato sempre que outra view (Buy/Send/Redeem) altera
        // a carteira. Sem isso o extrato fica desatualizado quando o usuário
        // volta para esta aba após comprar ou enviar pontos.
        .task(id: session.walletReloadTrigger) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true; defer { loading = false }
        loadError = nil
        do {
            let result = try await BlaxxAPI.shared.transactions(limit: 200)
            txs = result
            lastFetchAt = Date()
            print("StatementView: \(result.count) transações carregadas")
        } catch is CancellationError {
            // Navegação rápida — ignorar
        } catch let apiErr as APIError {
            loadError = apiErr.message
            print("StatementView APIError: \(apiErr.message)")
        } catch let e {
            loadError = e.localizedDescription
            print("StatementView erro: \(e)")
        }
    }
}

// MARK: - Parceiros

// Formatação local (pts / R$) — paridade com web/EXE.
private let pzDecimal: NumberFormatter = {
    let nf = NumberFormatter(); nf.numberStyle = .decimal
    nf.groupingSeparator = "."; nf.maximumFractionDigits = 0
    return nf
}()
private func pzPts(_ n: Int) -> String { (pzDecimal.string(from: NSNumber(value: n)) ?? "\(n)") + " pts" }
private func pzBRL(_ v: Double) -> String {
    let nf = NumberFormatter(); nf.numberStyle = .currency; nf.locale = Locale(identifier: "pt_BR")
    return nf.string(from: NSNumber(value: v)) ?? "R$ 0,00"
}

struct PartnersView: View {
    @Environment(Session.self) private var session
    @State private var partners: [PartnerDTO] = []
    @State private var categories: [String] = []
    @State private var wallet: WalletDTO?
    @State private var card: CardStateDTO?
    @State private var query: String = ""
    @State private var filter: String = ""          // "" = Todos · "__fav__" = Favoritos · else categoria
    @State private var loading = false
    @State private var selectedId: String?
    @State private var slide: Int = 0
    @State private var favs: Set<String> = PartnersView.loadFavs()

    private static let favKey = "blaxx_fav_partners"
    private static let primaryCats = ["Viagens", "Tecnologia", "Moda", "Casa", "Supermercado", "Saúde"]

    private static func loadFavs() -> Set<String> {
        Set(UserDefaults.standard.array(forKey: favKey) as? [String] ?? [])
    }
    private func saveFavs() { UserDefaults.standard.set(Array(favs), forKey: Self.favKey) }
    private func toggleFav(_ id: String) {
        if favs.contains(id) { favs.remove(id) } else { favs.insert(id) }
        saveFavs()
    }

    private var orderedCats: [String] {
        let primary = Self.primaryCats.filter { categories.contains($0) }
        let rest = categories.filter { !Self.primaryCats.contains($0) }
        return primary + rest
    }

    private var visible: [PartnerDTO] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return partners.filter { p in
            if filter == "__fav__" { if !favs.contains(p.id) { return false } }
            else if !filter.isEmpty { if p.category != filter { return false } }
            if !q.isEmpty {
                let hay = (p.name + " " + (p.description ?? "") + " " + p.category).lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    private var bannerItems: [PartnerDTO] { Array(partners.prefix(4)) }

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 22) {
                    if !isCompact {
                        Topbar(eyebrow: "Programa de Pontos", title: "Parceiros Blaxx",
                               userName: session.user?.name ?? "?")
                    }
                    Text("Milhares de parceiros para você acumular ainda mais pontos.")
                        .font(.system(size: 14))
                        .foregroundStyle(BlaxxColor.gray600)

                    metricsRail(isCompact: isCompact)

                    if !bannerItems.isEmpty { bannerView }

                    searchRow
                    pillsRow
                    gridView(isCompact: isCompact)
                    benefitsRow(isCompact: isCompact)
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Parceiros" : "")
            .task { await load() }
            .task(id: bannerItems.count) {
                guard bannerItems.count > 1 else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    if Task.isCancelled { break }
                    withAnimation(.easeInOut(duration: 0.5)) {
                        slide = (slide + 1) % max(bannerItems.count, 1)
                    }
                }
            }
            .sheet(item: Binding(
                get: { selectedId.map { PartnerIDWrapper(id: $0) } },
                set: { selectedId = $0?.id }
            )) { wrap in
                PartnerDetailView(partnerId: wrap.id).environment(session)
            }
        }
    }

    // MARK: Métricas

    @ViewBuilder private func metricsRail(isCompact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 150 : 180), spacing: 12)], spacing: 12) {
            metricCard(label: "Saldo atual", value: wallet.map { pzPts($0.balance_pts) } ?? "—")
            metricCard(label: "Valor estimado", value: wallet.map { pzBRL($0.balance_brl_equiv) } ?? "—")
            metricCard(label: "Pontos pendentes",
                       value: wallet.map { pzPts($0.pending_pts) } ?? "—",
                       hint: (wallet?.pending_pts ?? 0) > 0 ? "Em processamento" : "Nada pendente")
            tierCard
            progressCard
        }
    }

    private func metricCard(label: String, value: String, hint: String? = nil) -> some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: label, color: BlaxxColor.gray400)
                Text(value).font(BlaxxFont.display(22)).foregroundStyle(BlaxxColor.black)
                if let hint {
                    Text(hint).font(.system(size: 12, weight: .semibold)).foregroundStyle(BlaxxColor.gray600)
                }
            }
        }
    }

    private var tierCard: some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Nível atual", color: BlaxxColor.gray400)
                if let t = card?.tier {
                    Text(t.label.uppercased())
                        .font(.system(size: 13, weight: .bold)).tracking(0.6)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(Color(blaxxHex: t.color) ?? BlaxxColor.black))
                        .foregroundStyle(Color(blaxxHex: t.text_color) ?? .white)
                } else {
                    Text("—").font(BlaxxFont.display(22)).foregroundStyle(BlaxxColor.black)
                }
            }
        }
    }

    private var progressCard: some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Progresso", color: BlaxxColor.gray400)
                Text("\(card?.progress_pct ?? 0)%").font(BlaxxFont.display(22)).foregroundStyle(BlaxxColor.black)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(BlaxxColor.gray200).frame(height: 8)
                        Capsule().fill(BlaxxColor.lime)
                            .frame(width: geo.size.width * CGFloat(card?.progress_pct ?? 0) / 100, height: 8)
                    }
                }.frame(height: 8)
                if let next = card?.next_tier {
                    Text("Faltam \(pzPts(card?.points_to_next ?? 0)) para \(next.label)")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(BlaxxColor.gray600)
                } else {
                    Text("Nível máximo atingido")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(BlaxxColor.gray600)
                }
            }
        }
    }

    // MARK: Banner carrossel

    private var bannerView: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(Array(bannerItems.enumerated()), id: \.element.id) { idx, p in
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Campanha em destaque", color: BlaxxColor.lime)
                        Text(p.name).font(BlaxxFont.display(26)).foregroundStyle(.white)
                        Text(p.description ?? (p.accrual_rule ?? ""))
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).lineLimit(2)
                        Button { selectedId = p.id } label: {
                            Text("Ir para \(p.name) →")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(Capsule().fill(BlaxxColor.lime))
                                .foregroundStyle(BlaxxColor.black)
                        }.buttonStyle(.plain).padding(.top, 4)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 12)
                    Text(p.logo_emoji ?? "🏷️").font(.system(size: 60))
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(idx == slide ? 1 : 0)
            }
            HStack(spacing: 6) {
                ForEach(Array(0..<bannerItems.count), id: \.self) { i in
                    Capsule().fill(i == slide ? BlaxxColor.lime : Color.white.opacity(0.35))
                        .frame(width: i == slide ? 20 : 8, height: 8)
                        .onTapGesture { withAnimation { slide = i } }
                }
            }.padding(20)
        }
        .frame(height: 180)
        .background(BlaxxColor.black)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: Busca + favoritos

    private var searchRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(BlaxxColor.gray400)
                TextField("Buscar parceiro ou loja", text: $query).textFieldStyle(.plain)
            }
            .padding(.horizontal, 16).frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(BlaxxColor.white))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BlaxxColor.border, lineWidth: 0.5))

            Button { filter = (filter == "__fav__") ? "" : "__fav__" } label: {
                Text(filter == "__fav__" ? "♥ Favoritos" : "♡ Favoritos")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(filter == "__fav__" ? BlaxxColor.black : BlaxxColor.white))
                    .foregroundStyle(filter == "__fav__" ? BlaxxColor.lime : BlaxxColor.gray800)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(BlaxxColor.border, lineWidth: 0.5))
            }.buttonStyle(.plain)
        }
    }

    // MARK: Filtros (pills)

    private var pillsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill("Todos", value: "")
                pill("Favoritos", value: "__fav__")
                ForEach(orderedCats, id: \.self) { c in pill(c, value: c) }
            }
        }
    }

    private func pill(_ label: String, value: String) -> some View {
        let active = filter == value
        return Button { filter = value } label: {
            Text(label).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(active ? BlaxxColor.lime : BlaxxColor.white))
                .foregroundStyle(active ? BlaxxColor.black : BlaxxColor.gray600)
                .overlay(Capsule().stroke(active ? Color.clear : BlaxxColor.border, lineWidth: 0.5))
        }.buttonStyle(.plain)
    }

    // MARK: Grid

    @ViewBuilder private func gridView(isCompact: Bool) -> some View {
        if loading && partners.isEmpty {
            ProgressView().padding()
        } else if visible.isEmpty {
            Text("Nenhum parceiro encontrado.")
                .foregroundStyle(BlaxxColor.gray400).padding(.vertical, 24)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 160 : 200), spacing: 14)], spacing: 14) {
                ForEach(visible) { p in partnerCard(p) }
            }
        }
    }

    private func partnerCard(_ p: PartnerDTO) -> some View {
        Button { selectedId = p.id } label: {
            BlaxxCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(p.logo_emoji ?? "🏷️").font(.system(size: 26))
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(BlaxxColor.gray100))
                        Spacer()
                        Button { toggleFav(p.id) } label: {
                            Image(systemName: favs.contains(p.id) ? "heart.fill" : "heart")
                                .foregroundStyle(favs.contains(p.id) ? BlaxxColor.negative : BlaxxColor.gray400)
                        }.buttonStyle(.plain)
                    }
                    Text(p.name).font(BlaxxFont.display(16)).foregroundStyle(BlaxxColor.black)
                    Text(p.category.uppercased())
                        .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                        .foregroundStyle(BlaxxColor.gray400)
                    if let r = p.accrual_rule, !r.isEmpty {
                        Text(r).font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(BlaxxColor.lime)).foregroundStyle(BlaxxColor.black)
                    }
                    if let city = p.city, !city.isEmpty {
                        Text("📍 \(city)").font(.system(size: 12, weight: .semibold)).foregroundStyle(BlaxxColor.gray400)
                    }
                    Text("Comprar →").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BlaxxColor.black).padding(.top, 2)
                }
            }
        }.buttonStyle(.plain)
    }

    // MARK: Rodapé de benefícios

    @ViewBuilder private func benefitsRow(isCompact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 150 : 220), spacing: 14)], spacing: 14) {
            benefit("📈", "Acumule Mais", "Compre nas melhores lojas e acumule até 12 pts por real.")
            benefit("💵", "Cashback", "Receba parte do valor de volta em pontos ou saldo.")
            benefit("⭐", "Parceiros Exclusivos", "Benefícios reservados para clientes Black.")
            benefit("🔒", "Segurança", "Ambiente protegido e monitorado de ponta a ponta.")
        }.padding(.top, 8)
    }

    private func benefit(_ ico: String, _ title: String, _ desc: String) -> some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(ico).font(.system(size: 24))
                Text(title).font(BlaxxFont.display(15)).foregroundStyle(BlaxxColor.black)
                Text(desc).font(.system(size: 12)).foregroundStyle(BlaxxColor.gray600)
            }
        }
    }

    // MARK: Carregamento

    private func load() async {
        loading = true; defer { loading = false }
        async let pTask = BlaxxAPI.shared.partners()
        async let cTask = BlaxxAPI.shared.partnerCategories()
        async let wTask = BlaxxAPI.shared.wallet()
        async let cdTask = BlaxxAPI.shared.card()
        partners = (try? await pTask) ?? []
        categories = (try? await cTask) ?? []
        wallet = try? await wTask
        card = try? await cdTask
    }
}

/// Wrapper Identifiable pra sheet(item:)
private struct PartnerIDWrapper: Identifiable { let id: String }

struct PartnerDetailView: View {
    let partnerId: String
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var detail: PartnerDetailDTO?
    @State private var loading = false

    var body: some View {
        ZStack {
            BlaxxColor.gray50.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Button("Fechar") { dismiss() }
                            .buttonStyle(GhostButtonStyle())
                    }
                    if let d = detail {
                        BlaxxCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Chip(text: d.category, variant: .dark)
                                HStack(spacing: 12) {
                                    Text(d.logo_emoji ?? "◯")
                                        .font(.system(size: 36))
                                    Text(d.name)
                                        .font(BlaxxFont.display(28))
                                }
                                if let desc = d.description {
                                    Text(desc)
                                        .font(.system(size: 13))
                                        .foregroundStyle(BlaxxColor.gray600)
                                }
                            }
                        }
                        BlaxxCard(variant: .lime) {
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: "Regra de acúmulo")
                                Text(d.accrual_rule ?? "—")
                                    .font(BlaxxFont.display(18))
                                    .foregroundStyle(BlaxxColor.black)
                            }
                        }
                        if let bens = d.benefits, !bens.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Eyebrow(text: "Benefícios deste parceiro")
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 200), spacing: 12)],
                                    spacing: 12
                                ) {
                                    ForEach(bens) { b in
                                        BlaxxCard {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(b.image_emoji ?? "★").font(.system(size: 24))
                                                Text(b.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text("\(b.cost_pts) pts")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(BlaxxColor.limeDark)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else if loading {
                        ProgressView().padding(40)
                    }
                }
                .padding(30)
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true; defer { loading = false }
        do { detail = try await BlaxxAPI.shared.partner(partnerId) }
        catch { /* silencioso */ }
    }
}

// MARK: - Perfil

struct ProfileView: View {
    @Environment(Session.self) private var session
    @State private var showingChangePassword = false
    @State private var showingEmailVerify = false
    // Exclusão de conta (LGPD): confirmação + captura de senha + chamada API.
    @State private var showingDeleteConfirm = false
    @State private var showingDeletePassword = false
    @State private var deletePassword = ""
    @State private var deleteBusy = false
    @State private var deleteError: String?

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 24) {
                    if !isCompact {
                        Topbar(eyebrow: "Você", title: "Perfil",
                               userName: session.user?.name ?? "?")
                    }

                    AdaptiveStack(spacing: 16) {
                        BlaxxCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Eyebrow(text: "Dados pessoais")
                                Text("Seu perfil").font(BlaxxFont.display(isCompact ? 18 : 20))
                                if let u = session.user {
                                    row("Nome", u.name)
                                    row("E-mail", u.email)
                                    row("CPF", u.cpf)
                                    row("Chave PIX", u.pix_key ?? "não cadastrada")
                                }
                            }
                        }
                        BlaxxCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Eyebrow(text: "Conta")
                                Text("Ações").font(BlaxxFont.display(isCompact ? 18 : 20))
                                Button("Alterar senha") {
                                    showingChangePassword = true
                                }
                                .buttonStyle(GhostButtonStyle(fullWidth: true))
                                if let u = session.user, !u.isEmailVerified {
                                    Button("Confirmar e-mail") {
                                        showingEmailVerify = true
                                    }
                                    .buttonStyle(GhostButtonStyle(fullWidth: true))
                                }
                                Button("Indique e ganhe") {}
                                    .buttonStyle(GhostButtonStyle(fullWidth: true))
                                Button("Termos e privacidade") {}
                                    .buttonStyle(GhostButtonStyle(fullWidth: true))
                                Divider()
                                Button("Excluir conta (LGPD)") {
                                    showingDeleteConfirm = true
                                }
                                    .buttonStyle(GhostButtonStyle(fullWidth: true))
                                    .tint(BlaxxColor.negative)
                            }
                        }
                    }
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Perfil" : "")
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showingEmailVerify) {
                EmailVerifyView().environment(session)
            }
            .confirmationDialog(
                "Excluir conta?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Continuar", role: .destructive) {
                    deletePassword = ""
                    deleteError = nil
                    showingDeletePassword = true
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tem certeza? Esta ação é irreversível. Seus pontos, histórico e dados pessoais serão removidos.")
            }
            .sheet(isPresented: $showingDeletePassword) {
                deletePasswordSheet
            }
        }
    }

    private var deletePasswordSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Confirme sua senha")
                        .font(BlaxxFont.display(22, weight: .bold))
                    Text("Para excluir sua conta, digite sua senha atual.")
                        .foregroundStyle(BlaxxColor.gray600)
                        .font(.system(size: 14))
                    BlaxxField(label: "Senha", value: $deletePassword,
                               placeholder: "••••••••",
                               isSecure: true)
                    if let deleteError {
                        Text(deleteError)
                            .font(.system(size: 13))
                            .foregroundStyle(BlaxxColor.negative)
                    }
                    Button(deleteBusy ? "Excluindo…" : "Excluir conta agora") {
                        Task { await performDelete() }
                    }
                    .buttonStyle(DarkButtonStyle(fullWidth: true))
                    .tint(BlaxxColor.negative)
                    .disabled(deleteBusy || deletePassword.isEmpty)
                    Button("Cancelar") {
                        showingDeletePassword = false
                    }
                    .buttonStyle(GhostButtonStyle(fullWidth: true))
                    .disabled(deleteBusy)
                }
                .padding(24)
            }
            .navigationTitle("Excluir conta")
        }
    }

    private func performDelete() async {
        deleteBusy = true; deleteError = nil
        defer { deleteBusy = false }
        do {
            try await BlaxxAPI.shared.deleteAccount(password: deletePassword)
            // Limpa estado local e desloga.
            TokenStore.clear()
            TokenStore.clearProfile()
            // Remove preferências (best-effort): a chave de override do backend
            // só existe em DEBUG, mas removemos sempre para garantir um estado
            // limpo após exclusão.
            UserDefaults.standard.removeObject(forKey: "blaxx_backend_url")
            await MainActor.run {
                session.user = nil
                showingDeletePassword = false
                showingDeleteConfirm = false
            }
        } catch let e as APIError {
            deleteError = e.message
        } catch {
            deleteError = "Não foi possível excluir a conta agora."
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(BlaxxColor.gray600).font(.system(size: 13))
            Spacer()
            Text(v).font(.system(size: 14, weight: .semibold))
        }
    }
}
