//
//  EmailVerifyView.swift
//  BlaxxPontos
//
//  Tela de confirmação do código de 6 dígitos enviado por e-mail.
//  Quando aberta, mostra status atual do email_verified do usuário.
//

import SwiftUI

struct EmailVerifyView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var loading = false
    @State private var resendCooldown = 0
    @State private var error: String?
    @State private var done = false
    /// True quando MAILER=console e o backend devolveu o código no response.
    /// Mostramos banner amarelo "modo dev" e fazemos auto-submit.
    @State private var devCodeAutoFilled = false

    var body: some View {
        ZStack {
            BlaxxColor.gray50.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    if done {
                        successView
                    } else {
                        codeForm
                    }
                }
                .padding(40)
            }
        }
        .task {
            // Pede um código novo na hora que abre (caso tenha expirado)
            await resend(silent: true)
        }
    }

    private var codeForm: some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Verificação")
                Text("Confirme seu e-mail")
                    .font(BlaxxFont.display(22))
                Text("Enviamos um código de 6 dígitos para \(session.user?.email ?? ""). O código é válido por 10 minutos.")
                    .font(.system(size: 13))
                    .foregroundStyle(BlaxxColor.gray600)

                if devCodeAutoFilled {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(BlaxxColor.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Modo dev (MAILER=console)")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Código capturado direto do response. Em produção, MAILER=resend.")
                                .font(.system(size: 11))
                                .foregroundStyle(BlaxxColor.gray600)
                        }
                    }
                    .padding(10)
                    .background(BlaxxColor.warning.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

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
                    Button("Verifico depois") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(BlaxxColor.gray400)
                        .font(.system(size: 12))
                }
            }
        }
        .frame(maxWidth: 460)
    }

    private var successView: some View {
        VStack(spacing: 16) {
            SuccessTick()
            Text("E-mail confirmado!")
                .font(BlaxxFont.display(28))
                .foregroundStyle(BlaxxColor.black)
            Text("Sua conta está liberada para todas as operações.")
                .font(.system(size: 14))
                .foregroundStyle(BlaxxColor.gray600)
            Button("Continuar") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 12)
        }
        .padding(40)
    }

    private func submit() async {
        self.error = nil
        loading = true
        defer { loading = false }
        do {
            _ = try await BlaxxAPI.shared.verifyEmail(code: code)
            await session.refreshUser()
            done = true
        } catch let apiErr as APIError {
            self.error = apiErr.message
        } catch let e {
            self.error = e.localizedDescription
        }
    }

    private func resend(silent: Bool = false) async {
        do {
            let resp = try await BlaxxAPI.shared.resendEmailVerification()
            if !silent { error = nil }
            // Dev fallback: MAILER=console devolve _dev_code no response.
            // Auto-preenche e dispara o submit pra desbloquear teste.
            if let dev = resp._dev_code, dev.count == 6 {
                code = dev
                devCodeAutoFilled = true
                // Pequeno delay pra UI assentar o estado antes do submit.
                try? await Task.sleep(nanoseconds: 200_000_000)
                await submit()
            } else if resp.delivered == false && !silent {
                // Provider real reportou falha (key inválida, dominio etc).
                error = "O provedor reportou falha no envio. Tente reenviar em alguns segundos."
            }
        } catch {
            if !silent {
                self.error = "Falha ao reenviar. Aguarde e tente de novo."
            }
        }
        // Cooldown 30s
        resendCooldown = 30
        while resendCooldown > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            resendCooldown -= 1
        }
    }
}

#Preview { EmailVerifyView().environment(Session()) }
