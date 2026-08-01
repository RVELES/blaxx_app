//
//  EmailVerifyGate.swift
//  BlaxxPontos
//
//  Cobertura full-screen exibida em RELEASE quando o usuário está logado
//  mas com `email_verified_at == nil`. Bloqueia o uso do app até o e-mail
//  ser confirmado via código de 6 dígitos enviado por e-mail.
//
//  Em DEBUG o `RewardsBackend.start()` faz auto-verify via `devVerifyEmail`,
//  então este gate nunca aparece em build de desenvolvimento.
//
//  Implementação própria (em vez de reaproveitar EmailVerifyView) porque
//  o EmailVerifyView legado depende de `dismiss()` para fechar — aqui
//  precisamos atualizar o estado do backend para liberar o app.
//

import SwiftUI

struct EmailVerifyGate: View {
    let backend: RewardsBackend

    @State private var code = ""
    @State private var loading = false
    @State private var resendCooldown = 0
    @State private var error: String?
    @State private var sending = false
    @State private var sentOnce = false

    var body: some View {
        ZStack {
            BlaxxColor.gray50.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    BlaxxCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow(text: "Verificação obrigatória")
                            Text("Confirme seu e-mail")
                                .font(BlaxxFont.display(22))
                            Text("Para sua segurança, precisamos confirmar o e-mail \(backend.user?.email ?? "") antes de liberar as operações.")
                                .font(.system(size: 13))
                                .foregroundStyle(BlaxxColor.gray600)

                            if !sentOnce {
                                Button {
                                    Task { await resend() }
                                } label: {
                                    HStack {
                                        if sending { ProgressView().scaleEffect(0.7) }
                                        Text(sending ? "Enviando…" : "Enviar código por e-mail")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                                .disabled(sending)
                            } else {
                                BlaxxField(label: "Código de 6 dígitos", value: $code,
                                           placeholder: "000000",
                                           hint: "Veja na sua caixa de entrada")
                                    #if os(iOS)
                                    .keyboardType(.numberPad)
                                    #endif

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
                                        Text(loading ? "Validando…" : "Confirmar e-mail")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                                .disabled(loading || code.count != 6)
                                .accessibilityLabel("Confirmar código de verificação de e-mail")

                                HStack {
                                    if resendCooldown > 0 {
                                        Text("Reenviar em \(resendCooldown)s")
                                            .font(.system(size: 12))
                                            .foregroundStyle(BlaxxColor.gray400)
                                    } else {
                                        Button("Reenviar código") {
                                            Task { await resend() }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(BlaxxColor.limeDark)
                                        .font(.system(size: 12))
                                    }
                                    Spacer()
                                    Button("Sair") {
                                        TokenStore.clear()
                                        TokenStore.clearProfile()
                                        Task { await backend.refreshUserAndEmailStatus() }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(BlaxxColor.gray400)
                                    .font(.system(size: 12))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 460)
                }
                .padding(40)
            }
        }
        .task {
            // Re-checa status ao abrir (caso já tenha sido verificado fora).
            await backend.refreshUserAndEmailStatus()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            BlaxxWordmark(size: 40, tone: .dark)
            Text("Confirmação de e-mail")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(BlaxxColor.gray400)
        }
    }

    private func submit() async {
        error = nil
        loading = true
        defer { loading = false }
        do {
            _ = try await BlaxxAPI.shared.verifyEmail(code: code)
            await backend.refreshUserAndEmailStatus()
            // O gate desaparece quando emailVerified vira true (overlay
            // condicional na RewardsShell).
        } catch let apiErr as APIError {
            error = apiErr.message
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func resend() async {
        sending = true
        defer { sending = false }
        error = nil
        do {
            _ = try await BlaxxAPI.shared.resendEmailVerification()
            sentOnce = true
        } catch {
            self.error = "Falha ao enviar. Tente novamente em instantes."
        }
        resendCooldown = 30
        while resendCooldown > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            resendCooldown -= 1
        }
    }
}
