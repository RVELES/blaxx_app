//
//  RegisterView.swift
//  BlaxxPontos
//
//  Cadastro de novo cliente B2C. Após sucesso, auto-login e dismiss.
//

import SwiftUI

struct RegisterView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var cpf = ""
    @State private var pixKey = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var clientError: String?

    var body: some View {
        ZStack {
            BlaxxColor.gray50.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        BlaxxWordmark(size: 40, tone: .dark)
                        Text("Criar conta")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.8)
                            .textCase(.uppercase)
                            .foregroundStyle(BlaxxColor.gray400)
                    }

                    BlaxxCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow(text: "Cadastro")
                            Text("Sua carteira em 30 segundos")
                                .font(BlaxxFont.display(22))
                                .foregroundStyle(BlaxxColor.black)
                            Text("Comece a acumular pontos hoje. Cadastro gratuito.")
                                .font(.system(size: 13))
                                .foregroundStyle(BlaxxColor.gray600)
                                .padding(.bottom, 4)

                            BlaxxField(label: "Nome completo", value: $name,
                                       placeholder: "Ex: Maria Silva")
                            BlaxxField(label: "E-mail", value: $email,
                                       placeholder: "voce@email.com")
                                #if os(iOS)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                #endif
                            BlaxxField(label: "CPF (só números)", value: $cpf,
                                       placeholder: "00000000000",
                                       hint: "Demo CPFs válidos: 52998224725, 11144477735")
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                            BlaxxField(label: "Chave PIX (opcional)", value: $pixKey,
                                       placeholder: "e-mail, telefone, CPF ou chave aleatória")
                            BlaxxField(label: "Senha (mín. 6 caracteres)",
                                       value: $password,
                                       placeholder: "••••••",
                                       isSecure: true)
                            BlaxxField(label: "Confirmar senha",
                                       value: $passwordConfirm,
                                       placeholder: "••••••",
                                       isSecure: true)

                            if let err = clientError ?? session.lastError {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundStyle(BlaxxColor.negative)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                HStack {
                                    if session.isLoading { ProgressView().scaleEffect(0.7) }
                                    Text(session.isLoading ? "Criando…" : "Criar conta")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                            .padding(.top, 4)
                            .disabled(session.isLoading)

                            Button("Já tenho conta · Entrar") { dismiss() }
                                .buttonStyle(.plain)
                                .foregroundStyle(BlaxxColor.limeDark)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: 460)

                    Text("Pontos Blaxx são créditos promocionais de uso restrito. Não são moeda, depósito ou investimento.")
                        .font(.system(size: 11))
                        .foregroundStyle(BlaxxColor.gray400)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }
                .padding(40)
            }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(false)
        #endif
    }

    private func submit() async {
        clientError = nil

        // Validações client-side rápidas (UX melhor que esperar HTTP)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let normalizedCPF = cpf.filter(\.isNumber)
        let trimmedPix = pixKey.trimmingCharacters(in: .whitespaces)

        guard trimmedName.count >= 3 else {
            clientError = "Nome muito curto (mínimo 3 caracteres)"; return
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            clientError = "E-mail inválido"; return
        }
        guard normalizedCPF.count == 11 else {
            clientError = "CPF precisa ter 11 dígitos"; return
        }
        guard password.count >= 7 else {
            clientError = "Senha precisa ter no mínimo 7 caracteres"; return
        }
        guard password == passwordConfirm else {
            clientError = "As senhas não coincidem"; return
        }

        let ok = await session.register(
            name: trimmedName,
            email: trimmedEmail,
            cpf: normalizedCPF,
            password: password,
            pixKey: trimmedPix.isEmpty ? nil : trimmedPix
        )

        if ok {
            // Já está logado pelo session.register. Fechar a sheet/destination.
            dismiss()
        }
        // Se falhou, session.lastError já vai mostrar a mensagem
    }
}

#Preview {
    RegisterView().environment(Session())
}
