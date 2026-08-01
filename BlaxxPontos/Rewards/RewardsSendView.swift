//
//  RewardsSendView.swift
//  BlaxxPontos
//
//  Enviar pontos screen — 4 steps (recipient → amount → review → success).
//  Ports the JS send flow; source balance decreases on confirm.
//

import SwiftUI

struct RewardsSendView: View {
    @Environment(RewardsStore.self) private var store
    /// Bumped by the shell to reset the flow whenever the tab is (re)entered.
    var resetToken: Int

    @State private var step = 0
    @State private var contactIdx = 0
    @State private var fromIdx = 0
    @State private var amount: Double = 0
    @State private var msg = ""
    @State private var sentAmt = ""
    @State private var sentName = ""

    private var from: RWProgram { store.programs[fromIdx] }
    private var clampedAmount: Double { min(amount, from.balance) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                switch step {
                case 0: recipientStep
                case 1: amountStep
                case 2: reviewStep
                default: successStep
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 18)
        }
        .onChange(of: resetToken) { _, _ in reset() }
    }

    private func reset() {
        step = 0; contactIdx = 0; fromIdx = 0; amount = 0; msg = ""
    }

    // MARK: Step 0 — recipient

    private var recipientStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Enviar pontos")
                .font(BlaxxFont.display(24, weight: .bold))
                .foregroundStyle(RWColor.ink)
                .padding(.bottom, 18)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 18)).foregroundStyle(RWColor.fieldLabel)
                Text("Nome, e-mail ou @usuário")
                    .font(.system(size: 15)).foregroundStyle(RWColor.fieldLabel)
                Spacer()
            }
            .padding(.init(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(RWColor.searchBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.bottom, 18)

            RWFieldLabel(text: "Contatos recentes").padding(.bottom, 9)

            VStack(spacing: 0) {
                ForEach(Array(store.contacts.enumerated()), id: \.element.id) { i, c in
                    Button {
                        contactIdx = i
                        withAnimation { step = 1 }
                    } label: {
                        contactRow(c, selected: false)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {} label: {
                HStack(spacing: 13) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 22))
                        .foregroundStyle(RWColor.greenLight)
                        .frame(width: 46, height: 46)
                        .background(RWColor.chipSelBg)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enviar por link / QR").font(.system(size: 15, weight: .bold)).foregroundStyle(RWColor.ink)
                        Text("Para quem ainda não está nos seus contatos")
                            .font(.system(size: 11)).foregroundStyle(RWColor.rowExpiry)
                    }
                    Spacer()
                }
                .padding(.init(top: 13, leading: 15, bottom: 13, trailing: 15))
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .rwCardShadow()
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }

    private func contactRow(_ c: RWContact, selected: Bool) -> some View {
        HStack(spacing: 13) {
            Text(c.initial)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(c.color)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(c.name).font(.system(size: 15, weight: .bold)).foregroundStyle(RWColor.ink)
                Text(c.handle).font(.system(size: 12)).foregroundStyle(RWColor.chipPts)
            }
            Spacer()
        }
        .padding(.vertical, 11)
        .padding(.horizontal, selected ? 12 : 4)
        .background(selected ? RWColor.chipSelBg : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Step 1 — amount

    private var amountStep: some View {
        let c = store.contacts[contactIdx]
        return VStack(alignment: .leading, spacing: 0) {
            RWBackHeader(title: "Valor do envio") { withAnimation { step = 0 } }
            contactRow(c, selected: true).padding(.bottom, 18)

            RWFieldLabel(text: "De qual programa").padding(.bottom, 9)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(store.programs.enumerated()), id: \.element.id) { i, p in
                        RWProgramChip(program: p, selected: i == fromIdx) {
                            fromIdx = i
                            amount = min(amount, store.programs[i].balance)
                        }
                    }
                }
            }
            .padding(.bottom, 18)

            HStack(alignment: .firstTextBaseline) {
                RWFieldLabel(text: "Quanto enviar")
                Spacer()
                Text("disp. \(RWFormat.n(from.balance))")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(RWColor.chipPts)
            }
            .padding(.bottom, 6)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(RWFormat.n(clampedAmount)).font(BlaxxFont.display(30, weight: .bold)).foregroundStyle(RWColor.ink)
                Text(from.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(RWColor.muted)
            }
            RWSlider(value: Binding(
                get: { amount },
                set: { amount = max(0, min($0, from.balance)) }),
                     range: 0...max(1, from.balance))
            RWPctRow { pct in amount = (from.balance * pct).rounded() }

            RWFieldLabel(text: "Mensagem (opcional)").padding(.top, 20).padding(.bottom, 6)
            TextField("Escreva uma mensagem...", text: $msg, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 14))
                .padding(.init(top: 13, leading: 14, bottom: 13, trailing: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(RWColor.chipBorder, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 0) {
                Text("Destinatário recebe").font(.system(size: 12)).foregroundStyle(RWColor.heroSub)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(RWFormat.n(clampedAmount)).font(BlaxxFont.display(30, weight: .bold)).foregroundStyle(RWColor.neon)
                    Text(from.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: 0xCFD3CB))
                }
                .padding(.top, 2)
                HStack {
                    Text("Transferência entre usuários").font(.system(size: 12)).foregroundStyle(RWColor.heroSub)
                    Spacer()
                    Text("Sem taxa").font(.system(size: 12, weight: .bold)).foregroundStyle(RWColor.neon)
                }
                .padding(.top, 12)
            }
            .padding(18)
            .background(RWColor.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.vertical, 18)

            RWCTA(title: "Continuar", disabled: clampedAmount <= 0) {
                if clampedAmount > 0 { withAnimation { step = 2 } }
            }
        }
    }

    // MARK: Step 2 — review

    private var reviewStep: some View {
        let c = store.contacts[contactIdx]
        return VStack(alignment: .leading, spacing: 0) {
            RWBackHeader(title: "Revisar envio") { withAnimation { step = 1 } }
            RWSwapCard(leftKey: "Você envia", leftVal: RWFormat.n(clampedAmount), leftSub: from.name,
                       rightKey: "Para", rightVal: c.name, rightSub: c.handle)
                .padding(.bottom, 14)
            VStack(spacing: 0) {
                RWBreakdownRow(key: "Destinatário recebe", value: "\(RWFormat.n(clampedAmount)) \(from.name)")
                RWBreakdownRow(key: "Taxa de serviço", value: "Grátis")
                RWBreakdownRow(key: "Mensagem", value: msg.isEmpty ? "—" : "“\(msg)”", last: true)
            }
            .padding(.horizontal, 16)
            .background(.white)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0xEEF0EA), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.bottom, 16)

            HStack(spacing: 10) {
                Image(systemName: "faceid").font(.system(size: 16))
                Text("Confirme com Face ID para enviar").font(.system(size: 12))
            }
            .foregroundStyle(RWColor.rowBrl)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)

            RWCTA(title: "Enviar agora") { confirm() }
        }
    }

    // MARK: Step 3 — success

    private var successStep: some View {
        VStack(spacing: 0) {
            RWSuccessBadge().padding(.bottom, 22)
            Text("Pontos enviados!")
                .font(BlaxxFont.display(24, weight: .bold)).foregroundStyle(RWColor.ink)
            (Text("Você enviou ").foregroundColor(RWColor.breakdownK)
             + Text(sentAmt).foregroundColor(RWColor.ink).bold()
             + Text("\npara ").foregroundColor(RWColor.breakdownK)
             + Text(sentName).foregroundColor(RWColor.ink).bold())
                .font(.system(size: 14)).multilineTextAlignment(.center).padding(.top, 8)
            Text("A transferência foi concluída na hora.")
                .font(.system(size: 12)).foregroundStyle(RWColor.chipPts).padding(.top, 14)
            RWCTA(title: "Concluir") { reset() }.padding(.top, 26)
            RWCTA(title: "Ver comprovante", ghost: true) { reset() }.padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func confirm() {
        let c = store.contacts[contactIdx]
        sentAmt = "\(RWFormat.n(clampedAmount)) \(from.name)"
        sentName = c.name
        store.applySend(fromIdx: fromIdx, amount: clampedAmount)
        withAnimation { step = 3 }
    }
}
