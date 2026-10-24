//
//  BXTrocarSenhaSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Alterar senha (seguranca.html "Alterar senha"): senha atual, nova senha com a checklist da política
//  (mínimo de 7 caracteres no aparelho; o resto vem de `issues` do servidor), confirmação →
//  POST /auth/change-password. 401 "Senha atual incorreta" fica no campo (não derruba a sessão);
//  sucesso derruba todas as sessões no servidor → `sessaoRevogada("Senha alterada. Entre de novo.")`.
//  As senhas vivem só em @State e são apagadas ao fechar.
//

import SwiftUI

struct BXTrocarSenhaSheet: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(\.dismiss) private var fechar

    @State private var atual = ""
    @State private var nova = ""
    @State private var confirmar = ""
    @State private var salvando = false
    @State private var erroAtual: String?
    @State private var erroConfirmar: String?
    @State private var problemasServidor: [String] = []
    @State private var erroGeral: String?

    static let minimo = 7

    private var regras: [(String, Bool)] {
        [("Pelo menos \(Self.minimo) caracteres", nova.count >= Self.minimo),
         ("Diferente da senha atual", !nova.isEmpty && nova != atual),
         ("As duas senhas novas iguais", !confirmar.isEmpty && nova == confirmar)]
    }
    private var pode: Bool { !atual.isEmpty && regras.allSatisfy(\.1) && !salvando }

    var body: some View {
        BXCorpoFolhaConta {
            BXCabecalhoFolhaConta(rotulo: "Segurança · senha", titulo: "Alterar senha.") { fechar() }
            Text("Use uma senha forte e só sua. Depois de alterar, você entra de novo em todos os aparelhos.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)

            BXCampo("Senha atual", texto: $atual, tipo: .senha, erro: erroAtual)
                .submitLabel(.next)
                .onChange(of: atual) { _, _ in erroAtual = nil }
            BXCampo("Nova senha", texto: $nova, tipo: .novaSenha)
                .submitLabel(.next)
                .onChange(of: nova) { _, _ in problemasServidor = [] }
            BXCampo("Confirmar nova senha", texto: $confirmar, tipo: .novaSenha, erro: erroConfirmar)
                .submitLabel(.done)
                .onSubmit { Task { await salvar() } }
                .onChange(of: confirmar) { _, _ in erroConfirmar = nil }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(regras, id: \.0) { regra in
                    linhaRegra(regra.0, ok: regra.1)
                }
                ForEach(problemasServidor, id: \.self) { p in
                    linhaRegra(p, ok: false, servidor: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BXCor.superficie2, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Requisitos da nova senha")

            if let erroGeral { BXAvisoErroConta(texto: erroGeral) }

            BXBotao("Salvar nova senha", estilo: .preto, carregando: salvando) { Task { await salvar() } }
                .disabled(!pode)
                .opacity(pode || salvando ? 1 : 0.45)
        }
        .interactiveDismissDisabled(salvando)
        .onDisappear { atual = ""; nova = ""; confirmar = "" }
    }

    private func linhaRegra(_ texto: String, ok: Bool, servidor: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(ok ? BXCor.okFundo : (servidor ? BXCor.perigoFundo : BXCor.superficie))
                    .overlay(Circle().strokeBorder(ok ? BXCor.okTexto : (servidor ? BXCor.perigoTexto : BXCor.linha), lineWidth: 1))
                if ok {
                    Path { p in
                        p.move(to: CGPoint(x: 5, y: 10.5)); p.addLine(to: CGPoint(x: 8.5, y: 14)); p.addLine(to: CGPoint(x: 15, y: 6.5))
                    }
                    .stroke(BXCor.okTexto, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: 20, height: 20)
            .animation(BXMovimento.mola, value: ok)
            Text(texto).bxFonte(.corpo)
                .foregroundStyle(servidor ? BXCor.perigoTexto : (ok ? BXCor.tinta : BXCor.cinza))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(texto), \(ok ? "atendido" : "pendente")")
    }

    private func salvar() async {
        guard pode else {
            if !confirmar.isEmpty, nova != confirmar { erroConfirmar = "As senhas novas não conferem." }
            return
        }
        erroGeral = nil
        problemasServidor = []
        salvando = true
        defer { salvando = false }
        do {
            try await BXAPI.shared.trocarSenha(atual: atual, nova: nova)
            atual = ""; nova = ""; confirmar = ""
            BXHaptica.tocar(.sucesso)
            fechar()
            sessao.sessaoRevogada(motivo: "Senha alterada. Entre de novo.")
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            BXHaptica.tocar(.erro)
            switch e.tipo {
            case .naoAutorizado:
                erroAtual = "Senha atual incorreta."
            case .validacao where !e.problemasSeguros.isEmpty:
                problemasServidor = e.problemasSeguros
            case .muitasTentativas:
                erroGeral = "Muitas tentativas. Aguarde um pouco e tente de novo."
            default:
                erroGeral = e.mensagemParaUsuario
            }
        }
    }
}
