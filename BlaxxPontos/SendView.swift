//
//  SendView.swift
//  BlaxxPontos
//
//  Fluxo 2: Enviar pontos a outro cliente (P2P).
//

import SwiftUI

struct SendView: View {
    @Environment(Session.self) private var session

    @State private var to = ""
    @State private var amount = ""
    @State private var message = ""
    @State private var password = ""
    @State private var step: Step = .form
    @State private var error: String?
    @State private var receipt: TransferResponse?

    enum Step { case form, confirm, done, insufficient }

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 28) {
                    if !isCompact {
                        Topbar(eyebrow: "Envio P2P", title: "Enviar pontos",
                               userName: session.user?.name ?? "?")
                    }

                    switch step {
                    case .form: formView
                    case .confirm: confirmView
                    case .done: doneView
                    case .insufficient: insufficientView
                    }
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Enviar" : "")
            .blaxxBrandNavBar()
        }
    }

    private var formView: some View {
        AdaptiveStack(spacing: 16) {
            BlaxxCard {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Presente para alguém")
                    Text("Enviar pontos")
                        .font(BlaxxFont.display(22))
                    Text("Mínimo 100 pts · máximo 50.000 pts por dia.")
                        .font(.system(size: 14))
                        .foregroundStyle(BlaxxColor.gray600)

                    BlaxxField(label: "Destinatário (e-mail ou CPF)",
                               value: $to,
                               placeholder: "lucas@blaxx.com ou 987.654.321-00")
                    BlaxxField(label: "Quantos pontos?",
                               value: $amount,
                               placeholder: "2000",
                               hint: "entre 100 e 50.000")
                    BlaxxField(label: "Mensagem (opcional)",
                               value: $message,
                               placeholder: "Obrigado!")
                    if let error {
                        Text(error).font(.system(size: 12)).foregroundStyle(BlaxxColor.negative)
                    }
                    Button("Continuar") {
                        guard let n = Int(amount), n >= 100, n <= 50_000 else {
                            error = "Valor inválido. Use entre 100 e 50.000 pts."
                            return
                        }
                        guard !to.isEmpty else {
                            error = "Informe o destinatário."
                            return
                        }
                        error = nil
                        step = .confirm
                    }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                    .padding(.top, 4)
                }
            }

            BlaxxCard(variant: .lime) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Como funciona")
                    Text("Transferência atômica")
                        .font(BlaxxFont.display(18))
                        .foregroundStyle(BlaxxColor.black)
                    Text("Numa única transação no ledger: ou os pontos saem de você e entram no destinatário simultaneamente, ou nada acontece.")
                        .font(.system(size: 13))
                        .foregroundStyle(BlaxxColor.gray800)
                    Divider()
                    Eyebrow(text: "Limites")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Mínimo: 100 pts")
                        Text("• Máximo: 50.000 pts/dia")
                        Text("• Validade preservada")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(BlaxxColor.gray800)
                }
            }
        }
    }

    private var confirmView: some View {
        VStack(alignment: .center, spacing: 16) {
            BlaxxCard {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Confirmação")
                    Text("Revise o envio")
                        .font(BlaxxFont.display(22))
                    BlaxxCard(variant: .lime) {
                        VStack(alignment: .leading, spacing: 8) {
                            row("Para", to)
                            row("Valor", "\(amount) pts")
                            if !message.isEmpty { row("Mensagem", "\"\(message)\"") }
                        }
                    }
                    BlaxxField(label: "Senha", value: $password,
                               placeholder: "••••••", isSecure: true)
                    if let error {
                        Text(error).font(.system(size: 12)).foregroundStyle(BlaxxColor.negative)
                    }
                    Button("Confirmar envio") {
                        Task { await submit() }
                    }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                    Button("Voltar") { step = .form }
                        .buttonStyle(GhostButtonStyle(fullWidth: true))
                }
            }
            .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity)
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            SuccessTick()
            Eyebrow(text: "Comprovante")
            Text("Pontos enviados!")
                .font(BlaxxFont.display(32))
            if let r = receipt {
                BlaxxCard(variant: .lime) {
                    VStack(alignment: .leading, spacing: 8) {
                        row("Para", to)
                        row("Valor", "\(r.amount_pts) pts")
                        row("Comprovante", r.receipt_code)
                    }
                }
                .frame(maxWidth: 380)
            }
            Button("Fazer novo envio") {
                to = ""; amount = ""; message = ""; password = ""
                receipt = nil
                step = .form
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private var insufficientView: some View {
        VStack(spacing: 16) {
            SuccessTick(color: BlaxxColor.negative, icon: "exclamationmark")
            Eyebrow(text: "Atenção")
            Text("Saldo insuficiente")
                .font(BlaxxFont.display(28))
            Text("Você não tem pontos suficientes para essa operação.")
                .foregroundStyle(BlaxxColor.gray600)
            Button("Voltar") {
                step = .form
                error = nil
            }
            .buttonStyle(GhostButtonStyle())
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

    private func submit() async {
        guard let n = Int(amount), !to.isEmpty, !password.isEmpty else { return }
        do {
            let r = try await BlaxxAPI.shared.transfer(
                to: to, amountPts: n,
                message: message.isEmpty ? nil : message,
                password: password
            )
            receipt = r
            step = .done
            // Transfer cria 2 Transactions (debit no remetente, credit no
            // recipient) — notifica as telas de carteira/extrato.
            session.bumpWalletReload()
        } catch let apiErr as APIError {
            if apiErr.message.lowercased().contains("saldo") {
                step = .insufficient
            } else {
                self.error = apiErr.message
            }
        } catch is CancellationError {
            // ignorar
        } catch let e {
            self.error = e.localizedDescription
        }
    }
}
