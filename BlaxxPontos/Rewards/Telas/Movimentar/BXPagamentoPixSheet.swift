//
//  BXPagamentoPixSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Pagamento da compra por PIX (spec §5 G3 itens 3 e 4; web `comprar.html` sobreposição de QR e
//  `pagamento-pix.html`, fotos 23): gera a cobrança DE VERDADE (`POST /pix/charge`, D01) e só mostra
//  "O pagamento por PIX está indisponível no momento." quando a chamada falhar. QR + copia e cola +
//  "Expira em mm:ss" + polling a cada 4 s (pausado em segundo plano) → compra concluída.
//  Fechar com cobrança pendente pede confirmação. Brilho máximo enquanto o QR está na tela.
//  PIX aqui é só meio de pagamento da compra.
//

import SwiftUI

struct BXPagamentoPixSheet: View {
    let pedido: BXPedidoCompra

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var faseCena
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    enum Fase {
        case gerando
        case aguardando(BXCobrancaPix)
        case paga(BXCobrancaPix)
        case encerrada(BXCobrancaPix)
        case falhou(BXErro)
    }

    @State private var fase: Fase = .gerando
    @State private var pedidoAtual: BXPedidoCompra
    @State private var confirmarFechar = false
    @State private var simulando = false
    @State private var provedorMock = false
    @State private var tentativa = 0

    init(pedido: BXPedidoCompra) {
        self.pedido = pedido
        _pedidoAtual = State(initialValue: pedido)
    }

