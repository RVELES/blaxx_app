//
//  BXHistoricoComprasTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Histórico de compras (spec §5 G3 item 7; o web não tem página): `GET /pix/my-charges` agrupado por dia,
//  cada compra com pacote, valor da cobrança, pontos creditados e status. Cobrança ainda em aberto reabre a
//  folha de pagamento com o QR. Cartão (D02) entra aqui só quando `BXRecursos.compraCartao` for ligado.
//

import SwiftUI

struct BXHistoricoComprasTela: View {
    @Environment(BXNavegacao.self) private var nav
    @State private var carga: BXCarga<[BXCobrancaPix]> = .carregando
    @State private var reabrir: BXPedidoCompra?

    var body: some View {
        BXColunaMovimentar(atualizar: { await carregar(recarga: true) }) {
            BXCabecalhoPagina(eyebrow: "Histórico de compras",
                              titulo: "Suas compras de pontos.",
                              lead: "Cada pagamento e o status dele. Um código ainda válido pode ser reaberto aqui.")
                .padding(.bottom, 24)

            BXConteudo(carga,
                       vazio: BXEstadoVazio(icone: .comprar, titulo: "Nenhuma compra ainda.",
                                            texto: "Os pacotes não têm mensalidade.",
                                            acao: (titulo: "Comprar pontos", executar: { nav.ir(.comprar()) })),
                       tentarDeNovo: { await carregar(recarga: true) }) {
                VStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { _ in BXEsqueleto(.linhaExtrato) }
                }
                .padding(16)
                .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
            } pronto: { itens in
                lista(itens)
            }

            BXLinkSeta("Comprar pontos") { nav.ir(.comprar()) }
                .padding(.top, 28)
        }
        .task { await carregar(recarga: false) }
        .sheet(item: $reabrir, onDismiss: { Task { await carregar(recarga: true) } }) { pedido in
            BXPagamentoPixSheet(pedido: pedido)
                .bxFolhaMovimentar([.large])
        }
    }

    private func lista(_ itens: [BXCobrancaPix]) -> some View {
        let grupos = BXFormato.agruparPorDia(itens, data: \.dataReferencia)
        return VStack(alignment: .leading, spacing: 22) {
            ForEach(grupos, id: \.rotulo) { grupo in
                VStack(alignment: .leading, spacing: 10) {
                    Text(grupo.rotulo).bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(Array(grupo.itens.enumerated()), id: \.element.id) { i, c in
                            if i > 0 { BXTracejado(cor: BXCor.linha).padding(.horizontal, 16) }
                            linha(c)
                        }
                    }
                    .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
                }
            }
        }
    }

    private func reabrivel(_ c: BXCobrancaPix) -> Bool {
        c.status.emAberto && (c.segundosParaExpirar() ?? 1) > 0
    }

    @ViewBuilder private func linha(_ c: BXCobrancaPix) -> some View {
        let st = BXTextoCompra.status(reabrivel(c) || !c.status.emAberto ? c.status : .expirada)
        let conteudo = HStack(alignment: .center, spacing: 12) {
            BXIcone(.comprar, tamanho: .atalho)
            VStack(alignment: .leading, spacing: 4) {
                Text(BXTextoCompra.rotuloPacote(c.pacote) == "Valor livre" ? "Valor livre" : "Pacote \(BXTextoCompra.rotuloPacote(c.pacote))")
                    .bxFonte(.item).foregroundStyle(BXCor.tinta)
                Text("\(BXFormato.dinheiro(c.valor)) · \(BXFormato.hora(c.dataReferencia))")
                    .font(BXFonte.fonte(.recibo, tamanho: 12))
                    .foregroundStyle(BXCor.cinza)
                BXStatus(st.texto, st.tipo)
                    .padding(.top, 2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if c.pontos > 0 {
                    Text("+\(BXFormato.pontos(c.pontos))")
                        .bxFonte(.item)
                        .foregroundStyle(c.status == .paga ? BXCor.okTexto : BXCor.tinta)
                    Text("pts").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                }
                if reabrivel(c) {
                    Text("Pagar →").bxFonte(.botao).foregroundStyle(BXCor.tinta)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)

        if reabrivel(c) {
            Button { reabrir = .reabrir(c) } label: { conteudo }
                .buttonStyle(BXEstiloPressao())
                .accessibilityHint("Abre o QR Code para pagar")
        } else {
            conteudo
        }
    }

    private func carregar(recarga: Bool) async {
        if !recarga, carga.valor != nil { return }
        if carga.valor == nil { carga = .carregando }
        do {
            let itens = try await BXAPI.shared.minhasCobrancasPix()
                .sorted { $0.dataReferencia > $1.dataReferencia }
            carga = itens.isEmpty ? .vazio : .pronto(itens)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if recarga, carga.valor != nil { return }
            carga = .erro(BXErro.de(error))
        }
    }
}
