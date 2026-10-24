//
//  BXLancamentoSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G2 (Saldo)
//
//  Detalhe do lançamento (sheet [.medium, .large]): recibo "COMPROVANTE" com Tipo, Status, Data e hora,
//  Referência (copiar) e a faixa PONTOS. Envio pendente criado há menos de 60 s: "Desfazer envio (Ns)"
//  → POST /transfer/<reference>/cancel → recarrega a carteira. Compartilhar o comprovante como imagem.
//  O conteúdo vem só de GET /wallet/transactions (a página detalhe-transacao.html do web é fixa).
//

import SwiftUI

struct BXLancamentoSheet: View {
    let lancamento: BXLancamento
    /// Chamado depois de desfazer o envio (a lista recarrega).
    var aoDesfazer: () async -> Void = {}

    @Environment(BXSessao.self) private var sessao
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.dismiss) private var fechar
    @State private var desfazendo = false
    @State private var desfeito = false
    @State private var erro: String?
    @State private var imagem: Image?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    BXIcone(lancamento.ehEntrada ? .setaCima : .setaBaixo, tamanho: .padrao)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Movimento").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                        Text(lancamento.rotulo).bxFonte(.h2).foregroundStyle(BXCor.tinta)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                comprovante
                    .contextMenu {
                        if let r = lancamento.referencia {
                            Button("Copiar comprovante") { BXCopiar.copiar(r, aviso: "Comprovante copiado.", toast: toast) }
                        }
                    }
                acoes
            }
            .padding(.horizontal, BXEspaco.margem)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: BXEspaco.colunaMax)
            .frame(maxWidth: .infinity)
        }
        .background(BXCor.chao, in: Rectangle())
        .task { imagem = BXCompartilharImagem.imagem(de: comprovante) }
    }

    // MARK: recibo

    private var comprovante: some View {
        BXRecibo(cabeca: "Comprovante") {
            BXReciboLinha("Tipo", lancamento.rotulo)
            BXReciboLinha("Status", desfeito ? "Desfeito" : BXLinhaLancamento.rotuloStatus(lancamento))
            BXReciboLinha("Data", BXFormato.data(lancamento.criadoEm))
            BXReciboLinha("Hora", BXFormato.hora(lancamento.criadoEm))
            if let r = lancamento.referencia {
                BXReciboLinha("Referência", r)
            }
            if let d = lancamento.detalhe {
                BXReciboNota(d)
            }
            BXReciboTracejo()
            BXReciboFaixa("Pontos", BXFormato.pontosSinal(lancamento.pontos))
            BXReciboVia()
        }
    }

    // MARK: ações

    @ViewBuilder private var acoes: some View {
        VStack(spacing: 12) {
            if !desfeito && lancamento.envioDesfazivel() {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let resta = max(0, 60 - Int(ctx.date.timeIntervalSince(lancamento.criadoEm)))
                    if resta > 0 {
                        BXBotao("Desfazer envio (\(resta) s)", estilo: .preto, carregando: desfazendo) {
                            Task { await desfazer() }
                        }
                        .accessibilityLabel("Desfazer envio, \(resta) segundos restantes")
                    } else {
                        Text("A janela para desfazer terminou. O envio será efetivado.")
                            .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    }
                }
            }
            if let erro {
                Text(erro).bxFonte(.corpo).foregroundStyle(BXCor.perigoTexto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let r = lancamento.referencia {
                BXBotao("Copiar referência", estilo: .secundario, icone: .documento) {
                    BXCopiar.copiar(r, aviso: "Referência copiada.", toast: toast)
                }
            }
            if let imagem {
                ShareLink(item: imagem, preview: SharePreview("Comprovante BlaXx", image: imagem)) {
                    HStack(spacing: 10) {
                        BXIcone(.enviar, tamanho: .livre(lado: 26, raio: 7))
                        Text("Compartilhar comprovante").bxFonte(.botao)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BXEstiloBotao(estilo: .secundario))
            }
        }
    }

    private func desfazer() async {
        guard let id = lancamento.referencia else { return }
        desfazendo = true
        erro = nil
        defer { desfazendo = false }
        do {
            _ = try await BXAPI.shared.cancelarEnvio(id: id)
            desfeito = true
            BXHaptica.tocar(.sucesso)
            toast.mostrar("Envio desfeito. Os pontos voltaram para a sua conta.", .sucesso)
            await sessao.recarregarCarteira()
            await aoDesfazer()
            fechar()
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            BXHaptica.tocar(.erro)
            erro = e.mensagemServidorSegura ?? e.mensagemParaUsuario
        }
    }
}

extension View {
    /// Apresenta o detalhe do lançamento com os detents da spec (§3.1.6).
    func bxSheetLancamento(_ item: Binding<BXLancamento?>, aoDesfazer: @escaping () async -> Void) -> some View {
        sheet(item: item) { l in
            BXLancamentoSheet(lancamento: l, aoDesfazer: aoDesfazer)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(24)
                .presentationBackground(BXCor.chao)
                .presentationDragIndicator(.visible)
        }
    }
}
