//
//  BXEntrarTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Entrar (login.html, fotos web 02): cartão único "Bem-vindo de volta." · E-MAIL OU CPF · SENHA ·
//  "Esqueci a senha" · "Entrar →" · OU · Google · "Criar conta".
//  Login real (BXSessao.entrar): 2FA por aplicativo (TOTP) pede o código na mesma tela e repete com `mfa`;
//  2FA por SMS troca o cartão pelo passo do código (BXCodigo2FATela). 401/423/429 com texto honesto.
//  Google (D10, também em Release): cancelar a folha é silencioso; falha de rede mostra erro honesto.
//  A senha só vive em @State e é apagada ao sair da tela ou ao entrar.
//

import SwiftUI

struct BXEntrarTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav

    private enum Etapa: Equatable {
        case formulario
        /// 2FA por aplicativo: mesmo cartão, com o campo de código.
        case totp
        /// 2FA por SMS: passo próprio.
        case sms(desafio: String, dica: String?)
    }

    @State private var login = ""
    @State private var senha = ""
    @State private var codigo = ""
    @State private var etapa: Etapa = .formulario
    @State private var erro: String?
    @State private var erroLogin: String?
    @State private var erroSenha: String?
    @State private var entrando = false
    @State private var googleCarregando = false
    @State private var avisoHaptico = 0

    var body: some View {
        BXPaginaAcesso {
            switch etapa {
            case .sms(let desafio, let dica):
                BXCodigo2FATela(desafio: desafio, dica: dica, aoVoltar: voltarDoSMS)
                    .transition(.opacity)
            default:
                formulario
                    .transition(.opacity)
            }
        }
        .animation(BXMovimento.ease, value: etapa)
        .sensoryFeedback(.warning, trigger: avisoHaptico)
        .onDisappear { senha = ""; codigo = "" }
        .task { await demonstracao() }
    }

    // MARK: - Formulário

    private var formulario: some View {
        BXCartaoAcesso {
            BXTituloAcesso("Bem-vindo de volta.", sub: "Entre para acessar seus pontos e benefícios.")

            VStack(alignment: .leading, spacing: 16) {
                BXCampo("E-mail ou CPF", texto: $login, tipo: .emailOuCPF,
                        placeholder: "voce@email.com", erro: erroLogin)
                    .submitLabel(.next)
                BXCampo("Senha", texto: $senha, tipo: .senha, placeholder: "Sua senha", erro: erroSenha)
                    .submitLabel(etapa == .totp ? .next : .go)
                    .onSubmit { if etapa != .totp { Task { await entrar() } } }
                HStack {
                    Spacer(minLength: 0)
                    Button { nav.ir(.recuperarSenha) } label: {
                        Text("Esqueci a senha").bxFonte(.botao).foregroundStyle(BXCor.tinta)
                            .underline()
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, -6)
            }

            if etapa == .totp {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Código de verificação (2FA)").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                        .accessibilityHidden(true)
                    Text("Abra o seu aplicativo autenticador e digite o código de 6 dígitos.")
                        .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                    BXCampoCodigo(codigo: $codigo)
                        .accessibilityLabel("Código de verificação")
                        .onChange(of: codigo) { _, novo in
                            if novo.count == 6, !entrando { Task { await entrar() } }
                        }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let erro { BXErroFormulario(erro) }

            BXBotao(etapa == .totp ? "Confirmar e entrar →" : "Entrar →", estilo: .preto, carregando: entrando) {
                Task { await entrar() }
            }
            .disabled(googleCarregando)

            if BXRecursos.loginGoogle {
                BXDivisorOu()
                BXBotaoGoogle("Fazer Login com o Google", carregando: googleCarregando) {
                    Task { await google() }
                }
                .disabled(entrando)
            }

            Text("Protegido por verificação em duas etapas (2FA).")
                .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            BXTracejado(cor: BXCor.linha)
            HStack(spacing: 6) {
                Text("Ainda não tem conta?").bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                Button { nav.ir(.cadastro) } label: {
                    Text("Criar conta →").bxFonte(.botao).foregroundStyle(BXCor.tinta).underline()
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .animation(BXMovimento.ease, value: erro)
    }

    // MARK: - Ações

    private func limparErros() {
        erro = nil
        erroLogin = nil
        erroSenha = nil
    }

    private func entrar() async {
        guard !entrando else { return }
        limparErros()
        let l = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !l.isEmpty, !senha.isEmpty else {
            if l.isEmpty { erroLogin = "Informe seu e-mail ou CPF." }
            if senha.isEmpty { erroSenha = "Informe sua senha." }
            return
        }
        if etapa == .totp, codigo.count != 6 {
            erro = "Digite os 6 dígitos do código."
            return
        }
        entrando = true
        defer { entrando = false }
        let r = await sessao.entrar(login: l, senha: senha, mfa: etapa == .totp ? codigo : nil)
        switch r {
        case .success(.ok):
            senha = ""
            codigo = ""
            BXHaptica.tocar(.sucesso)
        case .success(.mfaTOTP):
            if etapa == .totp {
                codigo = ""
                erro = "Código inválido. Confira no aplicativo autenticador e tente de novo."
            } else {
                withAnimation(BXMovimento.ease) { etapa = .totp }
            }
            avisoHaptico += 1
        case .success(.mfaSMS(let desafio, let dica)):
            withAnimation(BXMovimento.ease) { etapa = .sms(desafio: desafio, dica: dica) }
            avisoHaptico += 1
        case .failure(let e):
            if etapa == .totp, e.tipo == .mfaNecessario || e.codigo == "invalid_mfa" {
                codigo = ""
                erro = "Código inválido. Confira no aplicativo autenticador e tente de novo."
                return
            }
            erro = mensagem(e)
        }
    }

    private func mensagem(_ e: BXErro) -> String {
        switch e.tipo {
        case .naoAutorizado:
            return e.mensagemServidorSegura ?? "E-mail, CPF ou senha incorretos."
        case .validacao:
            return e.mensagemServidorSegura ?? "Informe e-mail/CPF e senha."
        default:
            return e.mensagemParaUsuario
        }
    }

    private func google() async {
        guard !googleCarregando else { return }
        limparErros()
        googleCarregando = true
        defer { googleCarregando = false }
        do {
            try await sessao.entrarComGoogle()
            BXHaptica.tocar(.sucesso)
        } catch {
            if BXErro.ehCancelamento(error) { return }      // fechou a folha do Google: silencioso
            erro = BXErro.de(error).mensagemParaUsuario
        }
    }

    private func voltarDoSMS() {
        senha = ""
        codigo = ""
        withAnimation(BXMovimento.ease) { etapa = .formulario }
    }

    /// Só no modo demonstração (`-BXDemoVisitante`): `-BXSubtela 2fa|totp` entra com a conta de exemplo
    /// correspondente para fotografar o passo do código. Em Release `BXDemo.subtela` é sempre nil.
    private func demonstracao() async {
        #if DEBUG
        guard BXDemo.visitante, etapa == .formulario, let s = BXDemo.subtela else { return }
        switch s {
        case "2fa": login = "2fa@exemplo.test"
        case "totp": login = "totp@exemplo.test"
        case "erro": login = "cliente@exemplo.test"; senha = "errada"; await entrar(); return
        default: return
        }
        senha = "senha-de-exemplo"
        await entrar()
        #endif
    }
}
