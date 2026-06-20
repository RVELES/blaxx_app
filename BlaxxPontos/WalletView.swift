//
//  WalletView.swift
//  BlaxxPontos
//

import SwiftUI

struct WalletView: View {
    @Environment(Session.self) private var session
    @Binding var selection: Tab

    @State private var balancePts = 0
    @State private var balanceBRL: Double = 0
    @State private var pending = 0
    @State private var txs: [TransactionDTO] = []
    @State private var loading = false

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 28) {
                    if !isCompact {
                        Topbar(eyebrow: "Sua carteira", title: "Carteira",
                               userName: session.user?.name ?? "?")
                    }

                    AdaptiveStack(spacing: 16) {
                        ZStack(alignment: .bottomLeading) {
                            BalanceCard(balancePts: balancePts, balanceBRL: balanceBRL)
                            HStack(spacing: 8) {
                                Button("Comprar") { selection = .buy }
                                    .buttonStyle(PrimaryButtonStyle())
                                Button("Enviar") { selection = .send }
                                    .buttonStyle(GhostButtonStyle(onDark: true))
                                Button("Resgatar") { selection = .redeem }
                                    .buttonStyle(GhostButtonStyle(onDark: true))
                            }
                            .padding(isCompact ? 18 : 28)
                        }
                        AdaptiveStack(spacing: 12) {
                            MetricCard(label: "Pontos pendentes",
                                       value: "+\(formatPts(pending))",
                                       subtitle: "cobranças aguardando")
                            MetricCard(label: "Validade próxima", value: "12 meses",
                                       subtitle: "consumo FIFO")
                        }
                    }

                    BlaxxCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Eyebrow(text: "Extrato")
                                    Text("Últimas movimentações")
                                        .font(BlaxxFont.display(isCompact ? 18 : 20))
                                }
                                Spacer()
                                Button("Ver tudo") { selection = .statement }
                                    .buttonStyle(GhostButtonStyle())
                            }
                            if loading && txs.isEmpty {
                                ProgressView().padding()
                            } else if txs.isEmpty {
                                Text("Nenhuma transação ainda.")
                                    .foregroundStyle(BlaxxColor.gray400)
                            } else {
                                ForEach(txs) { tx in
                                    TransactionRow(tx: tx)
                                    if tx.id != txs.last?.id { Divider() }
                                }
                            }
                        }
                    }
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Carteira" : "")
            // Recarrega quando compra/envio/resgate disparam o trigger.
            .task(id: session.walletReloadTrigger) { await load() }
            .refreshable { await load() }
        }
    }

    private func formatPts(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let w = try await BlaxxAPI.shared.wallet()
            balancePts = w.balance_pts
            balanceBRL = w.balance_brl_equiv
            pending = w.pending_pts
            txs = try await BlaxxAPI.shared.transactions(limit: 12)
        } catch is CancellationError {
            // Navegação rápida ou view desmontada — ignorar silenciosamente
        } catch {
            print("WalletView load: \(error)")
        }
    }
}
