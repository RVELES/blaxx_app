//
//  ChangePasswordView.swift
//  BlaxxPontos
//

import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var loading = false
    @State private var error: String?
    @State private var done = false

    var body: some View {
        ZStack {
            BlaxxColor.gray50.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    if done {
                        VStack(spacing: 14) {
                            SuccessTick()
                            Text("Senha alterada")
                                .font(BlaxxFont.display(24))
                            Text("Sua nova senha já está ativa.")
                                .font(.system(size: 13))
                                .foregroundStyle(BlaxxColor.gray600)
                            Button("Fechar") { dismiss() }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                    } else {
                        BlaxxCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Eyebrow(text: "Segurança")
                                Text("Alterar senha")
                                    .font(BlaxxFont.display(22))

                                BlaxxField(label: "Senha atual", value: $current,
                                           placeholder: "••••••", isSecure: true)
                                BlaxxField(label: "Nova senha", value: $new,
                                           placeholder: "Mín. 8 chars · maiúscula · minúscula · número · símbolo",
                                           isSecure: true,
                                           hint: "Ex: \"Z9!mxKj#\"")
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
                                        Text(loading ? "Alterando…" : "Alterar senha")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                                .disabled(loading)

                                Button("Cancelar") { dismiss() }
                                    .buttonStyle(GhostButtonStyle(fullWidth: true))
                            }
                        }
                        .frame(maxWidth: 460)
                    }
                }
                .padding(40)
            }
        }
    }

    private func submit() async {
        error = nil
        guard !current.isEmpty else { error = "Informe a senha atual"; return }
        guard new == confirm else { error = "As senhas não coincidem"; return }
        loading = true
        defer { loading = false }
        do {
            try await BlaxxAPI.shared.changePassword(
                oldPassword: current, newPassword: new
            )
            done = true
        } catch let apiErr as APIError {
            self.error = apiErr.message
        } catch let e {
            self.error = e.localizedDescription
        }
    }
}

#Preview { ChangePasswordView() }
