//
//  BXRecibo.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Recibo com serrilhado e cabeça preta (`.bx-recibo`, fotos web 01-04/05, 13-06, 14b-03):
//  serrilhado de 12 pt em cima (preto quando há cabeça) e embaixo, corpo superfície em mono 13,
//  padding 22/16, gap 14, sombra que segue o recorte. Cabeça preta sangrando até a borda com o
//  wordmark (30 pt) e a legenda mono 12.
//  Regra do CSS e do dono: nunca linha de valor do ponto, nunca linha de "taxa".
//

import SwiftUI

struct BXRecibo<Corpo: View>: View {
    struct Acao {
        let titulo: String
        let executar: () -> Void
        init(titulo: String, executar: @escaping () -> Void) {
            self.titulo = titulo
            self.executar = executar
        }
    }

    let cabeca: String?
    let acao: Acao?
    let corpo: Corpo

    /// - Parameters:
    ///   - cabeca: legenda da cabeça preta ("EXTRATO DA SUA COMPRA"); `nil` = sem cabeça.
    ///   - acao: botão preto de largura total no pé ("COMPRAR 5.500 PTS →").
    init(cabeca: String? = nil, acao: Acao? = nil, @ViewBuilder corpo: () -> Corpo) {
        self.cabeca = cabeca
        self.acao = acao
        self.corpo = corpo()
    }

    var body: some View {
        VStack(spacing: 0) {
            BXSerrilha(borda: .top)
                .fill(cabeca == nil ? BXCor.superficie : BXCor.tinta)
                .frame(height: 12)
                .accessibilityHidden(true)
            if let cabeca {
                VStack(spacing: 10) {
                    BXWordmark(.barra, altura: 30)
                    Text(cabeca)
                        .bxFonte(.rotuloMedio)
                        .foregroundStyle(BXCor.barraTexto)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(EdgeInsets(top: 18, leading: 16, bottom: 16, trailing: 16))
                .background(BXCor.tinta, in: Rectangle())
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 14) {
                corpo
                if let acao {
                    Button(action: acao.executar) {
                        Text(acao.titulo)
                            .bxFonte(.acaoRecibo)
                            .foregroundStyle(BXCor.superficie)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(BXCor.tinta, in: Rectangle())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BXEstiloPressao())
                }
            }
            .bxFonte(.recibo)
            .foregroundStyle(BXCor.tinta)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: cabeca == nil ? 22 : 14, leading: 16, bottom: 22, trailing: 16))
            .background(BXCor.superficie, in: Rectangle())
            BXSerrilha(borda: .bottom)
                .fill(BXCor.superficie)
                .frame(height: 12)
                .accessibilityHidden(true)
        }
        .compositingGroup()
        .bxSombra(.recibo)
        .accessibilityElement(children: .contain)
    }
}

/// `RÓTULO ……… valor`: pontilhado de 2 pt `BXCor.pontilhado` 4 pt acima da linha de base.
struct BXReciboLinha: View {
    let rotulo: String
    let valor: String
    var corPontilhado: Color = BXCor.pontilhado

    init(_ rotulo: String, _ valor: String) {
        self.rotulo = rotulo
        self.valor = valor
    }

    init(_ rotulo: String, _ valor: String, corPontilhado: Color) {
        self.rotulo = rotulo
        self.valor = valor
        self.corPontilhado = corPontilhado
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(rotulo).textCase(.uppercase).lineLimit(1).layoutPriority(2)
            BXPontilhado(cor: corPontilhado)
            Text(valor).lineLimit(1).minimumScaleFactor(0.6).layoutPriority(1)
        }
        .bxFonte(.recibo)
        .frame(minHeight: 20)   // altura de linha do Space Mono 13 no web (o SF Mono é mais baixo)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rotulo), \(valor)")
    }
}

/// Pontilhado de 2 pt (pontos redondos a cada 4 pt) alinhado 4 pt acima da linha de base do texto vizinho.
struct BXPontilhado: View {
    var cor: Color = BXCor.pontilhado
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            p.move(to: CGPoint(x: 1, y: size.height / 2))
            p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.stroke(p, with: .color(cor), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.01, 4]))
        }
        .frame(minWidth: 12, maxWidth: .infinity)
        .frame(height: 2)
        .alignmentGuide(.lastTextBaseline) { d in d[.bottom] + 4 }
        .accessibilityHidden(true)
    }
}

/// "TOTAL" + valor grande (36/900), alinhados pela linha de base.
struct BXReciboTotal: View {
    let rotulo: String
    let valor: String

    init(_ rotulo: String = "TOTAL", _ valor: String) {
        self.rotulo = rotulo
        self.valor = valor
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(rotulo).bxFonte(.recibo).textCase(.uppercase)
            Spacer(minLength: 0)
            Text(valor).bxFonte(.totalRecibo)
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .foregroundStyle(BXCor.tinta)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rotulo), \(valor)")
    }
}

/// Faixa neon que sangra 12 pt para os lados ("PONTOS NA CONTA ……… 5.500").
struct BXReciboFaixa: View {
    let rotulo: String
    let valor: String

    init(_ rotulo: String, _ valor: String) {
        self.rotulo = rotulo
        self.valor = valor
    }

    var body: some View {
        BXReciboLinha(rotulo, valor, corPontilhado: BXCor.pontilhadoSobreNeon)
            .contentTransition(.numericText())
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(BXCor.neon, in: Rectangle())
            .padding(.horizontal, -12)
    }
}

/// Linha tracejada tinta de 2 pt (`.bx-tracejo`).
struct BXReciboTracejo: View {
    init() {}
    var body: some View { BXTracejado(cor: BXCor.tinta) }
}

/// "—— VIA DO PASSAGEIRO ——" entre dois tracejados de linha.
struct BXReciboVia: View {
    let texto: String
    init(_ texto: String = "Via do passageiro") { self.texto = texto }
    var body: some View {
        HStack(spacing: 12) {
            BXTracejado(cor: BXCor.linha)
            Text(texto).bxFonte(.rotulo).foregroundStyle(BXCor.cinza).fixedSize()
            BXTracejado(cor: BXCor.linha)
        }
        .accessibilityHidden(true)
    }
}

/// Nota de rodapé do recibo (mono 12 cinza, entrelinha 1,5).
struct BXReciboNota: View {
    let texto: String
    init(_ texto: String) { self.texto = texto }
    var body: some View {
        Text(texto)
            .font(BXFonte.fonte(.recibo, tamanho: 12))
            .lineSpacing(4)
            .foregroundStyle(BXCor.cinza)
            .fixedSize(horizontal: false, vertical: true)
    }
}
