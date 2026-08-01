//
//  ResetPasswordView.swift
//  BlaxxPontos
//
//  Tela de redefinição de senha. Recebe o token do e-mail de recuperação
//  (deep link `blaxxpontos://redefinir-senha?token=…` capturado em
//  BlaxxPontosApp.onOpenURL) ou colado manualmente, e aplica a nova senha
//  via BlaxxAPI.resetPassword. Paridade com a tela web RedefinirSenha.tsx.
//

import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    /// Token recebido por deep link. Se vazio, mostramos um campo pra colar.
    @State var token: String = ""

    @State private var password = ""
    @State private var confirm = ""
    @State private var loading = false
    @State private var done = false
    @State private var error: String?

    var body: some View {
        ZStack {
            BlaxxColor.gray50.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        BlaxxWordmark(size: 40, tone: .dark)
                        Text("Redefinir senha")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.8)
                            .textCase(.uppercase)
                            .foregroundStyle(BlaxxColor.gray400)
                    }

                    BlaxxCard {
                        if done {
                            VStack(spacing: 14) {
                                SuccessTick()
                                Text("Senha redefinida")
                                    .font(BlaxxFont.display(20))
                                    .foregroundStyle(BlaxxColor.black)
                                Text("Sua senha foi alterada com sucesso. Use a nova senha para entrar na sua conta.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(BlaxxColor.gray600)
                                    .multilineTextAlignment(.center)
                                Button("Voltar para o login") { dismiss() }
                                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                                    .padding(.top, 8)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                Eyebrow(text: "Recuperação")
                                Text("Crie uma nova senha")
                                    .font(BlaxxFont.display(22))
                                Text("Escolha uma senha com pelo menos 8 caracteres, contendo letras e números. O link de recuperação é válido por 30 minutos e funciona uma única vez.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(BlaxxColor.gray600)

                                // Token: editável só quando não veio por deep link,
                                // pra permitir colar o código manualmente.
                                if token.isEmpty {
                                    BlaxxField(label: "Código / token do e-mail", value: $token,
                                               placeholder: "Cole o código recebido")
                                }

                                BlaxxField(label: "Nova senha", value: $password,
                                           placeholder: "••••••", isSecure: true)
                                BlaxxField(label: "Confirmar nova senha", value: $confirm,
                                           placeholder: "••••••", isSecure: true)

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
                                        Text(loading ? "Salvando…" : "Redefinir senha")
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
    }

    private func submit() async {
        let tok = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tok.isEmpty else {
            error = "Código de recuperação ausente. Abra o link do e-mail ou cole o código."
            return
        }
        guard password.count >= 8 else {
            error = "A senha precisa ter pelo menos 8 caracteres."
            return
        }
        let hasLetter = password.rangeOfCharacter(from: .letters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        guard hasLetter && hasDigit else {
            error = "A senha precisa combinar letras e números."
            return
        }
        guard password == confirm else {
            error = "As senhas não conferem."
            return
        }
        error = nil
        loading = true
        defer { loading = false }
        do {
            try await BlaxxAPI.shared.resetPassword(token: tok, newPassword: password)
            done = true
        } catch let e as APIError {
            // O backend devolve o código no campo `error`, que vira `message`.
            // Mapeia pra mensagens amigáveis (paridade com RedefinirSenha.tsx).
            error = e.message
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview { ResetPasswordView(token: "demo-token") }
