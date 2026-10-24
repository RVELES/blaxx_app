//
//  BXCodigo2FATela.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Passo do código por SMS do login com 2FA (POST /auth/login/2fa). Aparece dentro de Entrar, no lugar
//  do formulário. Código de 6 dígitos (colado de uma vez pelo `.oneTimeCode`), tentativas restantes,
//  desafio expirado → volta ao formulário.
//

import SwiftUI

struct BXCodigo2FATela: View {
    @Environment(BXSessao.self) private var sessao

    let desafio: String
    let dica: String?
    let aoVoltar: () -> Void

    @State private var codigo = ""
    @State private var erro: String?
    @State private var expirou = false
    @State private var confirmando = false

    var body: some View {
        BXCartaoAcesso {
            BXChip("Verificação em duas etapas", .eyebrow)
            BXTituloAcesso("Digite o código.",
                           sub: dica.map { "Enviamos um código por SMS para o celular \($0)." }
                                ?? "Enviamos um código por SMS para o seu celular.")

            BXCampoCodigo(codigo: $codigo)
                .accessibilityLabel("Código de 6 dígitos")
                .onChange(of: codigo) { _, novo in
                    if novo.count == 6, !confirmando { Task { await confirmar() } }
                }
                .disabled(expirou)

            if let erro { BXErroFormulario(erro) }

            if expirou {
                BXBotao("Entrar de novo", estilo: .preto, acao: aoVoltar)
            } else {
                BXBotao("Confirmar →", estilo: .preto, carregando: confirmando) {
                    Task { await confirmar() }
                }
                BXBotao("← Voltar", estilo: .secundario, acao: aoVoltar)
                    .disabled(confirmando)
            }

            Text("O código vale por poucos minutos. Não compartilhe com ninguém.")
                .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .animation(BXMovimento.ease, value: erro)
    }

    private func confirmar() async {
        guard !confirmando, !expirou else { return }
        guard codigo.count == 6 else {
            erro = "Digite os 6 dígitos do código."
            return
        }
        erro = nil
        confirmando = true
        defer { confirmando = false }
        do {
            try await sessao.concluir2FASMS(desafio: desafio, codigo: codigo)
            BXHaptica.tocar(.sucesso)
        } catch {
            let e = BXErro.de(error)
            codigo = ""
            switch e.codigo {
            case "challenge_expired", "code_expired":
                expirou = true
                erro = "O código expirou. Entre de novo para receber outro."
            case "invalid_code", "wrong_code":
                if let n = e.tentativasRestantes {
                    erro = n == 1 ? "Código incorreto. Resta 1 tentativa." : "Código incorreto. Restam \(n) tentativas."
                } else {
                    erro = "Código incorreto. Confira o SMS e tente de novo."
                }
            default:
                if e.tipo == .muitasTentativas { expirou = true }
                erro = e.mensagemServidorSegura ?? e.mensagemParaUsuario
            }
            BXHaptica.tocar(.erro)
        }
    }
}
