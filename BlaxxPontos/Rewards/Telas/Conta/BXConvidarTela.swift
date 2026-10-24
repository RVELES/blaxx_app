//
//  BXConvidarTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Convidar amigos (WEB/indique.html, fotos 32), D06: só compartilhar o convite, SEM prometer pontos
//  (o backend não tem programa de indicação). Do web ficam o cartão preto com o link e as ações
//  (Copiar, Compartilhar, WhatsApp) e os passos 01–03; saem "5.000 PTS POR AMIGO", o código de convite
//  inventado, os números de convidados e a lista de convidados.
//

import SwiftUI

struct BXConvidarTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.openURL) private var abrirURL

    static let link = "https://blaxxpontos.com.br/cadastro"
    private var linkExibido: String { "blaxxpontos.com.br/cadastro" }

    private var mensagem: String {
        let nome = sessao.usuario?.primeiroNome.map { "\($0) te convidou para a BlaXx. " } ?? ""
        return "\(nome)Receba e envie pontos entre contas BlaXx e troque por benefícios. Sem mensalidade. Crie sua conta: \(Self.link)"
    }

    var body: some View {
        BXPaginaConta {
            BXCabecalhoPagina(eyebrow: "Convidar", titulo: "Chame seus amigos para a BlaXx.",
                              lead: "Mande o link de cadastro para quem você quiser. A conta é gratuita e sem mensalidade.")
            cartaoConvite
            VStack(spacing: 12) {
                passo("01", "Compartilhe", "Envie o link para os seus amigos por onde quiser.")
                passo("02", "Eles entram", "O cadastro leva poucos minutos e não tem mensalidade.")
                passo("03", "Usem juntos", "Vocês podem enviar pontos um para o outro, entre contas BlaXx.")
            }
            Text("Convidar amigos não gera pontos nem bônus.")
                .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cartaoConvite: some View {
        VStack(alignment: .leading, spacing: 18) {
            BXChip("Convite · sem mensalidade", .eyebrow)
            VStack(alignment: .leading, spacing: 8) {
                Text("Seu convite").bxFonte(.tituloConvite).foregroundStyle(BXCor.papel)
                    .accessibilityAddTraits(.isHeader)
                Text("Quem entrar pelo link cria a conta em poucos minutos e já pode receber pontos de você.")
                    .bxFonte(.corpo).foregroundStyle(BXCor.barraTexto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    textoLink
                    botaoCopiar
                }
                VStack(alignment: .leading, spacing: 12) {
                    textoLink
                    botaoCopiar
                }
            }
            .padding(14)
            .overlay(RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous)
                .strokeBorder(BXCor.tinta3, style: StrokeStyle(lineWidth: 1.5, dash: BXTraco.tracejado)))
            .background(BXCor.tinta2.opacity(0.5), in: RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous))

            ShareLink(item: URL(string: Self.link)!, subject: Text("Convite BlaXx"), message: Text(mensagem)) {
                Text("Compartilhar convite →").bxFonte(.botao).frame(maxWidth: .infinity)
            }
            .buttonStyle(BXEstiloBotao(estilo: .vazadoSobrePreto))
            .simultaneousGesture(TapGesture().onEnded { BXHaptica.tocar(.leve) })

            BXBotao("WhatsApp", estilo: .vazadoSobrePreto) { abrirWhatsApp() }
        }
        .padding(BXEspaco.cartao + 2)
        .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
        .bxSombra(.padrao)
    }

    private var textoLink: some View {
        Text(linkExibido)
            .font(BXFonte.fonte(.recibo, tamanho: 16))
            .bxTextoNeon()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityLabel("Link do convite, blaxxpontos ponto com ponto br barra cadastro")
    }

    private var botaoCopiar: some View {
        BXBotao("Copiar", estilo: .primario, larguraTotal: false) {
            BXCopiar.copiar(Self.link, aviso: "Link do convite copiado.", toast: toast)
        }
    }

    private func passo(_ n: String, _ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(n).bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
            Text(titulo).bxFonte(.tituloBilhete).foregroundStyle(BXCor.tinta)
            Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BXEspaco.cartao)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha, sombra: .leve)
        .accessibilityElement(children: .combine)
    }

    private func abrirWhatsApp() {
        var c = URLComponents(string: "https://wa.me/")
        c?.queryItems = [URLQueryItem(name: "text", value: mensagem)]
        guard let url = c?.url else { return }
        BXHaptica.tocar(.leve)
        abrirURL(url)
    }
}
