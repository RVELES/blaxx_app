//
//  BXEnviarTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Enviar pontos (spec §5 G3 item 8; web `enviar.html`, fotos 26b, e o fluxo `enviar-pontos` →
//  `confirmar-envio` → `envio-concluido`, fotos 26/27/28): Para (e-mail, CPF ou Cartão BlaXx, com "Ler QR"),
//  pontos com atalhos 500 · 1.000 · 5.000 · 10.000 · Tudo, mensagem (140), senha digitada na hora,
//  recibo de resumo sem linha de custo do envio, validações locais, confirmação em folha `.medium` e envio com
//  `Idempotency-Key` da intenção. Trata 400 senha (inline, não desloga), 401 2FA (código TOTP),
//  409 envio repetido, 429 sondagem de destinatários e 403 e-mail não verificado.
//  A senha vive só em `@State` e é apagada ao sair da tela e depois de cada envio.
//

import SwiftUI

struct BXEnviarTela: View {
    let paraInicial: String?

    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    @State private var para: String
    @State private var pontosTexto = ""
    @State private var mensagem = ""
    @State private var senha = ""

    @State private var erroPara: String?
    @State private var erroPontos: String?
    @State private var erroSenha: String?

    @State private var confirmando = false
    @State private var enviando = false
    @State private var erroFolha: String?
    @State private var pedirMFA = false
    @State private var codigoMFA = ""
    @State private var chave: BXChaveIdempotencia?
    @State private var duplicado = false

    @State private var concluido: BXEnvio?
    @State private var paraConcluido = ""
    @State private var lendoQR = false
    @State private var abriuSubtela = false

    init(paraInicial: String?) {
        self.paraInicial = paraInicial
        _para = State(initialValue: paraInicial ?? "")
    }

    private var pontos: Int? { Int(pontosTexto.filter(\.isNumber)) }
    private var saldo: Int? { sessao.carteira?.saldo }

    var body: some View {
        Group {
            if let envio = concluido {
                BXColunaMovimentar {
                    BXEnvioConcluido(envio: envio, para: paraConcluido,
                                     aoEnviarMais: { reiniciar() },
                                     aoVerExtrato: { nav.ir(.extrato()) })
                }
                .transition(.opacity)
            } else {
                formulario
                    .transition(.opacity)
            }
        }
        .animation(BXMovimento.ease, value: concluido?.id)
        .onDisappear { senha = ""; codigoMFA = "" }
        .onChange(of: para) { _, _ in erroPara = nil; chave = nil }
        .onChange(of: pontosTexto) { _, novo in
            let m = BXFormato.mascaraPontos(novo)
            if m != novo { pontosTexto = m }
            erroPontos = nil
            chave = nil
        }
        .onChange(of: mensagem) { _, _ in chave = nil }
        .onChange(of: senha) { _, _ in erroSenha = nil }
        .sheet(isPresented: $confirmando, onDismiss: { codigoMFA = "" }) {
            BXConfirmarEnvioSheet(para: para.trimmingCharacters(in: .whitespacesAndNewlines),
                                  pontos: pontos ?? 0,
                                  mensagem: mensagemLimpa,
                                  saldo: saldo,
                                  pedirMFA: pedirMFA,
                                  codigo: $codigoMFA,
                                  enviando: enviando,
                                  erro: erroFolha,
                                  aoConfirmar: { Task { await enviar() } },
                                  aoEditar: { confirmando = false })
                .bxFolhaMovimentar(pedirMFA ? [.large] : [.medium, .large])
                .interactiveDismissDisabled(enviando)
        }
        .alert("Parece um envio repetido.", isPresented: $duplicado) {
            Button("Cancelar", role: .cancel) {}
            Button("Enviar de novo") {
                chave = BXChaveIdempotencia()
                Task { await enviar() }
            }
        } message: {
            Text("Você enviou a mesma quantidade para a mesma pessoa há pouco. Enviar de novo?")
        }
        #if os(iOS)
        .sheet(isPresented: $lendoQR) {
            BXLeitorQRFolha { lido in
                lendoQR = false
                receberQR(lido)
            }
        }
        #endif
        .task { abrirSubtelaDemo() }
    }

    private var mensagemLimpa: String? {
        let m = mensagem.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? nil : m
    }

    // MARK: Formulário

    private var formulario: some View {
        BXColunaMovimentar {
            BXCabecalhoPagina(eyebrow: "Enviar pontos",
                              titulo: "Pontos para quem você quiser.",
                              lead: "Entre contas BlaXx. O envio pode ser desfeito em até 60 segundos.")
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 22) {
                campoPara
                campoPontos
                BXCampo("Mensagem (opcional)", texto: $mensagem, tipo: .mensagem(limite: 140),
                        placeholder: "Um presente para você")
                BXCampo("Sua senha (confirmação)", texto: $senha, tipo: .senha,
                        placeholder: "Senha da sua conta", erro: erroSenha)
            }
            .padding(BXEspaco.cartao)
            .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha, sombra: .padrao)
            .id("formulario")