    private var pendente: BXCobrancaPix? {
        if case .aguardando(let c) = fase { return c }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BXCabecaFolha(cabeca) { pedirFechar() }
                conteudo
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: BXEspaco.colunaMax)
            .frame(maxWidth: .infinity)
        }
        .interactiveDismissDisabled(pendente != nil)
        .task(id: tentativa) { await gerar() }
        .task(id: pendente?.id) { await acompanhar() }
        .task { await conferirProvedor() }
        .alert("Fechar o pagamento?", isPresented: $confirmarFechar) {
            Button("Continuar pagando", role: .cancel) {}
            Button("Fechar") { dismiss() }
        } message: {
            Text(mensagemFechar)
        }
    }

    private var cabeca: String {
        switch fase {
        case .paga: return "Compra confirmada"
        default: return "Pagamento por PIX"
        }
    }

    private var mensagemFechar: String {
        let minutos = max(1, Int(((pendente?.segundosParaExpirar() ?? 0) + 59) / 60))
        return "A cobrança continua válida por \(minutos) min. Você pode reabrir pelo histórico de compras."
    }

    // MARK: Conteúdo por fase

    @ViewBuilder private var conteudo: some View {
        switch fase {
        case .gerando:
            VStack(spacing: 16) {
                BXCarregando("Gerando o código de pagamento…")
                BXEsqueleto(.bloco(altura: 260))
                BXEsqueleto(.bloco(altura: 120))
            }
            .frame(maxWidth: .infinity)
        case .aguardando(let c):
            aguardando(c)
        case .paga(let c):
            BXCompraConcluida(cobranca: c,
                              aoVerSaldo: { dismiss(); nav.ir(.carteira) },
                              aoComprarMais: { dismiss() })
        case .encerrada(let c):
            encerrada(c)
        case .falhou(let e):
            falhou(e)
        }
    }

    private func aguardando(_ c: BXCobrancaPix) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .center, spacing: 12) {
                BXStatus("Aguardando pagamento", .aviso)
                Text("Pague pelo app do seu banco")
                    .bxFonte(.h2).foregroundStyle(BXCor.tinta)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Escaneie o QR Code com o app do seu banco ou copie o código abaixo.")
                    .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            qr(c)
                .frame(maxWidth: .infinity)
                .bxBrilhoMaximo()

            if let codigo = c.brCode {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PIX copia e cola").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    Text(codigo)
                        .font(BXFonte.fonte(.recibo, tamanho: 12))
                        .foregroundStyle(BXCor.tinta)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .accessibilityLabel("Código copia e cola")
                    BXBotao("Copiar código", icone: .documento) {
                        BXCopiar.copiar(codigo, aviso: "Código copiado.", toast: toast)
                    }
                    .accessibilityAction(named: "Copiar código") {
                        BXCopiar.copiar(codigo, aviso: "Código copiado.", toast: toast)
                    }
                }
                .padding(16)
                .bxSuperficie(raio: BXRaio.lg, cor: BXCor.superficie2, borda: BXCor.linha)
            }

            BXRecibo {
                BXReciboLinha("Pacote", BXTextoCompra.rotuloPacote(c.pacote))
                BXReciboLinha("Valor", BXFormato.dinheiro(c.valor))
                if c.pontos > 0 {
                    BXReciboLinha("Pontos", BXFormato.pontos(c.pontos))
                }
                BXReciboLinha("Pagamento", "PIX")
                BXReciboTracejo()
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let s = c.segundosParaExpirar(agora: ctx.date)
                    BXReciboFaixa("Expira em", s.map(BXTextoCompra.contagem) ?? "—")
                }
                BXReciboNota("Os pontos entram na conta assim que o banco confirmar o pagamento. Esta tela se atualiza sozinha.")
            }

            #if DEBUG
            if provedorMock {
                BXBotao("Simular pagamento (demo)", estilo: .secundario, carregando: simulando) {
                    Task { await simular(c) }
                }
            }
            #endif

            BXBotao("Fechar", estilo: .secundario) { pedirFechar() }
        }
    }

    @ViewBuilder private func qr(_ c: BXCobrancaPix) -> some View {
        Group {
            #if canImport(UIKit)
            if let dados = c.qrImagem, let img = UIImage(data: dados) {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .accessibilityLabel("QR Code do pagamento")
            } else if let codigo = c.brCode {
                BXQRCode(codigo, lado: 240)
            } else {
                semCodigo
            }
            #else
            if let codigo = c.brCode { BXQRCode(codigo, lado: 240) } else { semCodigo }
            #endif
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous).strokeBorder(BXCor.linha, lineWidth: 1))
        .bxSombra(.leve)
    }

    private var semCodigo: some View {
        Text("O código ainda não chegou. Aguarde alguns segundos.")
            .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            .multilineTextAlignment(.center)
            .frame(width: 240, height: 240)
    }

    private func encerrada(_ c: BXCobrancaPix) -> some View {
        let recusada = c.status == .recusada
        return VStack(alignment: .center, spacing: 14) {
            BXIcone(.relogio, tamanho: .marca)
            Text(recusada ? "O pagamento não foi aprovado." : "Este código expirou.")
                .bxFonte(.h2).foregroundStyle(BXCor.tinta)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(recusada ? "Nenhum valor foi cobrado. Gere um novo código para tentar de novo."
                          : "O prazo para pagar terminou e nenhum valor foi cobrado. Gere um novo código para continuar.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            BXBotao("Gerar novo código") {
                pedidoAtual = pedidoAtual.novoPedido
                tentativa += 1
            }
            .padding(.top, 6)
            BXBotao("Fechar", estilo: .secundario) { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
    }

    private func falhou(_ e: BXErro) -> some View {
        let indisponivel = e.tipo == .pagamentoIndisponivel
        return VStack(alignment: .center, spacing: 14) {
            BXIcone(.alerta, tamanho: .marca)
            Text(indisponivel ? "Pagamento indisponível." : "Não foi possível gerar o pagamento.")
                .bxFonte(.h2).foregroundStyle(BXCor.tinta)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(e.mensagemParaUsuario)
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if indisponivel {
                Text("Nenhum valor foi cobrado. Tente de novo mais tarde.")
                    .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                    .multilineTextAlignment(.center)
            }
            BXBotao("Tentar de novo", estilo: .secundario) { tentativa += 1 }
                .padding(.top, 6)
            BXBotao("Voltar", estilo: .preto) { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
    }

    // MARK: Rede

    private func gerar() async {
        fase = .gerando
        do {
            let c: BXCobrancaPix
            switch pedidoAtual {
            case .pacote(let chave, _): c = try await BXAPI.shared.criarCobrancaPix(pacote: chave)
            case .valor(let v): c = try await BXAPI.shared.criarCobrancaPix(valor: v)
            case .reabrir(let antiga): c = try await BXAPI.shared.cobrancaPix(id: antiga.id)
            }
            aplicar(c)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            switch e.tipo {
            case .emailNaoVerificado:
                dismiss()
                nav.exigirVerificacaoEmail()
            case .sessaoExpirada:
                dismiss()
            default:
                BXHaptica.tocar(.erro)
                fase = .falhou(e)
            }
        }
    }

    /// Polling a cada 4 s enquanto a cobrança está em aberto. Em segundo plano não consulta; ao voltar,
    /// a próxima volta do laço consulta de novo. Expirou pelo relógio → encerrada.
    private func acompanhar() async {
        guard let id = pendente?.id else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            guard faseCena == .active else { continue }
            do {
                aplicar(try await BXAPI.shared.cobrancaPix(id: id))
            } catch {
                // Falha passageira de rede no polling: tenta de novo na próxima volta.
                if let c = pendente, c.segundosParaExpirar() == 0 { fase = .encerrada(c) }
            }
            if pendente == nil { return }
        }
    }

    private func aplicar(_ c: BXCobrancaPix) {
        switch c.status {
        case .paga:
            withAnimation(BXMovimento.mola) { fase = .paga(c) }
            BXHaptica.tocar(.sucesso)
            Task { await sessao.recarregarCarteira() }
        case .pendente, .aguardandoConfirmacao:
            if let s = c.segundosParaExpirar(), s == 0 {
                fase = .encerrada(c)
            } else {
                fase = .aguardando(c)
            }
        case .expirada, .recusada, .estornada, .desconhecido:
            fase = .encerrada(c)
        }
    }

    private func conferirProvedor() async {
        #if DEBUG
        provedorMock = (try? await BXAPI.shared.provedorPix().ehMock) ?? false
        #endif
    }

    #if DEBUG
    /// Só com provedor de testes (`is_mock`): `POST /pix/simulate-payment` não existe em produção.
    private func simular(_ c: BXCobrancaPix) async {
        simulando = true
        defer { simulando = false }
        do {
            try await BXAPI.shared.simularPagamento(cobranca: c.id)
            aplicar(try await BXAPI.shared.cobrancaPix(id: c.id))
        } catch {
            toast.mostrar(BXErro.de(error).mensagemParaUsuario, .erro)
        }
    }
    #endif

    private func pedirFechar() {
        if pendente != nil { confirmarFechar = true } else { dismiss() }
    }
}
