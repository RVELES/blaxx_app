//
//  ForgotPasswordView.swift
//  BlaxxPontos
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var loading = false
    @State private var sent = false
    @State private var error: String?
    @State private var showingReset = false

    var body: some View {
        ZStack {
            BlaxxColor.gray50.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        BlaxxWordmark(size: 40, tone: .dark)
                        Text("Recuperar senha")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.8)
                            .textCase(.uppercase)
                            .foregroundStyle(BlaxxColor.gray400)
                    }

                    BlaxxCard {
                        if sent {
                            VStack(spacing: 14) {
                                SuccessTick()
                                Text("Verifique sua caixa de entrada")
                                    .font(BlaxxFont.display(20))
                                    .foregroundStyle(BlaxxColor.black)
                                Text("Se houver uma conta cadastrada com este e-mail, você receberá um link nos próximos minutos. O link é válido por 30 minutos e funciona uma única vez.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(BlaxxColor.gray600)
                                    .multilineTextAlignment(.center)
                                Button("Já tenho um código") { showingReset = true }
                                    .buttonStyle(GhostButtonStyle(fullWidth: true))
                                    .padding(.top, 4)
                                Button("Voltar para o login") { dismiss() }
                                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                Eyebrow(text: "Recuperação")
                                Text("Esqueceu a senha?")
                                    .font(BlaxxFont.display(22))
                                Text("Digite seu e-mail cadastrado. Vamos enviar um link pra você criar uma nova senha.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(BlaxxColor.gray600)

                                BlaxxField(label: "E-mail", value: $email,
                                           placeholder: "voce@email.com")

                                if let error {
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundStyle(BlaxxColor.negative)
                                }

                                Button {
                                    Task { await submit() }
                                } label: {
                                    HStack {
                                        if loading { ProgressView().scaleEffect(0.7) }
                                        Text(loading ? "Enviando…" : "Enviar link")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                                .disabled(loading)

                                Button("Cancelar") { dismiss() }
                                    .buttonStyle(GhostButtonStyle(fullWidth: true))
                            }
                        }
                    }
                    .frame(maxWidth: 460)
                }
                .padding(40)
            }
        }
        .sheet(isPresented: $showingReset) {
            ResetPasswordView()
        }
    }

    private func submit() async {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard e.contains("@"), e.contains(".") else {
            error = "E-mail inválido"; return
        }
        loading = true
        defer { loading = false }
        do {
            try await BlaxxAPI.shared.forgotPassword(email: e)
            sent = true
        } catch {
            // Mesmo em caso de erro, mostramos como enviado (anti-enumeração)
            sent = true
        }
    }
}

#Preview { ForgotPasswordView() }
