//
//  RewardsLoginView.swift
//  BlaxxPontos
//
//  Mock login gate for the "BlaXx Rewards" experience. Purely visual: any tap on
//  "Entrar" / "Face ID" opens the RewardsShell — no backend, no credentials.
//  Self-contained / prefixed (RW…) so nothing collides with the existing app.
//

import SwiftUI

/// Reversible login gate: shows the mock login first, swaps to the shell on entry.
/// ContentView points at this (`RewardsRoot()`); revert to `RewardsShell()` to skip.
struct RewardsRoot: View {
    @State private var loggedIn = false

    var body: some View {
        ZStack {
            if loggedIn {
                RewardsShell()
                    .transition(.opacity)
            } else {
                RewardsLoginView(onLogin: enter)
                    .transition(.opacity)
            }
        }
    }

    private func enter() {
        withAnimation(.easeInOut(duration: 0.35)) { loggedIn = true }
    }
}

struct RewardsLoginView: View {
    var onLogin: () -> Void

    @State private var email = ""
    @State private var senha = ""
    @FocusState private var focus: Field?
    private enum Field { case email, senha }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x16181A), Color(hex: 0x0A0B0C)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)
                lockup
                Spacer(minLength: 24)
                fields
                cta
                footer
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 36)
        }
    }

    // MARK: Lockup

    private var lockup: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                // Marca oficial (arte vetorial). Antes eram três elementos —
                // símbolo + wordmark em Text + "REWARDS" em Text —, e o
                // wordmark mudava de forma conforme a fonte disponível.
                // BlaxxLockup já é esse lockup completo, na proporção certa.
                Image("BlaxxLockup")
                    .resizable().scaledToFit()
                    .frame(height: 118)
                    .accessibilityLabel("BlaXx Rewards")
            }
            Text("Troque seus pontos. Multiplique vantagens.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0xB9BDB5))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: 12) {
            field(icon: "envelope", placeholder: "E-mail", text: $email,
                  field: .email, keyboard: .emailAddress, secure: false)
            field(icon: "lock", placeholder: "Senha", text: $senha,
                  field: .senha, keyboard: .default, secure: true)
        }
        .padding(.bottom, 18)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>,
                       field: Field, keyboard: UIKeyboardType, secure: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(focus == field ? RWColor.neon : RWColor.muted)
                .frame(width: 20)
            Group {
                if secure {
                    SecureField("", text: text, prompt: prompt(placeholder))
                } else {
                    TextField("", text: text, prompt: prompt(placeholder))
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .focused($focus, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(focus == field ? RWColor.neon.opacity(0.7) : Color.white.opacity(0.10),
                        lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: focus)
    }

    private func prompt(_ s: String) -> Text {
        Text(s).foregroundColor(RWColor.muted)
    }

    // MARK: CTA

    private var cta: some View {
        VStack(spacing: 14) {
            Button(action: onLogin) {
                Text("Entrar")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RWColor.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RWColor.fabGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color(hex: 0x40D210).opacity(0.4), radius: 14, x: 0, y: 10)
            }
            .buttonStyle(.plain)

            Button(action: onLogin) {
                HStack(spacing: 9) {
                    Image(systemName: "faceid").font(.system(size: 18, weight: .semibold))
                    Text("Entrar com Face ID").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 5) {
            Text("Novo na BlaXx?")
                .font(.system(size: 13))
                .foregroundStyle(RWColor.muted)
            Button(action: onLogin) {
                Text("Criar conta")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RWColor.neon)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }
}

#Preview {
    RewardsLoginView(onLogin: {})
}
