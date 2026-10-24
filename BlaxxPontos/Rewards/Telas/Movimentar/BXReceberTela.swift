//
//  BXReceberTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Receber pontos (spec §5 G3 item 10): QR e número do Cartão BlaXx gerados no aparelho a partir do
//  usuário da sessão (nenhum endpoint; o Cartão é destino aceito por `POST /transfer/`). QR grande e
//  nítido em cartão branco, brilho máximo enquanto visível, copiar com háptica e `ShareLink`.
//  Nada do conteúdo fixo de `receber-pontos.html` (convite inventado "Mariana, Lucas enviou…").
//

import SwiftUI

struct BXReceberTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXToastCentral.self) private var toast
    @State private var tentando = false

    var body: some View {
        BXColunaMovimentar(atualizar: { await sessao.recarregarUsuario() }) {
            BXCabecalhoPagina(eyebrow: "Receber pontos",
                              titulo: "Mostre o seu Cartão BlaXx.",
                              lead: "Quem tem a BlaXx aponta a câmera para o QR Code e envia pontos para você.")
                .padding(.bottom, 24)

            if let u = sessao.usuario {
                cartao(u)
            } else if sessao.estado == .iniciando {
                BXEsqueleto(.bloco(altura: 420))
            } else {
                BXEstadoErro(BXErro.semConexao) { await sessao.recarregarUsuario() }
            }

            Text("Quem tem a BlaXx pode enviar pontos para você com este código, o seu e-mail ou o seu CPF.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
        }
    }

    private func cartao(_ u: BXUsuario) -> some View {
        let link = "blaxxpontos://enviar?para=\(u.cartaoID)"
        let numero = u.cartaoFormatado
        return VStack(spacing: 0) {
            VStack(spacing: 18) {
                HStack {
                    BXRotulo("Cartão BlaXx")
                    Spacer()
                    BXChip("Receber", .preto)
                }
                BXQRCode(link, lado: 236)
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous).strokeBorder(BXCor.linha, lineWidth: 1))
                    .accessibilityLabel("QR Code do seu Cartão BlaXx")
                    .bxBrilhoMaximo()
                    .id("qr")
            }
            .padding(EdgeInsets(top: 20, leading: 18, bottom: 22, trailing: 18))

            BXPicote(.horizontal)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    BXRotulo("Número do cartão")
                    Text(numero)
                        .bxFonte(.saldoMono)
                        .foregroundStyle(BXCor.tinta)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .textSelection(.enabled)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Número do Cartão BlaXx, \(numero.map { String($0) }.joined(separator: " "))")
                .accessibilityAction(named: "Copiar número") { copiar(u) }
                if let primeiro = u.primeiroNome {
                    BXGradeDados([BXDado("Passageiro", primeiro), BXDado("Destino", "Sua conta")])
                }
                HStack(spacing: 10) {
                    BXBotao("Copiar número", estilo: .preto, icone: .documento) { copiar(u) }
                    ShareLink(item: "Meu Cartão BlaXx: \(numero)\n\(link)") {
                        Label { Text("Compartilhar") } icon: { BXIcone(.anexo, tamanho: .livre(lado: 26, raio: 7)) }
                            .bxFonte(.botao)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BXEstiloBotao(estilo: .secundario))
                }
            }
            .padding(EdgeInsets(top: 20, leading: 18, bottom: 22, trailing: 18))
        }
        .bxSuperficie(raio: BXRaio.xl, borda: BXCor.linha, sombra: .padrao)
        .contextMenu {
            Button("Copiar número") { copiar(u) }
        }
    }

    private func copiar(_ u: BXUsuario) {
        BXCopiar.copiar(u.cartaoID, aviso: "Número do cartão copiado.", toast: toast)
    }
}
