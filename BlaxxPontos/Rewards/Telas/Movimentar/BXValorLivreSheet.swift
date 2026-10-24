//
//  BXValorLivreSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Valor livre (spec §5 G3 item 2; web `comprar-livre.html`, fotos 21): campo em reais, mínimo R$ 10,00 e
//  máximo R$ 100.000,00. Sem prévia de pontos (o web calcula no cliente com o valor do ponto, proibido):
//  "Os pontos são calculados na confirmação." O botão fecha esta folha e abre a de pagamento.
//

import SwiftUI

struct BXValorLivreSheet: View {
    let aoGerar: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var texto = ""
    @State private var erro: String?

    private static let minimo: Decimal = 10
    private static let maximo: Decimal = 100_000

    init(aoGerar: @escaping (Decimal) -> Void) {
        self.aoGerar = aoGerar
    }

    private var valor: Decimal? {
        guard let v = BXFormato.decimalDeDinheiro(texto), v > 0 else { return nil }
        return v
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BXCabecaFolha("Valor livre") { dismiss() }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Você define quanto comprar.")
                        .bxFonte(.h2).foregroundStyle(BXCor.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Mínimo de R$ 10,00 e máximo de R$ 100.000,00 por compra.")
                        .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                }
                BXCampo("Quanto você quer comprar?", texto: $texto, tipo: .dinheiro,
                        placeholder: "R$ 0,00", dica: "Os pontos são calculados na confirmação.", erro: erro)
                    .onChange(of: texto) { _, _ in erro = nil }
                BXBotao("Gerar QR Code de pagamento") { gerar() }
                    .disabled(valor == nil)
                BXAvisoLegalPontos()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func gerar() {
        guard let v = valor else { erro = "Informe o valor da compra."; return }
        if v < Self.minimo { erro = "O valor mínimo é R$ 10,00."; return }
        if v > Self.maximo { erro = "O valor máximo por compra é R$ 100.000,00."; return }
        aoGerar(v)
    }
}
