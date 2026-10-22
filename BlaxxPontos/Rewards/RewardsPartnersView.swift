//
//  RewardsPartnersView.swift
//  BlaxxPontos
//
//  "Parceiros" — catalog of the loyalty programs you can exchange BlaXx points
//  with. Reuses the shared PROGRAMS data + atoms; "Trocar" opens the trade sheet
//  with that program pre-selected as the origin.
//

import SwiftUI

struct RewardsPartnersView: View {
    @Environment(RewardsStore.self) private var store
    var onTrade: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                VStack(spacing: 11) {
                    ForEach(store.programs) { p in
                        partnerCard(p)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Parceiros")
                .font(BlaxxFont.display(26, weight: .bold))
                .foregroundStyle(RWColor.ink)
            Text("Troque seus pontos BlaXx entre os principais programas de fidelidade.")
                .font(.system(size: 13))
                .foregroundStyle(RWColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: Card

    private func partnerCard(_ p: RWProgram) -> some View {
        HStack(spacing: 13) {
            RWProgramLogo(program: p, size: 52, corner: 16)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(p.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                    if p.bonus > 0 {
                        Text("+\(p.bonus)% bônus")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(RWColor.bonus)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RWColor.chipSelBg)
                            .clipShape(Capsule())
                    }
                }
                Text("\(RWFormat.n(p.balance)) pts · R$ \(RWFormat.n(p.brl))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RWColor.rowBrl)
            }
            Spacer(minLength: 8)
            Button { onTrade(p.id) } label: {
                Text("Trocar")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RWColor.neon)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(RWColor.ink2)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.init(top: 13, leading: 14, bottom: 13, trailing: 14))
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .rwCardShadow()
    }
}
