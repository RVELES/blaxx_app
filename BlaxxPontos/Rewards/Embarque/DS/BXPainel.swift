//
//  BXPainel.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Painel de partidas e quadro preto (`.bx-painel`, `.bx-quadro`, fotos web 01-05/06/07, 13-02):
//  - `BXPainel`: superfície, borda 1 pt, raio 24, padding 20/16, sombra; rótulo de seção + título.
//  - `BXNumeroDestaque`: número 44/900 sobre neon + legenda ("27 cidades no mapa").
//  - `BXQuadroPreto`: quadro mono com cabeçalho, linhas MAIÚSC tocáveis (a selecionada fica neon com
//    texto tinta), bolinha de situação (neon = em implantação, apagada = em expansão), rola por dentro
//    (máx. 300) e um rodapé com a informação da linha escolhida.
//

import SwiftUI

struct BXPainel<Conteudo: View>: View {
    let rotulo: String
    let titulo: String
    let conteudo: Conteudo

    init(rotulo: String, titulo: String, @ViewBuilder conteudo: () -> Conteudo) {
        self.rotulo = rotulo
        self.titulo = titulo
        self.conteudo = conteudo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text(rotulo).bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
                Text(titulo).bxFonte(.tituloSecao).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
        .bxSuperficie(raio: BXRaio.xl, borda: BXCor.linha, sombra: .padrao)
    }
}

/// Número grande sobre neon + legenda (`.bx-painel-grande`).
struct BXNumeroDestaque: View {
    let numero: String
    let legenda: String

    init(_ numero: String, legenda: String) {
        self.numero = numero
        self.legenda = legenda
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(numero)
                .bxFonte(.numeroDestaque)
                .foregroundStyle(BXCor.tinta)
                .padding(.horizontal, 3.5)
                .background(BXCor.neon, in: Rectangle())
            Text(legenda).bxFonte(.corpo).foregroundStyle(BXCor.tinta)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Legenda de cor do painel (quadradinho 12 raio 3 + texto mono 12 cinza).
struct BXLegendaCor: View {
    let cor: Color
    let texto: String
    init(_ cor: Color, _ texto: String) { self.cor = cor; self.texto = texto }
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(cor).frame(width: 12, height: 12)
            Text(texto).font(BXFonte.fonte(.recibo, tamanho: 12)).foregroundStyle(BXCor.cinza)
        }
    }
}

struct BXQuadroLinha: Identifiable, Hashable, Sendable {
    let id: String
    let destino: String
    let pais: String
    /// `true` = "Em implantação" (bolinha neon); `false` = "Em expansão" (bolinha apagada).
    let ativa: Bool

    init(id: String, destino: String, pais: String, ativa: Bool) {
        self.id = id
        self.destino = destino
        self.pais = pais
        self.ativa = ativa
    }
}

struct BXQuadroPreto<Rodape: View>: View {
    let cabecalho: [String]
    let linhas: [BXQuadroLinha]
    @Binding var selecionada: String?
    let rodape: (BXQuadroLinha?) -> Rodape
    var alturaMaxima: CGFloat = 300

    init(cabecalho: [String] = ["Destino", "País", "Situação"],
         linhas: [BXQuadroLinha],
         selecionada: Binding<String?>,
         alturaMaxima: CGFloat = 300,
         @ViewBuilder rodape: @escaping (BXQuadroLinha?) -> Rodape) {
        self.cabecalho = cabecalho
        self.linhas = linhas
        self._selecionada = selecionada
        self.alturaMaxima = alturaMaxima
        self.rodape = rodape
    }

    private func colunas<A: View, B: View, C: View>(@ViewBuilder _ a: () -> A, @ViewBuilder _ b: () -> B,
                                                     @ViewBuilder _ c: () -> C) -> some View {
        BXColunasQuadro {
            a()
            b()
            c()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            colunas {
                Text(cabecalho.first ?? "")
            } _: {
                Text(cabecalho.count > 1 ? cabecalho[1] : "")
            } _: {
                Circle().fill(BXCor.tintaApagada).frame(width: 6, height: 6)
                    .accessibilityLabel(cabecalho.count > 2 ? cabecalho[2] : "")
            }
            .bxFonte(.rotulo)
            .foregroundStyle(BXCor.tintaApagada)
            .padding(EdgeInsets(top: 18, leading: 16, bottom: 12, trailing: 16))
            .overlay(alignment: .bottom) { Rectangle().fill(BXCor.tinta2).frame(height: 1) }
            .accessibilityHidden(true)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(linhas) { l in
                        linha(l)
                    }
                }
            }
            .frame(maxHeight: alturaMaxima)
            .scrollIndicators(.visible)

