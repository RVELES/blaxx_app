//
//  DashboardView.swift
//  BlaxxPontos
//
//  "Command Center" premium. Dados REAIS: /wallet (saldo, R$), /card (nível,
//  progresso), /partners. Seções sem fonte (Oportunidade, Wealth Score,
//  Exchange, Intelligence) são showcase, marcadas "demo".
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(Session.self) private var session
    @Binding var selection: Tab

    @Query private var cachedWallets: [CachedWallet]

    @State private var balancePts: Int = 0
    @State private var balanceBRL: Double = 0
    @State private var pendingPts: Int = 0
    @State private var transactions: [TransactionDTO] = []
    @State private var partners: [PartnerDTO] = []
    @State private var card: CardStateDTO?
    @State private var loading = false
    @State private var error: String?
    @State private var showingEmailVerify = false

    private func ccPts(_ n: Int) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    private func ccBRL(_ v: Double) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .currency; nf.locale = Locale(identifier: "pt_BR")
        return nf.string(from: NSNumber(value: v)) ?? "R$ 0,00"
    }
    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Bom dia" : (h < 18 ? "Boa tarde" : "Boa noite")
    }
    private var firstName: String {
        (session.user?.name.split(separator: " ").first).map(String.init) ?? "cliente"
    }

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 18 : 26) {
                    if !isCompact {
                        Topbar(eyebrow: "Command Center",
                               title: "\(greeting), \(firstName) 👋",
                               userName: session.user?.name ?? "?")
                    }

                    if let u = session.user, !u.isEmailVerified {
                        emailBanner
                    }

                    heroCard

                    AdaptiveStack(spacing: 16) { levelsCard; transferCard }
                    AdaptiveStack(spacing: 16) { opportunityCard; marketplaceCard }
                    AdaptiveStack(spacing: 16) { campaignsCard; activityCard }
                    AdaptiveStack(spacing: 16) { wealthScoreCard; exchangeCard }
                    intelligenceCard

                    Text("Pontos são créditos promocionais — não são moeda, depósito ou investimento. Seções marcadas “demo” são ilustrativas.")
                        .font(.system(size: 12))
                        .foregroundStyle(BlaxxColor.gray400)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.paper)
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(isCompact ? .inline : .large)
            .toolbar {
                if isCompact {
                    ToolbarItem(placement: .principal) {
                        BlaxxWordmark(size: 20, tone: .light)
                            .fixedSize()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { selection = .profile } label: {
                            Avatar(name: session.user?.name ?? "?", size: 30)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            #endif
            .task(id: session.walletReloadTrigger) { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showingEmailVerify) {
                EmailVerifyView().environment(session)
            }
        }
    }

    // MARK: Banner e-mail

    private var emailBanner: some View {
        Button { showingEmailVerify = true } label: {
            HStack {
                Image(systemName: "envelope.badge.fill").foregroundStyle(BlaxxColor.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Confirme seu e-mail").font(.system(size: 13, weight: .semibold)).foregroundStyle(BlaxxColor.black)
                    Text("Compra, envio e resgate ficam bloqueados até confirmar.")
                        .font(.system(size: 11)).foregroundStyle(BlaxxColor.gray600)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(BlaxxColor.gray400)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 1, green: 0.95, blue: 0.78)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BlaxxColor.warning, lineWidth: 0.5))
        }.buttonStyle(.plain)
    }

    // MARK: Hero (REAL)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Patrimônio em Rewards 👁").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(ccPts(balancePts)).font(.system(size: 42, weight: .black)).foregroundStyle(.white)
                Text("pts").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            }
            Text("≈ \(ccBRL(balanceBRL))").font(.system(size: 18, weight: .bold)).foregroundStyle(BlaxxColor.lime)
            Text(pendingPts > 0 ? "\(ccPts(pendingPts)) pts em processamento" : "Nenhum ponto pendente")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 10) {
                ccQuick("🛒", "Comprar", primary: true) { selection = .buy }
                ccQuick("✈", "Transferir") { selection = .send }
                ccQuick("⇄", "Resgatar") { selection = .redeem }
                ccQuick("🎁", "Parceiros") { selection = .partners }
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.024, green: 0.031, blue: 0.039),
                                              Color(red: 0.051, green: 0.071, blue: 0.09)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private func ccQuick(_ icon: String, _ label: String, primary: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(icon).font(.system(size: 20))
                Text(label).font(.system(size: 12, weight: .bold))
            }
            .frame(maxWidth: .infinity).frame(height: 64)
            .background(RoundedRectangle(cornerRadius: 14).fill(primary ? BlaxxColor.lime : BlaxxColor.white))
            .foregroundStyle(BlaxxColor.black)
        }.buttonStyle(.plain)
    }

    // MARK: Níveis (REAL)

    private var tierBg: Color { (card?.tier.color).flatMap { Color(blaxxHex: $0) } ?? BlaxxColor.black }
    private var tierFg: Color { (card?.tier.text_color).flatMap { Color(blaxxHex: $0) } ?? .white }

    private var levelsCard: some View {
        BlaxxCard(variant: .brutal) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Níveis Blaxx", actionLabel: "Cartão →") { selection = .card }
                VStack(alignment: .leading, spacing: 4) {
                    Text((card?.tier.label ?? "—").uppercased())
                        .font(.system(size: 26, weight: .black)).foregroundStyle(tierFg)
                    Text((card?.lifetime_points ?? 0) > 0 ? "\(ccPts(card?.lifetime_points ?? 0)) pts acumulados" : "Programa de pontos")
                        .font(.system(size: 12)).foregroundStyle(tierFg.opacity(0.85))
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(tierBg))
                HStack {
                    Text(card?.next_tier != nil ? "Progresso para \(card!.next_tier!.label)" : "Nível máximo")
                        .font(.system(size: 12)).foregroundStyle(BlaxxColor.gray600)
                    Spacer()
                    Text("\(card?.progress_pct ?? 0)%").font(.system(size: 12, weight: .bold))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(BlaxxColor.gray200).frame(height: 8)
                        Capsule().fill(BlaxxColor.lime)
                            .frame(width: geo.size.width * CGFloat(card?.progress_pct ?? 0) / 100, height: 8)
                    }
                }.frame(height: 8)
                if let n = card?.next_tier {
                    Text("Faltam \(ccPts(card?.points_to_next ?? 0)) pts para \(n.label).")
                        .font(.system(size: 12)).foregroundStyle(BlaxxColor.gray600)
                }
            }
        }
    }

    // MARK: Transferir (REAL)

    private var transferCard: some View {
        BlaxxCard(variant: .brutal) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Transferir pontos").font(BlaxxFont.display(17)).foregroundStyle(BlaxxColor.black)
                Text("Envie pontos a outro cliente Blaxx, sem taxa.")
                    .font(.system(size: 13)).foregroundStyle(BlaxxColor.gray600)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saldo disponível").font(.system(size: 12)).foregroundStyle(BlaxxColor.gray600)
                    Text("\(ccPts(balancePts)) pts").font(.system(size: 24, weight: .black)).foregroundStyle(BlaxxColor.black)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(BlaxxColor.gray50))
                Button { selection = .send } label: {
                    Text("Enviar agora →").font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Capsule().fill(BlaxxColor.lime)).foregroundStyle(BlaxxColor.black)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: Oportunidade (showcase)

    private var opportunityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OPORTUNIDADE DETECTADA").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(BlaxxColor.lime)
            Text("LATAM PASS").font(.system(size: 26, weight: .black)).foregroundStyle(.white)
            Text("Bônus 85%").font(.system(size: 22, weight: .black)).foregroundStyle(BlaxxColor.lime)
            Text("Potencial ganho: + 122.000 pontos").font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
            Button { selection = .partners } label: {
                Text("Explorar parceiros").font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 22).padding(.vertical, 11)
                    .background(Capsule().fill(BlaxxColor.lime)).foregroundStyle(BlaxxColor.black)
            }.buttonStyle(.plain).padding(.top, 6)
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(red: 0.1, green: 0.06, blue: 0.19), Color(red: 0.04, green: 0.07, blue: 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(alignment: .topTrailing) { demoBadge.padding(12) }
    }

    // MARK: Marketplace (parceiros REAIS)

    private var marketplaceCard: some View {
        BlaxxCard(variant: .brutal) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Marketplace", actionLabel: "Ver tudo →") { selection = .partners }
                if partners.isEmpty {
                    Text("Carregando parceiros…").font(.system(size: 13)).foregroundStyle(BlaxxColor.gray400)
                } else {
                    ForEach(partners.prefix(4)) { p in
                        TileRow(emoji: p.logo_emoji ?? "🎁", title: p.name,
                                subtitle: p.accrual_rule ?? p.category, meta: "Trocar") { selection = .partners }
                        if p.id != partners.prefix(4).last?.id { Divider() }
                    }
                }
            }
        }
    }

    // MARK: Campanhas (programa)

    private var campaignsCard: some View {
        BlaxxCard(variant: .brutal) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Campanhas ativas", actionLabel: "Ver todas →") { selection = .partners }
                TileRow(emoji: "🎯", title: "Dobro de pontos em viagens",
                        subtitle: "Até 30/06 · parceiros selecionados", meta: "2x") { selection = .partners }
                TileRow(emoji: "🛍️", title: "Cashback turbo no varejo",
                        subtitle: "Resgate via PIX em 6 meses", meta: "+5%") { selection = .redeem }
            }
        }
    }

    // MARK: Atividade (REAL)

    private var activityCard: some View {
        BlaxxCard(variant: .brutal) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Últimas movimentações", actionLabel: "Ver extrato →") { selection = .statement }
                if transactions.isEmpty {
                    Text("Nenhuma movimentação ainda.").font(.system(size: 13)).foregroundStyle(BlaxxColor.gray400)
                } else {
                    ForEach(transactions.prefix(5)) { tx in
                        TransactionRow(tx: tx)
                        if tx.id != transactions.prefix(5).last?.id { Divider() }
                    }
                }
            }
        }
    }

    // MARK: Wealth Score (showcase)

    private var wealthScoreCard: some View {
        VStack(spacing: 10) {
            Text("Rewards Wealth Score™").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            ZStack {
                Circle().stroke(BlaxxColor.lime.opacity(0.22), lineWidth: 18)
                Circle().trim(from: 0, to: 0.89)
                    .stroke(BlaxxColor.lime, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("8.9").font(.system(size: 44, weight: .black)).foregroundStyle(.white)
                    Text("/10").font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 150, height: 150).padding(.vertical, 6)
            Text("Elite").font(.system(size: 20, weight: .black)).foregroundStyle(BlaxxColor.lime)
            Text("Indicador ilustrativo de performance.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(red: 0.027, green: 0.035, blue: 0.043), Color(red: 0.067, green: 0.082, blue: 0.102)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(alignment: .topTrailing) { demoBadge.padding(12) }
    }

    // MARK: Exchange (showcase)

    private var exchangeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Rewards Exchange™").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Text("Ilustrativo").font(.system(size: 12, weight: .bold)).foregroundStyle(BlaxxColor.lime)
            }.padding(.bottom, 6)
            exchangeRow("S", "SMILES", "0,021", "0,024")
            exchangeRow("L", "LIVELO", "0,034", "0,037")
            exchangeRow("A", "AZUL", "0,019", "0,022")
            exchangeRow("T", "LATAM", "0,023", "0,026")
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(red: 0.027, green: 0.035, blue: 0.043), Color(red: 0.067, green: 0.082, blue: 0.102)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(alignment: .topTrailing) { demoBadge.padding(12) }
    }

    private func exchangeRow(_ k: String, _ name: String, _ buy: String, _ sell: String) -> some View {
        HStack {
            Text(k).font(.system(size: 14, weight: .black)).foregroundStyle(BlaxxColor.black)
                .frame(width: 34, height: 34).background(RoundedRectangle(cornerRadius: 10).fill(BlaxxColor.lime))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("Compra \(buy)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Text("Venda \(sell)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5) }
    }

    // MARK: Intelligence (showcase)

    private var intelligenceCard: some View {
        BlaxxCard(variant: .brutal) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Intelligence Center™").font(BlaxxFont.display(16)).foregroundStyle(BlaxxColor.black)
                intelRow("S", "Melhor transferência hoje", "SMILES +80%", "Prazo: 48 horas")
                intelRow("✈", "Melhor resgate", "Business Class", "São Paulo → Londres")
                Text("Recomendações ilustrativas — em breve com dados reais.")
                    .font(.system(size: 12)).foregroundStyle(BlaxxColor.gray400)
            }
        }
        .overlay(alignment: .topTrailing) {
            Text("demo").font(.system(size: 10, weight: .bold)).textCase(.uppercase).tracking(0.6)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Capsule().fill(BlaxxColor.limeLight)).foregroundStyle(BlaxxColor.limeDark)
                .padding(12)
        }
    }

    private func intelRow(_ k: String, _ top: String, _ mid: String, _ bot: String) -> some View {
        HStack(spacing: 12) {
            Text(k).font(.system(size: 14, weight: .black)).foregroundStyle(BlaxxColor.black)
                .frame(width: 34, height: 34).background(RoundedRectangle(cornerRadius: 10).fill(BlaxxColor.lime))
            VStack(alignment: .leading, spacing: 1) {
                Text(top).font(.system(size: 11)).foregroundStyle(BlaxxColor.gray600)
                Text(mid).font(.system(size: 15, weight: .semibold)).foregroundStyle(BlaxxColor.black)
                Text(bot).font(.system(size: 11)).foregroundStyle(BlaxxColor.gray600)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(BlaxxColor.gray50))
    }

    private var demoBadge: some View {
        Text("demo").font(.system(size: 10, weight: .bold)).textCase(.uppercase).tracking(0.6)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(BlaxxColor.lime)).foregroundStyle(BlaxxColor.black)
    }

    // MARK: Carregamento

    private func load() async {
        if let userId = session.user?.id,
           let cached = cachedWallets.first(where: { $0.userId == userId }) {
            balancePts = cached.balancePts
            balanceBRL = cached.balanceBRLEquiv
        }
        loading = true
        defer { loading = false }
        do {
            let w = try await BlaxxAPI.shared.wallet()
            balancePts = w.balance_pts
            balanceBRL = w.balance_brl_equiv
            pendingPts = w.pending_pts
            transactions = try await BlaxxAPI.shared.transactions(limit: 10)
            partners = try await BlaxxAPI.shared.partners()
            card = try? await BlaxxAPI.shared.card()

            if let userId = session.user?.id {
                if let existing = cachedWallets.first(where: { $0.userId == userId }) {
                    existing.apply(w)
                } else {
                    context.insert(CachedWallet(userId: userId,
                                                balancePts: w.balance_pts,
                                                pendingPts: w.pending_pts,
                                                balanceBRLEquiv: w.balance_brl_equiv))
                }
                try? context.save()
            }
        } catch is CancellationError {
        } catch let e {
            self.error = e.localizedDescription
        }
    }
}

struct TransactionRow: View {
    let tx: TransactionDTO
    private var formatted: String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        let s = nf.string(from: NSNumber(value: abs(tx.amount_pts))) ?? "\(tx.amount_pts)"
        return (tx.amount_pts > 0 ? "+" : "-") + s
    }
    var body: some View {
        HStack {
            Chip(text: tx.type, variant: tx.amount_pts > 0 ? .success : .neutral)
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.description.isEmpty ? "—" : tx.description)
                    .font(.system(size: 13))
                Text(tx.created_at.prefix(16).replacingOccurrences(of: "T", with: " "))
                    .font(.system(size: 11))
                    .foregroundStyle(BlaxxColor.gray400)
            }
            Spacer()
            Text(formatted + " pts")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tx.amount_pts > 0 ? BlaxxColor.limeDark : BlaxxColor.negative)
        }
        .padding(.vertical, 4)
    }
}
