//
//  RewardsProgramSheet.swift
//  BlaxxPontos
//
//  Program-detail sheet: logo + name + balance, "Trocar pontos da {prog}" and
//  the program's transaction history. Ports openProg().
//

import SwiftUI

struct RewardsProgramSheet: View {
    @Environment(RewardsStore.self) private var store
    let programId: String
    var onClose: () -> Void
    /// Opens trade with this program preselected as source.
    var onTrade: (String) -> Void

    private var p: RWProgram { store.program(id: programId) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                RWGrabber()

                HStack(spacing: 13) {
                    Text(p.logo)
                        .font(BlaxxFont.display(p.logo.count > 2 ? 11 : 18, weight: .black))
                        .foregroundStyle(p.fg)
                        .frame(width: 46, height: 46)
                        .background(p.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(RWColor.ink)
                        Text("\(RWFormat.n(p.balance)) pts · R$ \(RWFormat.n(p.brl))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RWColor.rowBrl)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(RWColor.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 18)

                RWCTA(title: "Trocar pontos da \(p.name)") { onTrade(programId) }
                    .padding(.bottom, 18)

                RWFieldLabel(text: "Histórico")
                    .padding(.bottom, 4)

                let txs = store.tx(for: programId)
                if txs.isEmpty {
                    Text("Sem movimentações recentes.")
                        .font(.system(size: 13))
                        .foregroundStyle(RWColor.chipPts)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(txs.enumerated()), id: \.element.id) { i, tx in
                        VStack(spacing: 0) {
                            HStack(spacing: 13) {
                                Image(systemName: tx.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(RWColor.ink)
                                    .frame(width: 40, height: 40)
                                    .background(RWColor.pctBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tx.t).font(.system(size: 14, weight: .bold)).foregroundStyle(RWColor.ink)
                                    Text(tx.d).font(.system(size: 11)).foregroundStyle(RWColor.chipPts)
                                }
                                Spacer()
                                Text(tx.pts)
                                    .font(BlaxxFont.display(15, weight: .bold))
                                    .foregroundStyle(tx.isIn ? RWColor.bonus : RWColor.ink)
                            }
                            .padding(.vertical, 12)
                            if i < txs.count - 1 {
                                Rectangle().fill(RWColor.txDivider).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
    }
}
