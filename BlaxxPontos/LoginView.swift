//
//  LoginView.swift
//  BlaxxPontos
//

import SwiftUI

struct LoginView: View {
    @Environment(Session.self) private var session
    /// Opcional: volta para a Home pública. Quando nil, não mostra o botão.
    var onBack: (() -> Void)? = nil
    @State private var emailOrCPF: String = ""
    @State private var password: String = ""
    @State private var showingRegister = false
    @State private var showingForgotPassword = false

    var body: some View {
        CompactReader { isCompact in
            ZStack(alignment: .topLeading) {
                BlaxxColor.gray50.ignoresSafeArea()

                if isCompact {
                    // iPhone: empilhado, com um cabeçalho de boas-vindas amigável.
                    ScrollView {
                        VStack(spacing: 24) {
                            welcomeHeaderCompact
                            loginCard
                        }
                        .padding(28)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // Mac / iPad: split amigável (aside escuro + formulário).
                    HStack(spacing: 0) {
                        welcomeAside
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        ZStack {
                            BlaxxColor.gray50
                            loginCard
                                .frame(maxWidth: 420)
                                .padding(40)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .ignoresSafeArea()
                }

                if let onBack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                            Text("Voltar").font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isCompact ? BlaxxColor.gray600 : .white)
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showingRegister) {
            RegisterView().environment(session)
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
    }

    // MARK: - Aside de boas-vindas (Mac/iPad)
    private var welcomeAside: some View {
        ZStack {
            LinearGradient(colors: [BlaxxColor.black, Color(red: 0.10, green: 0.12, blue: 0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Brilho lime difuso
            Circle()
                .fill(BlaxxColor.lime.opacity(0.18))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -120, y: -160)

            VStack(alignment: .leading, spacing: 28) {
                BlaxxWordmark(size: 34, tone: .light)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Que bom ter você de volta 👋")
                        .font(BlaxxFont.display(30))
                        .foregroundStyle(.white)
                    Text("Sua carteira de pontos Blaxx, com tudo num só lugar — e sempre sincronizada entre web, Windows e Mac.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    asideFeature("🎁", "Troque pontos por benefícios em + de 250 parceiros")
                    asideFeature("＋", "Compre pontos via PIX em segundos")
                    asideFeature("↙", "Venda pontos e receba cashback no PIX")
                    asideFeature("↗", "Presenteie alguém com seus pontos")
                }

                Spacer()

                Text("Créditos promocionais de uso restrito · Programa de pontos Blaxx")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(48)
            .frame(maxWidth: 480, alignment: .leading)
        }
    }

    private func asideFeature(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .background(Circle().fill(.white.opacity(0.08)))
                .foregroundStyle(BlaxxColor.lime)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Cabeçalho compacto (iPhone)
    private var welcomeHeaderCompact: some View {
        VStack(spacing: 10) {
            BlaxxWordmark(size: 32, tone: .dark)
            Text("Que bom ter você de volta 👋")
                .font(BlaxxFont.display(20))
                .foregroundStyle(BlaxxColor.black)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Card do formulário (compartilhado)
    private var loginCard: some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: "Entrar")
                Text("Acesse sua carteira")
                    .font(BlaxxFont.display(22))
                    .foregroundStyle(BlaxxColor.black)
                Text("Use o e-mail ou CPF cadastrado.")
                    .font(.system(size: 14))
                    .foregroundStyle(BlaxxColor.gray600)
                    .padding(.bottom, 4)

                BlaxxField(label: "E-mail ou CPF", value: $emailOrCPF,
                           placeholder: "voce@email.com")
                BlaxxField(label: "Senha", value: $password,
                           placeholder: "••••••",
                           isSecure: true)

                if let err = session.lastError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(BlaxxColor.negative)
                }

                Button {
                    Task { await session.login(emailOrCPF: emailOrCPF, password: password) }
                } label: {
                    HStack {
                        if session.isLoading {
                            ProgressView().scaleEffect(0.7)
                        }
                        Text(session.isLoading ? "Entrando…" : "Entrar")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                .padding(.top, 4)

                HStack {
                    Button("Esqueci a senha") {
                        showingForgotPassword = true
                    }
                        .buttonStyle(.plain)
                        .foregroundStyle(BlaxxColor.limeDark)
                    Spacer()
                    Button("Criar conta") {
                        showingRegister = true
                    }
                        .buttonStyle(.plain)
                        .foregroundStyle(BlaxxColor.limeDark)
                }
                .font(.system(size: 13))
            }
        }
    }
}

#Preview {
    LoginView().environment(Session())
}
