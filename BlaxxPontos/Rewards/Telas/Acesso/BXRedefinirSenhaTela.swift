//
//  BXRedefinirSenhaTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Redefinir senha (redefinir-senha.html), aberta pelo deep link `blaxxpontos://redefinir-senha?token=…`.
//  Nova senha + confirmação → POST /auth/reset-password {token, password, password_confirm}.
//  Sucesso: toast + Entrar (o backend encerra todas as sessões). Política de senha pelos `issues` do servidor.
//

import SwiftUI

struct BXRedefinirSenhaTela: View {
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    let token: String?

    @State private var senha = ""
    @State private var confirmacao = ""
    @State private var erroSenha: String?
    @State private var erroConfirmacao: String?
    @State private var erro: String?
    @State private var problemas: [String] = []
    @State private var salvando = false

    var body: some View {
        BXPaginaAcesso {
            BXCartaoAcesso {
                BXTituloAcesso("Redefinir senha.", sub: "Escolha uma nova senha para a sua conta BlaXx.")
                if token?.isEmpty ?? true {
                    BXErroFormulario("Este link de redefinição é inválido ou já foi usado. Peça um novo link.")
                    BXBotao("Pedir novo link →", estilo: .preto) { nav.ir(.recuperarSenha) }
                } else {
                    BXCampo("Nova senha", texto: $senha, tipo: .novaSenha, placeholder: "Mínimo 7 caracteres",
                            erro: erroSenha)
                        .submitLabel(.next)
                    BXCampo("Confirme a nova senha", texto: $confirmacao, tipo: .novaSenha,
                            placeholder: "Repita a senha", erro: erroConfirmacao)
                        .submitLabel(.done)
                        .onSubmit { Task { await salvar() } }
                    if !problemas.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("A senha precisa").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                            ForEach(problemas, id: \.self) { p in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle().fill(BXCor.perigoTexto).frame(width: 6, height: 6).padding(.top, 7)
                                    Text(p).bxFonte(.corpo).foregroundStyle(BXCor.tinta)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BXCor.superficie2, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
                    }
                    if let erro { BXErroFormulario(erro) }
                    BXBotao("Salvar nova senha →", estilo: .preto, carregando: salvando) {
                        Task { await salvar() }
                    }
                }
            }
            .animation(BXMovimento.ease, value: erro)
        }
        .onDisappear { senha = ""; confirmacao = "" }
    }

    private func salvar() async {
        guard !salvando, let token, !token.isEmpty else { return }
        erro = nil
        problemas = []
        erroSenha = BXValidaAcesso.senha(senha) ? nil : "A senha precisa ter pelo menos 7 caracteres."
        erroConfirmacao = senha == confirmacao ? nil : "As senhas não são iguais."
        guard erroSenha == nil, erroConfirmacao == nil else { return }
        salvando = true
        defer { salvando = false }
        do {
            try await BXAPI.shared.redefinirSenha(token: token, senha: senha)
            senha = ""
            confirmacao = ""
            BXHaptica.tocar(.sucesso)
            toast.mostrar("Senha redefinida. Entre com a nova senha.", .sucesso)
            nav.voltarParaRaiz()
            nav.ir(.entrar)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            if !e.problemasSeguros.isEmpty {
                problemas = e.problemasSeguros
                erroSenha = "Escolha uma senha mais forte."
            } else if e.tipo == .validacao || e.tipo == .naoEncontrado || e.tipo == .naoAutorizado {
                erro = e.mensagemServidorSegura ?? "Este link de redefinição é inválido ou expirou. Peça um novo link."
            } else {
                erro = e.mensagemParaUsuario
            }
            BXHaptica.tocar(.erro)
        }
    }
}
