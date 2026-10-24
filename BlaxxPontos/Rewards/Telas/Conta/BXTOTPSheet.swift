//
//  BXTOTPSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Verificação em duas etapas por aplicativo autenticador (TOTP).
//  Ativar: POST /auth/mfa/setup → QR do `otpauth://` + chave copiável + "Abrir no app autenticador" →
//          código de 6 dígitos → POST /auth/mfa/enable.
//  Desativar: senha + código do app → POST /auth/mfa/disable.
//

import SwiftUI

struct BXTOTPSheet: View {
    enum Modo { case ativar, desativar }

    let modo: Modo
    var aoConcluir: () -> Void = {}

    @Environment(BXSessao.self) private var sessao
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.dismiss) private var fechar
    @Environment(\.openURL) private var abrirURL

    @State private var preparo: BXCarga<(segredo: String, uri: String)> = .carregando
    @State private var codigo = ""
    @State private var senha = ""
    @State private var enviando = false
    @State private var erro: String?

    var body: some View {
        BXCorpoFolhaConta {
            BXCabecalhoFolhaConta(rotulo: "Segurança · aplicativo autenticador",
                                  titulo: modo == .ativar ? "Ativar verificação em duas etapas." : "Desativar o aplicativo autenticador.") { fechar() }
            if modo == .ativar { ativar } else { desativar }
        }
        .interactiveDismissDisabled(enviando)
        .task { if modo == .ativar { await preparar() } }
        .onDisappear { senha = ""; codigo = "" }
    }

    // MARK: Ativar

    @ViewBuilder private var ativar: some View {
        switch preparo {
        case .ocioso, .carregando:
            VStack(spacing: 14) {
                BXEsqueleto(.bloco(altura: 240))
                BXEsqueleto(.linha(largura: 220))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preparando")
        case .erro(let e):
            BXEstadoErro(e) { await preparar() }
        case .vazio:
            EmptyView()
        case .pronto(let p):
            passo("1", "Abra o seu aplicativo autenticador (Google Authenticator, Microsoft Authenticator, 1Password ou o de Senhas do iPhone) e adicione a BlaXx.")
            VStack(spacing: 14) {
                BXQRCode(p.uri, lado: 200)
                    .padding(14)
                    .background(BXCor.superficie, in: RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous).strokeBorder(BXCor.linha, lineWidth: 1))
                    .accessibilityLabel("QR Code para o aplicativo autenticador")
                BXBotao("Abrir no app autenticador", estilo: .primario, icone: .seguranca) { abrirAutenticador(p.uri) }
                VStack(spacing: 6) {
                    Text("Ou digite a chave").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    Text(agrupar(p.segredo))
                        .font(BXFonte.fonte(.recibo, tamanho: 17))
                        .foregroundStyle(BXCor.tinta)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .accessibilityLabel("Chave \(p.segredo.map { String($0) }.joined(separator: " "))")
                    BXBotao("Copiar chave", estilo: .secundario, larguraTotal: false) {
                        BXCopiar.copiar(p.segredo, aviso: "Chave copiada.", toast: toast)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            passo("2", "Digite o código de 6 dígitos que o aplicativo mostra.")
            BXCampoCodigo(codigo: $codigo)
                .onChange(of: codigo) { _, novo in
                    erro = nil
                    if novo.count == 6 { Task { await ligar() } }
                }
            if let erro { BXAvisoErroConta(texto: erro) }
            BXBotao("Ativar verificação", estilo: .preto, carregando: enviando) { Task { await ligar() } }
                .disabled(codigo.count != 6)
                .opacity(codigo.count == 6 || enviando ? 1 : 0.45)
            BXNotaConta(texto: "Depois de ativar, pedimos o código do aplicativo ao entrar e em envios de valores altos. Guarde a chave em lugar seguro.")
        }
    }

    // MARK: Desativar

    @ViewBuilder private var desativar: some View {
        Text("Sem a verificação em duas etapas, a sua conta fica protegida só pela senha. Para confirmar, informe a senha e o código atual do aplicativo.")
            .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            .fixedSize(horizontal: false, vertical: true)
        BXCampo("Sua senha", texto: $senha, tipo: .senha)
            .onChange(of: senha) { _, _ in erro = nil }
        VStack(alignment: .leading, spacing: 8) {
            Text("Código do aplicativo").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            BXCampoCodigo(codigo: $codigo)
                .onChange(of: codigo) { _, _ in erro = nil }
        }
        if let erro { BXAvisoErroConta(texto: erro) }
        BXBotao("Desativar", estilo: .perigo, carregando: enviando) { Task { await desligar() } }
            .disabled(senha.isEmpty || codigo.count != 6)
            .opacity(!senha.isEmpty && codigo.count == 6 || enviando ? 1 : 0.45)
    }

    // MARK: Peças

    private func passo(_ n: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n).bxFonte(.monoForte).foregroundStyle(BXCor.tinta)
                .frame(width: 28, height: 28)
                .background(BXCor.neon, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Passo \(n). \(texto)")
    }

    private func agrupar(_ s: String) -> String {
        stride(from: 0, to: s.count, by: 4).map { i in
            let a = s.index(s.startIndex, offsetBy: i)
            let b = s.index(a, offsetBy: min(4, s.count - i))
            return String(s[a..<b])
        }.joined(separator: " ")
    }

    private func abrirAutenticador(_ uri: String) {
        guard let url = URL(string: uri) else { return }
        abrirURL(url) { aceito in
            if !aceito {
                toast.mostrar("Nenhum app autenticador encontrado neste aparelho. Use o QR Code ou a chave.", .aviso)
            }
        }
    }

    // MARK: Rede

    private func preparar() async {
        preparo = .carregando
        do {
            let r = try await BXAPI.shared.prepararTOTP()
            preparo = .pronto(r)
            if BXDemo.subtela == "totp-codigo" { codigo = "12345" }
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            preparo = .erro(BXErro.de(error))
        }
    }

    private func ligar() async {
        guard codigo.count == 6, !enviando else { return }
        enviando = true
        defer { enviando = false }
        do {
            try await BXAPI.shared.ligarTOTP(codigo: codigo)
            BXHaptica.tocar(.sucesso)
            await sessao.recarregarUsuario()
            toast.mostrar("Verificação em duas etapas ativada.", .sucesso)
            aoConcluir()
            fechar()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            BXHaptica.tocar(.erro)
            let e = BXErro.de(error)
            codigo = ""
            erro = e.tipo == .naoAutorizado ? "Código inválido. Confira no aplicativo autenticador e digite o código atual." : e.mensagemParaUsuario
        }
    }

    private func desligar() async {
        enviando = true
        defer { enviando = false }
        do {
            try await BXAPI.shared.desligarTOTP(senha: senha, codigo: codigo)
            senha = ""
            BXHaptica.tocar(.sucesso)
            await sessao.recarregarUsuario()
            toast.mostrar("Verificação em duas etapas desativada.", .info)
            aoConcluir()
            fechar()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            BXHaptica.tocar(.erro)
            let e = BXErro.de(error)
            codigo = ""
            erro = e.mensagemServidorSegura ?? e.mensagemParaUsuario
        }
    }
}