            resumo
                .padding(.top, 28)
                .id("resumo")

            Text("Mínimo de 100 pts por envio. O envio fica em processamento por 60 segundos e pode ser desfeito nesse prazo.")
                .bxFonte(.rotulo)
                .foregroundStyle(BXCor.cinza)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
        }
    }

    private var campoPara: some View {
        VStack(alignment: .leading, spacing: 10) {
            BXCampo("Enviar para", texto: $para, tipo: .email,
                    placeholder: "E-mail, CPF ou Cartão BlaXx", erro: erroPara)
            if BXLeitorQR.disponivel {
                BXBotao("Ler QR de um Cartão BlaXx", estilo: .secundario, icone: .cartao) { lendoQR = true }
            }
        }
    }

    private var campoPontos: some View {
        let forma = RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Pontos a enviar").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                .accessibilityHidden(true)
            TextField("Pontos a enviar", text: $pontosTexto, prompt: Text("0").foregroundStyle(BXCor.cinza.opacity(0.6)))
                .bxFonte(.numeroGrande)
                .foregroundStyle(BXCor.tinta)
                .tint(BXCor.tinta)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .padding(.horizontal, 16)
                .frame(minHeight: 68)
                .background(BXCor.superficie, in: forma)
                .overlay(forma.strokeBorder(erroPontos != nil ? BXCor.perigoTexto : BXCor.linha, lineWidth: 1))
                .accessibilityLabel("Pontos a enviar")
            if let erroPontos {
                Text(erroPontos).bxFonte(.legenda).foregroundStyle(BXCor.perigoTexto)
            } else if let saldo {
                Text("Seus pontos: \(BXFormato.pontosComUnidade(saldo))").bxFonte(.legenda).foregroundStyle(BXCor.cinza)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach([500, 1_000, 5_000, 10_000], id: \.self) { n in
                    BXPilula(BXFormato.pontos(n), ativa: pontos == n, estilo: .conta) {
                        pontosTexto = BXFormato.pontos(n)
                    }
                }
                if let saldo, saldo > 0 {
                    BXPilula("Tudo", ativa: pontos == saldo, estilo: .conta) {
                        pontosTexto = BXFormato.pontos(saldo)
                    }
                }
            }
        }
    }

    private var resumo: some View {
        let p = pontos ?? 0
        let destino = para.trimmingCharacters(in: .whitespacesAndNewlines)
        return BXRecibo(cabeca: "Resumo do envio",
                        acao: .init(titulo: "Revisar envio →") { revisar() }) {
            BXReciboTracejo()
            BXReciboLinha("Para", destino.isEmpty ? "—" : destino)
            BXReciboLinha("Pontos", p > 0 ? BXFormato.pontos(p) : "—")
            if let m = mensagemLimpa {
                BXReciboLinha("Mensagem", m)
            }
            BXReciboTracejo()
            BXReciboLinha("Seus pontos", saldo.map(BXFormato.pontos) ?? "—")
            BXReciboFaixa("Após o envio", saldo.map { BXFormato.pontos(max(0, $0 - p)) } ?? "—")
            BXReciboNota("Quem recebe vê os pontos depois de 60 segundos. Até lá, você pode desfazer o envio.")
        }
    }

    // MARK: Ações

    private func revisar() {
        let destino = para.trimmingCharacters(in: .whitespacesAndNewlines)
        var ok = true
        if destino.isEmpty {
            erroPara = "Informe o e-mail, CPF ou Cartão BlaXx de quem vai receber."; ok = false
        } else if ehVoceMesmo(destino) {
            erroPara = "Você não pode enviar pontos para você mesmo."; ok = false
        }
        if let p = pontos, p >= 100 {
            if let saldo, p > saldo { erroPontos = "Pontos insuficientes."; ok = false }
        } else {
            erroPontos = "O envio mínimo é de 100 pts."; ok = false
        }
        if senha.isEmpty { erroSenha = "Confirme com sua senha."; ok = false }
        guard ok else { BXHaptica.tocar(.aviso); return }
        if chave == nil { chave = BXChaveIdempotencia() }
        erroFolha = nil
        pedirMFA = false
        codigoMFA = ""
        confirmando = true
    }

    private func ehVoceMesmo(_ destino: String) -> Bool {
        guard let u = sessao.usuario else { return false }
        let d = destino.lowercased()
        if d == u.email.lowercased() { return true }
        let hex = d.uppercased().filter(\.isHexDigit)
        if d.filter({ !$0.isWhitespace }).count == 8, hex.count == 8, hex == u.cartaoID { return true }
        return false
    }

    private func enviar() async {
        guard let p = pontos, !enviando else { return }
        if chave == nil { chave = BXChaveIdempotencia() }
        guard let chaveAtual = chave else { return }
        enviando = true
        erroFolha = nil
        defer { enviando = false }
        let pedido = BXPedidoEnvio(para: para, pontos: p, senha: senha, mensagem: mensagemLimpa,
                                   codigoMFA: pedirMFA ? codigoMFA : nil)
        do {
            let envio = try await BXAPI.shared.enviar(pedido, chave: chaveAtual)
            senha = ""
            codigoMFA = ""
            chave = nil
            confirmando = false
            paraConcluido = para.trimmingCharacters(in: .whitespacesAndNewlines)
            BXHaptica.tocar(.sucesso)
            concluido = envio
            Task { await sessao.recarregarCarteira() }
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            tratar(BXErro.de(error))
        }
    }

    private func tratar(_ e: BXErro) {
        switch e.tipo {
        case .mfaNecessario:
            // Mesma intenção: a chave continua.
            if pedirMFA && !codigoMFA.isEmpty {
                erroFolha = "Código inválido ou expirado. Confira no seu app autenticador e tente de novo."
                codigoMFA = ""
            }
            pedirMFA = true
            BXHaptica.tocar(.aviso)
        case .conflito:
            chave = nil
            confirmando = false
            BXHaptica.tocar(.aviso)
            duplicado = true
        case .muitasTentativas:
            chave = nil
            erroFolha = e.codigo == "RECIPIENT_PROBE_BLOCKED"
                ? "Muitas tentativas com destinatários diferentes. Aguarde um pouco antes de tentar de novo."
                : e.mensagemParaUsuario
            BXHaptica.tocar(.erro)
        case .emailNaoVerificado:
            chave = nil
            confirmando = false
            nav.exigirVerificacaoEmail()
        case .sessaoExpirada:
            confirmando = false
        case .semConexao, .tempoEsgotado:
            // Sem resposta definitiva: mantém a chave para o "Confirmar" de novo não duplicar o envio.
            erroFolha = e.mensagemParaUsuario
            BXHaptica.tocar(.erro)
        case .saldoInsuficiente:
            chave = nil
            confirmando = false
            erroPontos = "Pontos insuficientes."
            BXHaptica.tocar(.erro)
        default:
            chave = nil
            let servidor = (e.mensagemServidorSegura ?? "").lowercased()
            if servidor.contains("senha") {
                confirmando = false
                senha = ""
                erroSenha = "Senha incorreta. Digite de novo."
            } else if servidor.contains("destinat") || servidor.contains("si mesmo") {
                confirmando = false
                erroPara = servidor.contains("si mesmo") ? "Você não pode enviar pontos para você mesmo."
                                                         : "Não encontramos uma conta BlaXx com esses dados."
            } else if servidor.contains("insuficiente") {
                confirmando = false
                erroPontos = "Pontos insuficientes."
            } else {
                erroFolha = e.mensagemParaUsuario
            }
            BXHaptica.tocar(.erro)
        }
    }

    private func reiniciar() {
        concluido = nil
        para = ""
        pontosTexto = ""
        mensagem = ""
        senha = ""
        chave = nil
    }

    private func receberQR(_ lido: String) {
        if let cartao = BXLeitorQR.cartao(de: lido) {
            para = cartao
            BXHaptica.tocar(.leve)
            toast.mostrar("Cartão BlaXx \(BXFormato.cartao(cartao)) lido.", .sucesso)
        } else {
            BXHaptica.tocar(.aviso)
            toast.mostrar("Este QR Code não é de um Cartão BlaXx.", .aviso)
        }
    }

    /// `-BXSubtela confirmar | concluido` (só DEBUG com `-BXDemo`; em Release `BXDemo.subtela` é nil).
    private func abrirSubtelaDemo() {
        #if DEBUG
        guard !abriuSubtela, BXDemo.ativo, let sub = BXDemo.subtela, sub == "confirmar" || sub == "concluido" else { return }
        abriuSubtela = true
        para = "amigo@exemplo.test"
        pontosTexto = "1.000"
        mensagem = "Feliz aniversário!"
        senha = "demo"
        if sub == "confirmar" {
            chave = BXChaveIdempotencia()
            confirmando = true
        } else {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                chave = BXChaveIdempotencia()
                await enviar()
            }
        }
        #endif
    }
}
