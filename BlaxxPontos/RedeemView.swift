//
//  RedeemView.swift
//  BlaxxPontos
//
//  Fluxo 3: Resgatar pontos via PIX.
//
//  ⚠️ CÓDIGO MORTO — alcançável só por `ContentView.legacyBody`, que ninguém
//  chama. A tela viva de resgate é `Rewards/RewardsFinanceSheets.swift`
//  (`RewardsSellSheet`). Corrigir aqui não chega ao app. Ver ContentView.swift.
//

import SwiftUI

struct RedeemView: View {
    @Environment(Session.self) private var session

    @State private var pointsText = ""
    @State private var quote: RedeemQuoteDTO?
    @State private var pixKey = ""
    @State private var password = ""
    @State private var step: Step = .form
    @State private var result: RedeemResponse?
    @State private var error: String?

    enum Step { case form, confirm, done }

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 28) {
                    if !isCompact {
                        Topbar(eyebrow: "Resgate", title: "Resgatar pontos",
                               userName: session.user?.name ?? "?")
                    }
                    switch step {
                    case .form: formView
                    case .confirm: confirmView
                    case .done: resultView
                    }
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Resgatar" : "")
            .blaxxBrandNavBar()
        }
    }

    private var formView: some View {
        AdaptiveStack(spacing: 16) {
            BlaxxCard {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Cashback via PIX")
                    Text("Resgatar pontos")
                        .font(BlaxxFont.display(22))
                    Text("1 pt = R$ 0,09 · disponível após 6 meses · VIPs sem limite diário.")
                        .font(.system(size: 13))
                        .foregroundStyle(BlaxxColor.gray600)

                    BlaxxField(label: "Quantos pontos resgatar?",
                               value: $pointsText,
                               placeholder: "1000",
                               hint: quote.map { "Equivalente a \(formatBRL($0.amount_brl)) · \($0.rate)" }
                                   ?? "mínimo 1 pt · máx R$ 100.000/dia (= 1.111.111 pts)")
                        .onChange(of: pointsText) { _, new in
                            Task { await updateQuote(new) }
                        }

                    if let error {
                        Text(error).font(.system(size: 12)).foregroundStyle(BlaxxColor.negative)
                    }
                    Button("Continuar") {
                        guard let n = Int(pointsText), n >= 1, n <= 1_111_111 else {
                            error = "Valor inválido. Use entre 1 e 1.111.111 pts."
                            return
                        }
                        error = nil
                        step = .confirm
                    }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                }
            }

            BlaxxCard(variant: .lime) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Como funciona")
                    Text("Resgate seguro")
                        .font(BlaxxFont.display(18))
                        .foregroundStyle(BlaxxColor.black)
                    Text("Em produção validamos sua chave PIX via DICT do Banco Central e confirmamos que o titular é você. Se o payout falhar, os pontos voltam à carteira automaticamente.")
                        .font(.system(size: 13))
                        .foregroundStyle(BlaxxColor.gray800)
                    Divider()
                    Eyebrow(text: "Limites")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Conversão: 1 pt = R$ 0,09")
                        Text("• Máximo diário: R$ 100.000 (= 1.111.111 pts)")
                        Text("• Usuários VIP: sem limite diário")
                        Text("• Carência: 6 meses após cadastro")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(BlaxxColor.gray800)
                }
            }
        }
    }

    private var confirmView: some View {
        VStack {
            BlaxxCard {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Chave PIX")
                    Text("Para qual chave enviar?")
                        .font(BlaxxFont.display(20))
                    Text("Em produção a chave precisa pertencer ao mesmo CPF do cadastro.")
                        .font(.system(size: 13))
                        .foregroundStyle(BlaxxColor.gray600)

                    BlaxxField(label: "Chave PIX (e-mail, CPF, telefone, aleatória)",
                               value: $pixKey,
                               placeholder: "seu@email.com")
                    BlaxxField(label: "Senha", value: $password,
                               placeholder: "••••••", isSecure: true)

                    if let quote {
                        BlaxxCard(variant: .lime) {
                            VStack(alignment: .leading, spacing: 6) {
                                row("Pontos", "\(quote.points) pts")
                                row("Você recebe", formatBRL(quote.amount_brl))
                                row("Cotação", quote.rate)
                            }
                        }
                    }

                    if let error {
                        Text(error).font(.system(size: 12)).foregroundStyle(BlaxxColor.negative)
                    }
                    Button("Solicitar resgate") {
                        Task { await submit() }
                    }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                    Button("Voltar") { step = .form }
                        .buttonStyle(GhostButtonStyle(fullWidth: true))
                }
            }
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            if result?.status == "failed" {
                SuccessTick(color: BlaxxColor.warning, icon: "arrow.uturn.backward")
                Eyebrow(text: "Estorno automático")
                Text("Payout falhou")
                    .font(BlaxxFont.display(28))
                Text("Os pontos foram devolvidos à sua carteira (REFUND).")
                    .foregroundStyle(BlaxxColor.gray600)
            } else if result?.status == "processing" {
                // PAYOUT_MODE=manual (produção sem provider de payout real):
                // débito retido, PIX sai em até 1 dia útil. Sem "PIX enviado!".
                SuccessTick(color: BlaxxColor.warning, icon: "clock")
                Eyebrow(text: "Em processamento")
                Text("Resgate em processamento")
                    .font(BlaxxFont.display(28))
                Text("Seu PIX será transferido em até 1 dia útil. Acompanhe no extrato.")
                    .foregroundStyle(BlaxxColor.gray600)
            } else {
                SuccessTick()
                Eyebrow(text: "Resgate aprovado")
                Text("PIX enviado!")
                    .font(BlaxxFont.display(28))
                Text("Recurso disponível na sua conta em até 30 segundos.")
                    .foregroundStyle(BlaxxColor.gray600)
            }
            if let r = result {
                BlaxxCard(variant: .lime) {
                    VStack(alignment: .leading, spacing: 8) {
                        row("Valor", formatBRL(r.amount_brl))
                        row("Pontos debitados", "\(r.points_debited) pts")
                        row("End-to-End ID", r.end_to_end_id ?? "—")
                        HStack {
                            Text("Status").foregroundStyle(BlaxxColor.gray600).font(.system(size: 13))
                            Spacer()
                            Chip(text: r.status, variant: r.status == "failed" ? .danger : .success)
                        }
                    }
                }
                .frame(maxWidth: 420)
            }
            Button("Fazer outro resgate") {
                pointsText = ""; pixKey = ""; password = ""
                quote = nil; result = nil
                step = .form
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(BlaxxColor.gray600).font(.system(size: 13))
            Spacer()
            Text(v).font(.system(size: 14, weight: .semibold))
        }
    }

    private func updateQuote(_ s: String) async {
        guard let n = Int(s), n >= 2_500 else { quote = nil; return }
        do {
            quote = try await BlaxxAPI.shared.redeemQuote(points: n)
        } catch {
            quote = nil
        }
    }

    private func submit() async {
        guard let n = Int(pointsText), !pixKey.isEmpty, !password.isEmpty else {
            error = "Preencha chave PIX e senha"
            return
        }
        do {
            let r = try await BlaxxAPI.shared.redeem(points: n, pixKey: pixKey, password: password)
            result = r
            step = .done
            // Resgate cria Transaction REDEEM (e REFUND se falhar) — notifica
            // Dashboard/Carteira/Extrato para recarregarem do backend.
            session.bumpWalletReload()
        } catch let e {
            self.error = (e as? APIError)?.message ?? e.localizedDescription
        }
    }

    private func formatBRL(_ v: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale(identifier: "pt_BR")
        return nf.string(from: NSNumber(value: v)) ?? "R$ \(v)"
    }
}
