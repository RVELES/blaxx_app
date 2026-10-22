//
//  RewardsCatalogViews.swift
//  BlaxxPontos
//
//  Cartão BlaXx, Campanhas e o catálogo de resgate com pontos.
//
//  Espelham, respectivamente, `blaxx/cartao.html` (GET /card/),
//  `blaxx/campanhas.html` (GET /campaigns/) e `blaxx/resgates.html`
//  (GET /benefits/, GET /vouchers/, POST /benefits/<id>/redeem).
//

import SwiftUI

// MARK: - Cartão BlaXx

struct RWCardView: View {
    @Environment(RewardsBackend.self) private var backend
    var onBack: () -> Void

    @State private var state: CardStateDTO?
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                RWScreenHeader(title: "Cartão BlaXx", onBack: onBack)

                if loading {
                    RWListState(kind: .loading, message: "Carregando cartão…")
                } else if failed || state == nil {
                    RWListState(kind: .failed, message: "Não foi possível carregar o cartão.")
                } else if let s = state {
                    cardFace(s)
                    progress(s)
                    tiers(s)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .task { await load() }
    }

    private func cardFace(_ s: CardStateDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                (Text("Bla").foregroundColor(.white)
                 + Text("Xx").foregroundColor(RWColor.neon))
                    .font(BlaxxFont.display(19, weight: .bold))
                Spacer()
                Text(s.tier.label.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(RWColor.ink)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RWColor.neon)
                    .clipShape(Capsule())
            }
            Text(backend.cardIdFormatted ?? "—")
                .font(.system(size: 21, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white)
                .padding(.top, 26)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TITULAR")
                        .font(.system(size: 9, weight: .heavy)).tracking(1)
                        .foregroundStyle(RWColor.heroSub)
                    Text(s.member.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SALDO")
                        .font(.system(size: 9, weight: .heavy)).tracking(1)
                        .foregroundStyle(RWColor.heroSub)
                    Text("\(RWFormat.n(s.balance_pts)) pts")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RWColor.neon)
                }
            }
            .padding(.top, 22)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RWColor.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .rwCardShadow()
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func progress(_ s: CardStateDTO) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if let next = s.next_tier {
                Text("Faltam \(RWFormat.n(s.points_to_next)) pontos para \(next.label)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RWColor.ink)
            } else {
                Text("Você está no nível máximo.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RWColor.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(RWColor.pctBg)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(RWColor.neon)
                        .frame(width: geo.size.width * CGFloat(min(100, max(0, s.progress_pct))) / 100)
                }
            }
            .frame(height: 12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(RWColor.ink, lineWidth: 2))
            Text("Acumulado na vida: \(RWFormat.n(s.lifetime_points)) pontos")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RWColor.rowExpiry)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rwBrutalCard()
        .padding(.bottom, 4)
    }

    private func tiers(_ s: CardStateDTO) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            RWGroupLabel(text: "Níveis")
            ForEach(s.tiers) { t in
                HStack(spacing: 12) {
                    Circle()
                        .fill(t.key == s.tier.key ? RWColor.neon : RWColor.chipBorder)
                        .frame(width: 12, height: 12)
                    Text(t.label)
                        .font(.system(size: 14, weight: t.key == s.tier.key ? .bold : .semibold))
                        .foregroundStyle(RWColor.ink)
                    Spacer()
                    Text("\(RWFormat.n(t.min_points)) pts")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RWColor.chipPts)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .rwBrutalCard()
            }
        }
    }

    private func load() async {
        loading = true; failed = false
        defer { loading = false }
        do {
            state = try await backend.card()
        } catch {
            failed = true
        }
    }
}

// MARK: - Campanhas

struct RWCampaignsView: View {
    @Environment(RewardsBackend.self) private var backend
    var onBack: () -> Void

    @State private var items: [CampaignDTO] = []
    @State private var loading = true
    @State private var failed = false
    @State private var joining: String?
    @State private var error: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 9) {
                RWScreenHeader(title: "Campanhas", onBack: onBack)

                if let error { RWSheetError(message: error) }

                if loading {
                    RWListState(kind: .loading, message: "Carregando campanhas…")
                } else if failed {
                    RWListState(kind: .failed, message: "Não foi possível carregar as campanhas.")
                } else if items.isEmpty {
                    RWListState(kind: .empty, message: "Nenhuma campanha ativa no momento.")
                } else {
                    ForEach(items) { c in card(c) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .task { await load() }
    }

    private func card(_ c: CampaignDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(c.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RWColor.ink)
                Spacer(minLength: 10)
                Text("+\(RWFormat.n(c.reward_pts)) pts")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(RWColor.ink)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(RWColor.neon)
                    .clipShape(Capsule())
            }
            if let d = c.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: 13))
                    .foregroundStyle(RWColor.breakdownK)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if c.isJoined {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(RWColor.pctBg)
                        RoundedRectangle(cornerRadius: 8).fill(RWColor.neon)
                            .frame(width: geo.size.width * CGFloat(min(100, max(0, c.progressPct))) / 100)
                    }
                }
                .frame(height: 10)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(RWColor.ink, lineWidth: 2))
                Text(c.isCompleted
                     ? "Concluída — recompensa creditada."
                     : "\(c.progressPct)% de R$ \(RWFormat.n(c.target_brl))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(c.isCompleted ? RWColor.bonus : RWColor.rowExpiry)
            } else {
                RWCTA(title: joining == c.id ? "Entrando…" : "Participar",
                      ghost: true, disabled: joining != nil) {
                    Task { await join(c) }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rwBrutalCard()
    }

    private func load() async {
        loading = true; failed = false
        defer { loading = false }
        do {
            items = try await backend.campaigns()
        } catch {
            failed = true
        }
    }

    private func join(_ c: CampaignDTO) async {
        joining = c.id; error = nil
        defer { joining = nil }
        do {
            try await backend.joinCampaign(c.id)
            await load()
        } catch let e as APIError {
            error = e.message
        } catch {
            self.error = "Não foi possível entrar na campanha."
        }
    }
}

