//
//  BXConfirmarEnvioSheet.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Confirmação do envio em folha `.medium` (spec §5 G3 item 8; web `confirmar-envio.html`, fotos 27):
//  Para · Pontos · Mensagem, aviso de que o envio pode ser desfeito em 60 segundos, "Confirmar envio →"
//  e "Voltar e editar". Quando o servidor pede 2FA (401 `mfa_required`), aparece o código de 6 dígitos
//  do app autenticador e o mesmo botão reenvia com `mfa_code`. Sem linha de custo do envio.
//

import SwiftUI

struct BXConfirmarEnvioSheet: View {
    let para: String
    let pontos: Int
    let mensagem: String?
    let saldo: Int?
    let pedirMFA: Bool
    @Binding var codigo: String
    let enviando: Bool
    let erro: String?
    let aoConfirmar: () -> Void
    let aoEditar: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BXCabecaFolha("Confirmar envio", aoFechar: aoEditar)
                Text("Confira antes de enviar.")
                    .bxFonte(.h2).foregroundStyle(BXCor.tinta)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 0) {
                    linha("Para", para)
                    Divider().overlay(BXCor.linha)
                    linha("Pontos", BXFormato.pontosComUnidade(pontos))
                    if let mensagem {
                        Divider().overlay(BXCor.linha)
                        linha("Mensagem", mensagem)
                    }
                    if let saldo {
                        Divider().overlay(BXCor.linha)
                        linha("Após o envio", BXFormato.pontosComUnidade(max(0, saldo - pontos)))
                    }
                }
                .padding(.horizontal, 16)
                .bxSuperficie(raio: BXRaio.lg, cor: BXCor.superficie2, borda: BXCor.linha)

                if pedirMFA {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Código de verificação").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                        Text("Para este valor, digite o código de 6 dígitos do seu app autenticador.")
                            .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                            .fixedSize(horizontal: false, vertical: true)
                        BXCampoCodigo(codigo: $codigo)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let erro {
                    BXCaixaAviso(erro, .erro)
                } else {
                    BXCaixaAviso("Você pode desfazer o envio em até 60 segundos. Depois disso, os pontos ficam com quem recebeu.", .aviso)
                }

                BXBotao(pedirMFA ? "Confirmar com o código →" : "Confirmar envio →", carregando: enviando, acao: aoConfirmar)
                    .disabled(pedirMFA && codigo.filter(\.isNumber).count < 6)
                BXBotao("Voltar e editar", estilo: .secundario, acao: aoEditar)
                    .disabled(enviando)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .animation(BXMovimento.ease, value: pedirMFA)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func linha(_ rotulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            Text(valor).bxFonte(.item).foregroundStyle(BXCor.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
