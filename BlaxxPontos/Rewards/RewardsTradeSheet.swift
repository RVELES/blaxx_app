//
//  RewardsTradeSheet.swift
//  BlaxxPontos
//
//  Trade flow (3 steps) — ports the JS trade logic exactly.
//

import SwiftUI

/// Parameters used when the trade sheet is opened from elsewhere (FAB, offer,
/// program detail). Mirrors how the JS seeds S.trade before openTrade().
struct RWTradeConfig {
    var fromIdx: Int = 0
    var toIdx: Int = 3
    var amount: Double = 120000
    var bonusRate: Double = 0.08
    var bonusLabel: String = "+8% bônus"
}

struct RewardsTradeSheet: View {
    @Environment(RewardsStore.self) private var store
    let config: RWTradeConfig
    var onClose: () -> Void

    @State private var step = 0
    @State private var fromIdx = 0
    @State private var toIdx = 3
    @State private var amount: Double = 0
    @State private var bonusRate = 0.08
    @State private var bonusLabel = "+8% bônus"

    private var calc: RWTradeCalc {
        RWTradeCalc(from: store.programs[fromIdx], to: store.programs[toIdx],
                    requestedAmount: amount, bonusRate: bonusRate)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                RWGrabber()
                switch step {
                case 0: configStep
                case 1: reviewStep
                default: successStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .onAppear {
            fromIdx = config.fromIdx
            toIdx = config.toIdx
            bonusRate = config.bonusRate
            bonusLabel = config.bonusLabel
            amount = min(config.amount, store.programs[config.fromIdx].balance)
        }
    }

    // MARK: Step 0 — configure

    private var configStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            RWSheetHeader(title: "Trocar pontos", onClose: onClose)

            RWFieldLabel(text: "De")
            chipRow(selectedIdx: fromIdx) { i in setFrom(i) }
                .padding(.top, 9)

            Button { swap() } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(RWColor.neon)
                    .frame(width: 40, height: 40)
                    .background(RWColor.ink2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            RWFieldLabel(text: "Para")
            chipRow(selectedIdx: toIdx) { i in setTo(i) }
                .padding(.top, 9)
                .padding(.bottom, 20)

            amountBlock(label: "Quanto trocar",
                        avail: calc.from.balance,
                        amt: calc.amount,
                        progName: calc.from.name)

            RWReceiveCard(total: RWFormat.n(calc.total),
                          toName: calc.to.name,
                          rateText: calc.rateLabel,
                          bonusLabel: bonusLabel)
                .padding(.vertical, 16)

            RWCTA(title: "Revisar troca") { withAnimation(.easeIn(duration: 0.25)) { step = 1 } }
        }
    }

    // MARK: Step 1 — review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            RWBackHeader(title: "Revisar troca") { withAnimation { step = 0 } }
            RWSwapCard(leftKey: "De", leftVal: RWFormat.n(calc.amount), leftSub: calc.from.name,
                       rightKey: "Para", rightVal: RWFormat.n(calc.total), rightSub: calc.to.name)
                .padding(.bottom, 14)
            VStack(spacing: 0) {
                RWBreakdownRow(key: "Taxa de conversão", value: calc.rateLabel)
                RWBreakdownRow(key: "Bônus BlaXx", value: "+\(RWFormat.n(calc.bonus))", green: true)
                RWBreakdownRow(key: "Taxa de serviço", value: "Grátis", last: true)
            }
            .padding(.horizontal, 16)
            .background(.white)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0xEEF0EA), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.bottom, 22)
            RWCTA(title: "Confirmar troca") { confirm() }
        }
    }

    // MARK: Step 2 — success

    private var successStep: some View {
        VStack(spacing: 0) {
            RWSuccessBadge().padding(.bottom, 22)
            Text("Troca concluída!")
                .font(BlaxxFont.display(24, weight: .bold))
                .foregroundStyle(RWColor.ink)
            (Text("Você trocou ").foregroundColor(RWColor.breakdownK)
             + Text(successAmt).foregroundColor(RWColor.ink).bold()
             + Text("\npor ").foregroundColor(RWColor.breakdownK)
             + Text(successTotal).foregroundColor(RWColor.ink).bold())
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Text("Os pontos já estão na sua carteira BlaXx.")
                .font(.system(size: 12))
                .foregroundStyle(RWColor.chipPts)
                .padding(.top, 14)
            RWCTA(title: "Concluir") { onClose() }
                .padding(.top, 26)
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
    }

    // MARK: snapshots for the success copy (frozen at confirm)
    @State private var successAmt = ""
    @State private var successTotal = ""

    // MARK: Shared amount block

    private func amountBlock(label: String, avail: Double, amt: Double, progName: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 12, weight: .bold)).tracking(0.6).textCase(.uppercase)
                    .foregroundStyle(RWColor.fieldLabel)
                Spacer()
                Text("disp. \(RWFormat.n(avail))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RWColor.chipPts)
            }
            .padding(.bottom, 6)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(RWFormat.n(amt))
                    .font(BlaxxFont.display(30, weight: .bold))
                    .foregroundStyle(RWColor.ink)
                Text(progName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RWColor.muted)
            }
            RWSlider(value: Binding(
                get: { amount },
                set: { amount = max(0, min($0, store.programs[fromIdx].balance)) }),
                     range: 0...max(1, store.programs[fromIdx].balance))
            RWPctRow { pct in
                amount = (store.programs[fromIdx].balance * pct).rounded()
            }
        }
    }

    private func chipRow(selectedIdx: Int, pick: @escaping (Int) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(store.programs.enumerated()), id: \.element.id) { i, p in
                    RWProgramChip(program: p, selected: i == selectedIdx) { pick(i) }
                }
            }
        }
    }

    // MARK: Logic (ports JS exactly)

    private func setFrom(_ i: Int) {
        if i == toIdx { toIdx = fromIdx }
        fromIdx = i
        amount = min(amount, store.programs[i].balance)
    }
    private func setTo(_ i: Int) {
        if i == fromIdx { fromIdx = toIdx }
        toIdx = i
    }
    private func swap() {
        let t = fromIdx; fromIdx = toIdx; toIdx = t
        amount = min(amount, store.programs[fromIdx].balance)
    }
    private func confirm() {
        let c = calc
        successAmt = "\(RWFormat.n(c.amount)) \(c.from.name)"
        successTotal = "\(RWFormat.n(c.total)) \(c.to.name)"
        store.applyTrade(fromIdx: fromIdx, toIdx: toIdx, amount: c.amount, total: c.total)
        withAnimation { step = 2 }
    }
}

// MARK: - Swap summary card (De → Para)

struct RWSwapCard: View {
    let leftKey: String, leftVal: String, leftSub: String
    let rightKey: String, rightVal: String, rightSub: String

    var body: some View {
        HStack {
            col(leftKey, leftVal, leftSub)
            Image(systemName: "arrow.right")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(RWColor.neonB)
            col(rightKey, rightVal, rightSub)
        }
        .padding(18)
        .background(RWColor.simBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    private func col(_ k: String, _ v: String, _ s: String) -> some View {
        VStack(spacing: 5) {
            Text(k).font(.system(size: 11, weight: .semibold)).tracking(0.4)
                .textCase(.uppercase).foregroundStyle(RWColor.muted)
            Text(v).font(BlaxxFont.display(18, weight: .bold)).foregroundStyle(RWColor.ink)
            Text(s).font(.system(size: 12, weight: .semibold)).foregroundStyle(RWColor.breakdownK)
        }
        .frame(maxWidth: .infinity)
    }
}
