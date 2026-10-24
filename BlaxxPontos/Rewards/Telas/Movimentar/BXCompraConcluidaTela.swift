//
//  BXCompraConcluidaTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Compra concluída (spec §5 G3 item 5): recibo "COMPRA CONFIRMADA" com a faixa "PONTOS NA CONTA +N"
//  (pontos do servidor, `points_to_credit`), háptica de sucesso, "Ver meu saldo" e "Comprar mais".
//  Mostrada dentro da folha de pagamento, no lugar do QR, quando a cobrança vira paga.
//

import SwiftUI

struct BXCompraConcluida: View {
    let cobranca: BXCobrancaPix
    let aoVerSaldo: () -> Void
    let aoComprarMais: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .center, spacing: 12) {
                BXIcone(.visto, tamanho: .marca)
                Text("Pagamento confirmado.")
                    .bxFonte(.h2).foregroundStyle(BXCor.tinta)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Seus pontos já estão na conta.")
                    .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            BXRecibo(cabeca: "Compra confirmada") {
                BXReciboTracejo()
                BXReciboLinha("Pacote", BXTextoCompra.rotuloPacote(cobranca.pacote))
                BXReciboLinha("Valor", BXFormato.dinheiro(cobranca.valor))
                BXReciboLinha("Pagamento", "PIX")
                BXReciboLinha("Data", BXFormato.dataHora(cobranca.pagaEm ?? .now))
                BXReciboTracejo()
                BXReciboFaixa("Pontos na conta", "+\(BXFormato.pontos(cobranca.pontos))")
                BXReciboVia()
            }

            BXBotao("Ver meu saldo", acao: aoVerSaldo)
            BXBotao("Comprar mais", estilo: .secundario, acao: aoComprarMais)
        }
        .onAppear { AccessibilityNotification.Announcement("Pagamento confirmado. \(BXFormato.pontosFalados(cobranca.pontos)) na conta.").post() }
    }
}

