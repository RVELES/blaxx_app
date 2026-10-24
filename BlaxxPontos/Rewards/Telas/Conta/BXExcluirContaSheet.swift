//
//  BXExcluirContaSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Excluir minha conta (LGPD art. 18; App Store 5.1.1(v)): explicação do que acontece, senha (ou
//  reautenticação com o Google em conta sem senha), digitar "EXCLUIR" e botão de perigo →
//  DELETE /auth/account com confirm "EXCLUIR MINHA CONTA" → sessão revogada ("Sua conta foi excluída.").
//  401 de senha errada fica na tela e NÃO derruba a sessão.
//

import SwiftUI

struct BXExcluirContaSheet: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(\.dismiss) private var fechar

    @State private var senha = ""
    @State private var confirmacao = ""
    @State private var excluindo = false
    @State private var erroSenha: String?
    @State private var erroGeral: String?
    @State private var confirmarFinal = false

    private var contaSoGoogle: Bool { sessao.usuario.map { !$0.temSenha } ?? false }
    private var digitouExcluir: Bool {
        confirmacao.trimmingCharacters(in: .whitespaces).uppercased() == "EXCLUIR"
    }
    private var podeExcluir: Bool { digitouExcluir && (contaSoGoogle || !senha.isEmpty) && !excluindo }

    var body: some View {
        BXCorpoFolhaConta {
            BXCabecalhoFolhaConta(rotulo: "Zona de risco", titulo: "Excluir minha conta.") { fechar() }

            VStack(alignment: .leading, spacing: 12) {
                Text("O que acontece").bxFonte(.rotulo).foregroundStyle(BXCor.perigoTexto)
                item("Seu nome, e-mail e celular são apagados e você perde o acesso à conta.")
                item("O saldo de pontos, os vouchers ativos e os envios em processamento deixam de estar disponíveis.")
                item("O CPF e o histórico de movimentações ficam guardados pelo prazo que a lei exige (registro fiscal e contábil).")
                item("Todas as sessões são encerradas, em todos os aparelhos.")
                Text("Esta ação não pode ser desfeita.")
                    .bxFonte(.item).foregroundStyle(BXCor.perigoTexto)
                    .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BXCor.perigoFundo, in: RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous))
            .accessibilityElement(children: .combine)

            if contaSoGoogle {
                BXNotaConta(texto: "Sua conta entra pelo Google. Para confirmar, vamos abrir a janela do Google e pedir que você entre de novo.")
            } else {
                BXCampo("Sua senha", texto: $senha, tipo: .senha, erro: erroSenha)
                    .onChange(of: senha) { _, _ in erroSenha = nil }
            }

            BXCampo("Digite EXCLUIR para confirmar", texto: $confirmacao, placeholder: "EXCLUIR")
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            if let erroGeral { BXAvisoErroConta(texto: erroGeral) }

            BXBotao(contaSoGoogle ? "Confirmar com o Google e excluir" : "Excluir minha conta",
                    estilo: .perigo, carregando: excluindo) { confirmarFinal = true }
                .disabled(!podeExcluir)
                .opacity(podeExcluir || excluindo ? 1 : 0.45)

            BXBotao("Cancelar", estilo: .secundario) { fechar() }

            Text("Se você só quer parar de receber ofertas, revogue o consentimento em Privacidade e dados.")
                .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        }
        .interactiveDismissDisabled(excluindo)
        .confirmationDialog("Excluir a conta agora?", isPresented: $confirmarFinal, titleVisibility: .visible) {
            Button("Excluir definitivamente", role: .destructive) { Task { await excluir() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Seus dados pessoais serão apagados e você perderá o acesso ao saldo.")
        }
        .onAppear {
            if BXDemo.subtela == "excluir" { confirmacao = "EXCLUIR" }
        }
        .onDisappear { senha = "" }
    }

    private func item(_ texto: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("→").bxFonte(.corpo).foregroundStyle(BXCor.perigoTexto)
            Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func excluir() async {
        erroSenha = nil
        erroGeral = nil
        excluindo = true
        defer { excluindo = false }
        do {
            if contaSoGoogle {
                let token = try await sessao.reautenticarGoogle()
                try await BXAPI.shared.excluirConta(senha: nil, googleIdToken: token)
            } else {
                try await BXAPI.shared.excluirConta(senha: senha, googleIdToken: nil)
            }
            senha = ""
            BXHaptica.tocar(.sucesso)
            fechar()
            sessao.sessaoRevogada(motivo: "Sua conta foi excluída.")
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            BXHaptica.tocar(.erro)
            switch e.tipo {
            case .naoAutorizado where !contaSoGoogle:
                erroSenha = "Senha incorreta."
            case .muitasTentativas:
                erroGeral = "Muitas tentativas de exclusão hoje. Tente de novo amanhã ou abra um chamado."
            default:
                erroGeral = e.mensagemParaUsuario
            }
        }
    }
}
