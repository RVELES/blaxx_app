#if BX_LEGADO_REWARDS   // desativado no redesenho Embarque de 22/10/2026. Não apagar sem decisão do dono (D14).
//
//  RewardsOfferSheet.swift
//  BlaxxPontos
//
//  Offer detail sheet with inline transfer simulator. Ports openOffer/offerSim.
//

import SwiftUI

struct RewardsOfferSheet: View {
    @Environment(RewardsStore.self) private var store
    let programId: String
    var onClose: () -> Void
    /// Called with the program id when user taps "Trocar com este bônus".
    var onTrade: (String, Double) -> Void

    @State private var simValue: Double = 100000

    private var p: RWProgram { store.program(id: programId) }
    private var maxFrom: Double { store.programs.map(\.balance).max() ?? 100000 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                RWGrabber()
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(RWColor.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)

                // Hero
                VStack(spacing: 0) {
                    Text(p.logo)
                        .font(BlaxxFont.display(p.logo.count > 2 ? 13 : 22, weight: .black))
                        .foregroundStyle(p.fg)
                        .frame(width: 64, height: 64)
                        .background(p.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Text("+\(p.bonus)%")
                        .font(BlaxxFont.display(40, weight: .bold))
                        .foregroundStyle(RWColor.greenLight)
                        .padding(.top, 12)
                    Text("Transfira para a \(p.name) com +\(p.bonus)% de bônus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.top, 2)
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 14, weight: .semibold))
                        Text("Termina em \(store.offerCountdown(programId))")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(RWColor.countdownFg)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .background(RWColor.countdownBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 14)
                }
                .padding(.vertical, 6)

                // How it works
                VStack(alignment: .leading, spacing: 12) {
                    how(1, "Escolha de qual programa sairão os pontos")
                    how(2, "Confirme a troca com o bônus aplicado")
                    how(3, "Receba os pontos em até 24h na conta de destino")
                }
                .padding(.vertical, 20)

                // Simulator
                VStack(alignment: .leading, spacing: 0) {
                    RWFieldLabel(text: "Simule sua transferência")
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(RWFormat.n(simValue))
                            .font(BlaxxFont.display(24, weight: .bold))
                            .foregroundStyle(RWColor.ink)
                        Text("pontos").font(.system(size: 15, weight: .semibold)).foregroundStyle(RWColor.muted)
                    }
                    .padding(.top, 8)
                    RWSlider(value: $simValue, range: 10000...max(10000, maxFrom), step: 5000)
                    HStack {
                        Text("Você recebe com bônus")
                            .font(.system(size: 13)).foregroundStyle(RWColor.breakdownK)
                        Spacer()
                        Text(RWFormat.n((simValue * (1 + Double(p.bonus) / 100)).rounded()))
                            .font(BlaxxFont.display(24, weight: .bold))
                            .foregroundStyle(RWColor.greenLight)
                    }
                }
                .padding(16)
                .background(RWColor.simBg)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.bottom, 8)

                Text("Bônus de \(p.bonus)% aplicado sobre o total transferido. Mínimo de 10.000 pontos por transferência. Pontos creditados em até 24h. Sujeito aos termos do programa parceiro.")
                    .font(.system(size: 11))
                    .foregroundStyle(RWColor.chipPts)
                    .lineSpacing(2)
                    .padding(.vertical, 14)

                RWCTA(title: "Trocar com este bônus") {
                    onTrade(programId, simValue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .onAppear { simValue = min(100000, maxFrom) }
    }

    private func how(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(RWColor.neon)
                .frame(width: 26, height: 26)
                .background(RWColor.ink2)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(RWColor.pctFg)
                .padding(.top, 2)
            Spacer(minLength: 0)
        }
    }
}

#endif
