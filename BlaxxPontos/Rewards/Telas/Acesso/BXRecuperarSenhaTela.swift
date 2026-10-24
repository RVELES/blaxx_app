//
//  BXRecuperarSenhaTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Recuperar senha (recuperar-senha.html, fotos web 04): e-mail → POST /auth/forgot-password.
//  A resposta é sempre genérica (não revela se o e-mail existe) e o formulário some, como no web.
//

import SwiftUI

struct BXRecuperarSenhaTela: View {
    @Environment(BXNavegacao.self) private var nav

    @State private var email = ""
    @State private var erroEmail: String?
    @State private var erro: String?
    @State private var enviando = false
    @State private var enviado = false

    var body: some View {
        BXPaginaAcesso {
            BXCartaoAcesso {
                BXTituloAcesso("Recuperar senha.",
                               sub: "Informe seu e-mail e enviaremos um link para redefinir sua senha.")
                if enviado {
                    BXAvisoFormulario("Se este e-mail estiver cadastrado, enviamos as instruções de redefinição. Verifique a caixa de entrada e o spam.")
                    BXBotao("Voltar para entrar", estilo: .preto) { nav.voltar() }
                } else {
                    BXCampo("E-mail", texto: $email, tipo: .email, placeholder: "voce@email.com", erro: erroEmail)
                        .submitLabel(.send)
                        .onSubmit { Task { await enviar() } }
                    if let erro { BXErroFormulario(erro) }
                    BXBotao("Enviar link de recuperação →", estilo: .preto, carregando: enviando) {
                        Task { await enviar() }
                    }
                    Text("O link expira em 30 minutos.")
                        .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .animation(BXMovimento.ease, value: enviado)
        }
    }

    private func enviar() async {
        guard !enviando else { return }
        erro = nil
        erroEmail = BXValidaAcesso.email(email) ? nil : "Informe um e-mail válido."
        guard erroEmail == nil else { return }
        enviando = true
        defer { enviando = false }
        do {
            try await BXAPI.shared.esqueciSenha(email: email)
            enviado = true
            BXHaptica.tocar(.sucesso)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            switch e.tipo {
            case .semConexao, .tempoEsgotado, .servidor, .muitasTentativas:
                erro = e.mensagemParaUsuario
            default:
                // Qualquer outra resposta continua genérica (sem revelar se o e-mail existe).
                enviado = true
            }
        }
    }
}
