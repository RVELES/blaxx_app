#if BX_LEGADO_REWARDS   // desativado no redesenho Embarque de 22/10/2026. Não apagar sem decisão do dono (D14).
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
            RWColor.screenBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "Verificação obrigatória", color: RWColor.amber)
                        Text("Confirme seu e-mail")
                            .font(BlaxxFont.display(22))
                            .foregroundStyle(RWColor.ink)
                        Text("Para sua segurança, precisamos confirmar o e-mail \(backend.user?.email ?? "") antes de liberar as operações.")
                            .font(.system(size: 13))
                            .foregroundStyle(RWColor.breakdownK)

                        if !sentOnce {
                            RWCTA(title: sending ? "Enviando…" : "Enviar código por e-mail",
                                  disabled: sending) {
                                Task { await resend() }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                RWFieldLabel(text: "Código de 6 dígitos")
                                TextField("", text: $code,
                                          prompt: Text("000000").foregroundColor(RWColor.muted))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(RWColor.ink)
                                    #if os(iOS)
                                    .keyboardType(.numberPad)
                                    #endif
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .background(RWColor.searchBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                Text("Veja na sua caixa de entrada")
                                    .font(.system(size: 12))
                                    .foregroundStyle(RWColor.muted)
                            }

                            if let error {
                                RWSheetError(message: error)
                            }

                            RWCTA(title: loading ? "Validando…" : "Confirmar e-mail",
                                  disabled: loading || code.count != 6) {
                                Task { await submit() }
                            }
                            .accessibilityLabel("Confirmar código de verificação de e-mail")

                            HStack {
                                if resendCooldown > 0 {
                                    Text("Reenviar em \(resendCooldown)s")
                                        .font(.system(size: 12))
                                        .foregroundStyle(RWColor.muted)
                                } else {
                                    Button("Reenviar código") {
                                        Task { await resend() }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(RWColor.greenLight)
                                    .font(.system(size: 12))
                                }
                                Spacer()
                                Button("Sair") {
                                    TokenStore.clear()
                                    TokenStore.clearProfile()
                                    Task { await backend.refreshUserAndEmailStatus() }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(RWColor.muted)
                                .font(.system(size: 12))
                            }
                        }
                    }
                    .padding(20)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .rwBrutalCard()
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
            Image("BlaxxWordmarkClaro")
                .resizable().scaledToFit()
                .frame(height: 40)
                .accessibilityLabel("BlaXx Rewards")
            Text("Confirmação de e-mail")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(RWColor.muted)
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

#endif