// MARK: - Resgatar com pontos (benefícios + vouchers)

struct RWBenefitsView: View {
    @Environment(RewardsBackend.self) private var backend
    var onBack: () -> Void

    private enum Aba: String, CaseIterable { case catalogo = "Catálogo", meus = "Meus vouchers" }

    @State private var aba: Aba = .catalogo
    @State private var benefits: [BenefitDTO] = []
    @State private var vouchers: [VoucherDTO] = []
    @State private var loading = true
    @State private var failed = false
    @State private var redeeming: String?
    @State private var error: String?
    @State private var lastVoucher: VoucherDTO?

    private var saldo: Int { backend.balancePts ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                RWScreenHeader(title: "Resgatar com pontos", onBack: onBack)
                HStack(spacing: 8) {
                    ForEach(Aba.allCases, id: \.rawValue) { a in
                        let on = aba == a
                        Button { aba = a } label: {
                            Text(a.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(on ? RWColor.ink : RWColor.segFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(on ? RWColor.neon : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(RWColor.ink, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 9) {
                    if let error { RWSheetError(message: error) }
                    if let v = lastVoucher {
                        voucherHighlight(v)
                    }
                    if loading {
                        RWListState(kind: .loading, message: "Carregando…")
                    } else if failed {
                        RWListState(kind: .failed, message: "Não foi possível carregar o catálogo.")
                    } else if aba == .catalogo {
                        if benefits.isEmpty {
                            RWListState(kind: .empty, message: "Nenhum benefício disponível agora.")
                        } else {
                            ForEach(benefits) { b in benefitCard(b) }
                        }
                    } else {
                        if vouchers.isEmpty {
                            RWListState(kind: .empty, message: "Você ainda não resgatou nenhum benefício.")
                        } else {
                            ForEach(vouchers) { v in voucherCard(v) }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .task { await load() }
    }

    private func benefitCard(_ b: BenefitDTO) -> some View {
        let pode = saldo >= b.cost_pts && b.stock > 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                Text(b.image_emoji ?? "🎁")
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .background(RWColor.pctBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(b.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                    if let p = b.partner_name {
                        Text(p)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RWColor.chipPts)
                    }
                }
                Spacer(minLength: 6)
                Text("\(RWFormat.n(b.cost_pts)) pts")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(pode ? RWColor.ink : RWColor.muted)
            }
            if let d = b.description, !d.isEmpty {
                Text(d)
                    .font(.system(size: 13))
                    .foregroundStyle(RWColor.breakdownK)
                    .fixedSize(horizontal: false, vertical: true)
            }
            RWCTA(title: redeeming == b.id ? "Resgatando…"
                  : (b.stock <= 0 ? "Esgotado" : (pode ? "Resgatar" : "Saldo insuficiente")),
                  ghost: true, disabled: !pode || redeeming != nil) {
                Task { await redeem(b) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rwBrutalCard()
    }

    private func voucherCard(_ v: VoucherDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(v.benefit_name ?? "Benefício")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RWColor.ink)
            Text(v.code)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(RWColor.greenLight)
            HStack(spacing: 8) {
                Text(statusLabel(v.status))
                if let d = RWDate.parse(v.expires_at) {
                    Text("· vence em \(RWDate.short(d))")
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(RWColor.rowExpiry)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rwBrutalCard()
    }

    private func voucherHighlight(_ v: VoucherDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resgatado!")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(RWColor.neon)
            Text(v.code)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RWColor.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .rwCardShadow()
    }

    private func statusLabel(_ s: String) -> String {
        switch s.lowercased() {
        case "active": return "ativo"
        case "used": return "usado"
        case "expired": return "expirado"
        default: return s
        }
    }

    private func load() async {
        loading = true; failed = false
        defer { loading = false }
        async let b = try? await backend.benefits()
        async let v = try? await backend.vouchers()
        let (bb, vv) = await (b, v)
        if bb == nil && vv == nil { failed = true }
        benefits = bb ?? []
        vouchers = vv ?? []
    }

    private func redeem(_ b: BenefitDTO) async {
        redeeming = b.id; error = nil
        defer { redeeming = nil }
        do {
            let v = try await backend.redeemBenefit(b.id)
            lastVoucher = v
            await backend.refresh()
            await load()
        } catch let e as APIError {
            error = e.message
        } catch {
            self.error = "Não foi possível resgatar."
        }
    }
}
