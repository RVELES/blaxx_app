//
//  BenefitsView.swift
//  BlaxxPontos
//
//  Marketplace de benefícios. Tabs: "Disponíveis" e "Meus vouchers".
//

import SwiftUI

struct BenefitsView: View {
    @Environment(Session.self) private var session
    @State private var benefits: [BenefitDTO] = []
    @State private var vouchers: [VoucherDTO] = []
    @State private var tab = 0       // 0 = disponíveis, 1 = meus vouchers
    @State private var loading = false
    @State private var redeemed: VoucherDTO?

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 24) {
                    if !isCompact {
                        Topbar(eyebrow: "Resgates", title: "Benefícios",
                               userName: session.user?.name ?? "?")
                    }

                    Picker("", selection: $tab) {
                        Text("Disponíveis").tag(0)
                        Text("Meus vouchers").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)

                    if loading {
                        ProgressView().padding()
                    } else if tab == 0 {
                        catalog(isCompact: isCompact)
                    } else {
                        myVouchersList(isCompact: isCompact)
                    }
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Benefícios" : "")
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $redeemed) { v in
                VoucherSheet(voucher: v).environment(session)
            }
        }
    }

    private func catalog(isCompact: Bool) -> some View {
        Group {
            if benefits.isEmpty {
                Text("Nenhum benefício disponível.")
                    .foregroundStyle(BlaxxColor.gray400)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: isCompact ? 160 : 240), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(benefits) { b in
                        benefitCard(b)
                    }
                }
            }
        }
    }

    private func benefitCard(_ b: BenefitDTO) -> some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 8) {
                if let tag = b.tag, !tag.isEmpty {
                    Chip(text: tag, variant: .success)
                }
                Text(b.image_emoji ?? "★").font(.system(size: 32))
                Text(b.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BlaxxColor.black)
                if let partner = b.partner_name {
                    Text(partner)
                        .font(.system(size: 11))
                        .foregroundStyle(BlaxxColor.gray400)
                }
                if let desc = b.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(BlaxxColor.gray600)
                        .lineLimit(2)
                }
                HStack {
                    Text(formatPts(b.cost_pts))
                        .font(BlaxxFont.display(18))
                        .foregroundStyle(BlaxxColor.black)
                    + Text(" pts")
                        .font(.system(size: 11))
                        .foregroundStyle(BlaxxColor.gray600)
                    Spacer()
                    Button("Resgatar") {
                        Task { await redeem(b) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.top, 4)
            }
        }
    }

    private func myVouchersList(isCompact: Bool) -> some View {
        Group {
            if vouchers.isEmpty {
                BlaxxCard {
                    Text("Você ainda não tem vouchers. Resgate um benefício para começar.")
                        .foregroundStyle(BlaxxColor.gray400)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(vouchers) { v in
                        Button {
                            redeemed = v
                        } label: {
                            voucherRow(v)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func voucherRow(_ v: VoucherDTO) -> some View {
        BlaxxCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(v.benefit_name ?? "Voucher Blaxx")
                        .font(.system(size: 14, weight: .semibold))
                    Text(v.code)
                        .font(BlaxxFont.mono(11))
                        .foregroundStyle(BlaxxColor.gray600)
                    Text("Vale até \(shortDate(v.expires_at))")
                        .font(.system(size: 11))
                        .foregroundStyle(BlaxxColor.gray400)
                }
                Spacer()
                statusChip(v.status)
            }
        }
    }

    private func statusChip(_ s: String) -> some View {
        let variant: Chip.Variant = switch s {
        case "active":  .success
        case "used":    .neutral
        case "expired": .danger
        default:        .neutral
        }
        return Chip(text: s, variant: variant)
    }

    private func shortDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "pt_BR")
            fmt.dateStyle = .short
            return fmt.string(from: d)
        }
        return iso.prefix(10).description
    }

    private func formatPts(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func load() async {
        loading = true; defer { loading = false }
        do {
            async let b = BlaxxAPI.shared.benefits()
            async let v = BlaxxAPI.shared.myVouchers()
            benefits = try await b
            vouchers = try await v
        } catch { /* silencioso */ }
    }

    private func redeem(_ b: BenefitDTO) async {
        do {
            let v = try await BlaxxAPI.shared.redeemBenefit(b.id)
            redeemed = v
            await load()
            // Resgate de voucher debita pontos no ledger — atualiza
            // dashboard/carteira/extrato.
            session.bumpWalletReload()
        } catch {
            // mostraria erro num toast — versão simples ignora
        }
    }
}

/// Sheet apresentado após resgate.
struct VoucherSheet: View {
    let voucher: VoucherDTO
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BlaxxColor.gray50.ignoresSafeArea()
            VStack(spacing: 16) {
                SuccessTick()
                Eyebrow(text: "Voucher emitido")
                Text(voucher.benefit_name ?? "Voucher Blaxx")
                    .font(BlaxxFont.display(22))
                BlaxxCard(variant: .lime) {
                    VStack(spacing: 6) {
                        Eyebrow(text: "Código", color: BlaxxColor.gray600)
                        Text(voucher.code)
                            .font(BlaxxFont.mono(20))
                            .foregroundStyle(BlaxxColor.black)
                            .padding(.vertical, 4)
                        Text("Apresente no parceiro · Vale até \(shortDate)")
                            .font(.system(size: 11))
                            .foregroundStyle(BlaxxColor.gray600)
                    }
                }
                .frame(maxWidth: 380)
                Button("Copiar código") {
                    copyToClipboard(voucher.code)
                }
                .buttonStyle(DarkButtonStyle())
                Button("Fechar") { dismiss() }
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(30)
        }
    }

    private var shortDate: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: voucher.expires_at) {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "pt_BR")
            fmt.dateStyle = .medium
            return fmt.string(from: d)
        }
        return voucher.expires_at.prefix(10).description
    }
}

#Preview { BenefitsView().environment(Session()) }
