//
//  BXComprarTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Comprar pontos (spec §5 G3 item 1; web `comprar.html`/`comprar-pontos.html`, fotos 20/20b e o bloco de
//  pacotes da home, foto 01-04): cabeçalho · 4 bilhetes de `GET /pix/packages` · recibo "EXTRATO DA SUA
//  COMPRA" que se reescreve ao tocar num bilhete · "Valor livre" · "Histórico de compras" · aviso legal.
//  Não gera cobrança ao abrir (o web gera com `?pkg=`): só ao tocar em "COMPRAR N PTS →".
//  Sem % de bônus (D07), sem régua de valor do ponto, sem prévia de pontos no valor livre.
//

import SwiftUI

struct BXComprarTela: View {
    let pacoteInicial: String?

    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav

    @State private var carga: BXCarga<[BXPacote]> = .carregando
    @State private var escolhido: String
    @State private var folha: BXFolhaCompra?
    @State private var abriuSubtela = false

    init(pacoteInicial: String?) {
        self.pacoteInicial = pacoteInicial
        _escolhido = State(initialValue: pacoteInicial ?? "plus")
    }

    var body: some View {
        BXColunaMovimentar(atualizar: { await carregar(recarga: true) }) {
            BXCabecalhoPagina(eyebrow: "Comprar pontos",
                              titulo: "Escolha o seu ponto de partida.",
                              lead: "Pacotes sem mensalidade. Os pontos entram na conta depois da confirmação do pagamento.")
                .padding(.bottom, 28)

            conteudo

            VStack(alignment: .leading, spacing: 14) {
                BXLinkSeta("Valor livre") { abrirValorLivre() }
                BXLinkSeta("Histórico de compras") { nav.ir(.historicoCompras) }
            }
            .padding(.top, 28)
            .id("links")

            BXAvisoLegalPontos()
                .padding(.top, 28)
                .id("fim")
        }
        .task { await carregar(recarga: false) }
        .sheet(item: $folha) { f in
            switch f {
            case .valorLivre:
                BXValorLivreSheet { valor in folha = .pagamento(.valor(valor)) }
                    .bxFolhaMovimentar([.medium, .large])
            case .pagamento(let pedido):
                BXPagamentoPixSheet(pedido: pedido)
                    .bxFolhaMovimentar([.large])
            }
        }
    }

    // MARK: Conteúdo

    @ViewBuilder private var conteudo: some View {
        switch carga {
        case .ocioso, .carregando:
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in BXEsqueleto(.bilhete) }
                BXEsqueleto(.bloco(altura: 360)).padding(.top, 16)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Carregando pacotes")
        case .vazio:
            BXEstadoVazio(icone: .comprar, titulo: "Nenhum pacote disponível agora.",
                          texto: "Tente de novo em alguns minutos ou use o valor livre.",
                          acao: (titulo: "Valor livre", executar: { abrirValorLivre() }))
        case .erro(let e):
            BXEstadoErro(e) { await carregar(recarga: true) }
        case .pronto(let pacotes):
            VStack(spacing: 12) {
                ForEach(pacotes) { p in
                    BXBilhetePacote(pacote: p, selecionado: p.chave == escolhido) {
                        withAnimation(BXMovimento.mola) { escolhido = p.chave }
                    }
                }
            }
            .id("pacotes")
            if let p = pacotes.first(where: { $0.chave == escolhido }) ?? pacotes.first {
                recibo(p)
                    .padding(.top, 28)
                    .id("recibo")
            }
        }
    }

    private func recibo(_ p: BXPacote) -> some View {
        BXRecibo(cabeca: "Extrato da sua compra",
                 acao: .init(titulo: "Comprar \(BXFormato.pontos(p.pontos)) pts →") { comprar(p) }) {
            BXReciboTracejo()
            BXReciboLinha("Pacote", p.rotulo)
            BXReciboLinha("Pontos", BXFormato.pontos(p.pontos))
            // D02: com cartão aprovado, "Cartão ou PIX". Hoje só PIX (meio de pagamento da compra).
            BXReciboLinha("Pagamento", BXRecursos.compraCartao ? "Cartão ou PIX" : "PIX")
            BXReciboLinha("Mensalidade", "nenhuma")
            BXReciboTracejo()
            BXReciboTotal("Total", BXFormato.dinheiro(p.preco))
            BXReciboFaixa("Pontos na conta", BXFormato.pontos(p.pontos))
            BXReciboNota("Os pontos do pacote já incluem o bônus. Pontos são créditos promocionais de uso restrito na plataforma.")
            BXReciboVia()
        }
        .animation(BXMovimento.mola, value: p.chave)
    }

    // MARK: Ações

    private func comprar(_ p: BXPacote) {
        guard sessao.logado else { nav.pedirEntrada(depois: .comprar(pacote: p.chave)); return }
        folha = .pagamento(.pacote(chave: p.chave, rotulo: p.rotulo))
    }

    private func abrirValorLivre() {
        guard sessao.logado else { nav.pedirEntrada(depois: .comprar(pacote: nil)); return }
        folha = .valorLivre
    }

    private func carregar(recarga: Bool) async {
        if !recarga, carga.valor != nil { return }
        if carga.valor == nil { carga = .carregando }
        do {
            let pacotes = BXPacote.ordenar(try await BXAPI.shared.pacotes())
            guard !pacotes.isEmpty else { carga = .vazio; return }
            if !pacotes.contains(where: { $0.chave == escolhido }) {
                escolhido = pacotes.first(where: { $0.chave == "plus" })?.chave ?? pacotes[0].chave
            }
            carga = .pronto(pacotes)
            abrirSubtelaDemo(pacotes)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            // Recarga com conteúdo na tela mantém o conteúdo (o erro some com o indicador do refreshable).
            if recarga, carga.valor != nil { return }
            carga = .erro(BXErro.de(error))
        }
    }

    /// `-BXSubtela valorLivre | pix | pago` (só tem efeito em DEBUG; em Release `BXDemo.subtela` é nil).
    private func abrirSubtelaDemo(_ pacotes: [BXPacote]) {
        guard !abriuSubtela, let sub = BXDemo.subtela else { return }
        abriuSubtela = true
        switch sub {
        case "valorLivre":
            folha = .valorLivre
        case "pix", "pago":
            if let p = pacotes.first(where: { $0.chave == escolhido }) {
                folha = .pagamento(.pacote(chave: p.chave, rotulo: p.rotulo))
            }
        default:
            break
        }
    }
}