            rodape(linhas.first { $0.id == selecionada })
                .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
                .background(BXCor.quadroRodape, in: Rectangle())
                .overlay(alignment: .top) { Rectangle().fill(BXCor.tinta2).frame(height: 1) }
        }
        .background(BXCor.tinta, in: Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
    }

    private func linha(_ l: BXQuadroLinha) -> some View {
        let ativa = selecionada == l.id
        return Button {
            withAnimation(BXMovimento.ease) { selecionada = ativa ? nil : l.id }
        } label: {
            colunas {
                Text(l.destino).bxFonte(.quadro).lineLimit(1)
                    .foregroundStyle(ativa ? BXCor.tinta : BXCor.papel)
            } _: {
                Text(l.pais).font(BXFonte.fonte(.recibo, tamanho: 12)).lineLimit(1)
                    .foregroundStyle(ativa ? BXCor.tinta : BXCor.tintaApagada)
            } _: {
                Circle()
                    .fill(ativa ? BXCor.tinta : (l.ativa ? BXCor.neon : BXCor.quadroApagado))
                    .frame(width: 8, height: 8)
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .frame(minHeight: 44)
            .background(ativa ? BXCor.neon : Color.clear, in: Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(BXCor.quadroLinha).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(BXEstiloLinhaQuadro())
        .sensoryFeedback(.selection, trigger: ativa)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(l.destino), \(l.pais), \(l.ativa ? "em implantação" : "em expansão")")
        .accessibilityAddTraits(ativa ? [.isButton, .isSelected] : .isButton)
    }
}

/// Colunas do quadro: 1,25fr · 1fr · 18 pt (situação), vão 12 (grid do `.bx-quadro-linha` no celular).
nonisolated struct BXColunasQuadro: Layout {
    var espaco: CGFloat = 12
    var ultima: CGFloat = 18
    var pesos: [CGFloat] = [1.25, 1]

    private func larguras(_ total: CGFloat, _ n: Int) -> [CGFloat] {
        let livre = max(0, total - ultima - espaco * CGFloat(max(0, n - 1)))
        let soma = pesos.reduce(0, +)
        var r = pesos.map { livre * $0 / soma }
        while r.count < n - 1 { r.append(0) }
        return Array(r.prefix(max(0, n - 1))) + [ultima]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 320
        let ls = larguras(w, subviews.count)
        let h = subviews.indices.map { subviews[$0].sizeThatFits(ProposedViewSize(width: ls[$0], height: nil)).height }.max() ?? 0
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ls = larguras(bounds.width, subviews.count)
        var x = bounds.minX
        for i in subviews.indices {
            let ultimaColuna = i == subviews.count - 1
            subviews[i].place(at: CGPoint(x: ultimaColuna ? x + ls[i] : x, y: bounds.midY),
                              anchor: ultimaColuna ? .trailing : .leading,
                              proposal: ProposedViewSize(width: ls[i], height: nil))
            x += ls[i] + espaco
        }
    }
}

private struct BXEstiloLinhaQuadro: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? BXCor.quadroToque : Color.clear)
    }
}

/// Conteúdo padrão do rodapé do quadro: título 20/800 papel, texto mono 13 apagado e link neon sublinhado.
struct BXQuadroInfo: View {
    let titulo: String
    let texto: String?
    var link: (titulo: String, acao: () -> Void)? = nil

    init(titulo: String, texto: String?, link: (titulo: String, acao: () -> Void)? = nil) {
        self.titulo = titulo
        self.texto = texto
        self.link = link
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo).bxFonte(.tituloQuadro).foregroundStyle(BXCor.papel)
            if let texto {
                Text(texto).bxFonte(.recibo).foregroundStyle(BXCor.tintaApagada)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let link {
                Button(action: link.acao) {
                    Text("\(link.titulo) →").bxFonte(.botao)
                        .bxTextoNeon()
                        .padding(.bottom, 2)
                        .overlay(alignment: .bottom) { Rectangle().fill(BXCor.neon).frame(height: 2) }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
