//
//  BXFormas.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Motivos gráficos do tema (blaxx-embarque.css, "Motivos do design"):
//  - `BXPicote`: linha tracejada 2 pt + dois recortes redondos de 28 pt nas pontas;
//  - `.bxSuperficie(...)`: fundo de cartão que FURA os recortes de todo `BXPicote` interno
//    (compositingGroup + blendMode(.destinationOut)), então o cartão funciona sobre chão, superfície ou sheet;
//  - `BXSerrilha`: borda serrilhada do recibo (dentes de 12 pt);
//  - `BXCodigoBarras`: padrão repetido de 14 pt (2 cheio, 2 vazio, 3 cheio, 2 vazio, 1 cheio, 4 vazio);
//  - `BXTracejado`: linha tracejada (2 pt, traço 6 / vão 4, medido nas fotos do web).
//  Todos são decorativos: ocultos para o VoiceOver.
//

import SwiftUI

/// Padrão de traço das linhas tracejadas de 2 pt do web (medido: 6 cheio, 4 vazio).
nonisolated enum BXTraco {
    static let tracejado: [CGFloat] = [6, 4]
}

// MARK: - Picote

struct BXPicote: View {
    enum Orientacao: Sendable { case horizontal, vertical }

    let orientacao: Orientacao
    var recorte: CGFloat = 28
    var cor: Color = BXCor.linha

    init(_ orientacao: Orientacao, recorte: CGFloat = 28, cor: Color = BXCor.linha) {
        self.orientacao = orientacao
        self.recorte = recorte
        self.cor = cor
    }

    var body: some View {
        BXLinhaTracejada(orientacao: orientacao, cor: cor, espessura: 2)
            .frame(width: orientacao == .vertical ? 2 : nil, height: orientacao == .horizontal ? 2 : nil)
            .frame(maxWidth: orientacao == .horizontal ? .infinity : nil,
                   maxHeight: orientacao == .vertical ? .infinity : nil)
            .anchorPreference(key: BXPicoteChave.self, value: .bounds) { a in
                [BXPicoteInfo(ancora: a, orientacao: orientacao, recorte: recorte)]
            }
            .accessibilityHidden(true)
    }
}

struct BXPicoteInfo {
    let ancora: Anchor<CGRect>
    let orientacao: BXPicote.Orientacao
    let recorte: CGFloat
}

nonisolated struct BXPicoteChave: PreferenceKey {
    static var defaultValue: [BXPicoteInfo] { [] }
    static func reduce(value: inout [BXPicoteInfo], nextValue: () -> [BXPicoteInfo]) {
        value.append(contentsOf: nextValue())
    }
}

/// Linha tracejada reta que ocupa o espaço proposto (horizontal ou vertical).
struct BXLinhaTracejada: View {
    var orientacao: BXPicote.Orientacao = .horizontal
    var cor: Color
    var espessura: CGFloat = 2
    var padrao: [CGFloat] = BXTraco.tracejado

    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            if orientacao == .horizontal {
                p.move(to: CGPoint(x: 0, y: size.height / 2)); p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            } else {
                p.move(to: CGPoint(x: size.width / 2, y: 0)); p.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            }
            ctx.stroke(p, with: .color(cor), style: StrokeStyle(lineWidth: espessura, dash: padrao))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Superfície com recortes

extension View {
    /// Fundo de cartão do tema: cor, raio, borda opcional e sombra, com os recortes de todo `BXPicote`
    /// interno abertos de verdade (furos transparentes, não círculos pintados com a cor do chão).
    /// Os picotes internos são consumidos aqui e não vazam para um cartão de fora.
    func bxSuperficie(raio: CGFloat,
                      cor: Color = BXCor.superficie,
                      borda: Color? = nil,
                      larguraBorda: CGFloat = 1,
                      sombra: BXSombra? = nil) -> some View {
        modifier(BXSuperficieModificador(raio: raio, cor: cor, borda: borda, larguraBorda: larguraBorda, sombra: sombra))
    }
}

private struct BXSuperficieModificador: ViewModifier {
    let raio: CGFloat
    let cor: Color
    let borda: Color?
    let larguraBorda: CGFloat
    let sombra: BXSombra?

    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: raio, style: .continuous)
        content
            .background(cor, in: forma)
            .clipShape(forma)
            .overlay {
                if let borda { forma.strokeBorder(borda, lineWidth: larguraBorda) }
            }
            .overlayPreferenceValue(BXPicoteChave.self) { infos in
                GeometryReader { g in
                    ForEach(Array(infos.enumerated()), id: \.offset) { _, info in
                        let r = g[info.ancora]
                        let d = info.recorte
                        let pontas: [CGPoint] = info.orientacao == .horizontal
                            ? [CGPoint(x: r.minX, y: r.midY), CGPoint(x: r.maxX, y: r.midY)]
                            : [CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.midX, y: r.maxY)]
                        ForEach(0..<2, id: \.self) { i in
                            Circle()
                                .frame(width: d, height: d)
                                .position(pontas[i])
                                .blendMode(.destinationOut)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            .transformPreference(BXPicoteChave.self) { $0 = [] }
            .compositingGroup()
            .modifier(BXSombraOpcional(sombra: sombra))
    }
}

private struct BXSombraOpcional: ViewModifier {
    let sombra: BXSombra?
    func body(content: Content) -> some View {
        if let sombra { content.bxSombra(sombra) } else { content }
    }
}

// MARK: - Serrilha do recibo

/// Faixa serrilhada do recibo. Os dentes ficam na borda indicada (`.top` em cima, `.bottom` embaixo);
/// o resto da faixa é cheio, na cor do corpo (ou tinta, quando o recibo tem cabeça preta).
/// Geometria do CSS (dois gradientes de 135°/−135° em ladrilhos de 12 pt): entalhe em V de 90°,
/// meia-base = (período/2)·(√2 − 1) ≈ 2,5 pt.
nonisolated struct BXSerrilha: Shape {
    var periodo: CGFloat = 12
    var borda: Edge = .top

    init(periodo: CGFloat = 12, borda: Edge) {
        self.periodo = periodo
        self.borda = borda
    }

    func path(in rect: CGRect) -> Path {
        let h = (periodo / 2) * (2.0.squareRoot() - 1)
        var p = Path()
        let em: Bool = borda == .top      // dentes em cima?
        let yDente = em ? rect.minY : rect.maxY
        let yFundo = em ? rect.maxY : rect.minY
        let dir: CGFloat = em ? 1 : -1
        p.move(to: CGPoint(x: rect.minX, y: yDente))
        var x = rect.minX
        while x < rect.maxX {
            let centro = x + periodo / 2
            p.addLine(to: CGPoint(x: min(rect.maxX, centro - h), y: yDente))
            if centro + h <= rect.maxX {
                p.addLine(to: CGPoint(x: centro, y: yDente + dir * h))
                p.addLine(to: CGPoint(x: centro + h, y: yDente))
            }
            x += periodo
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: yDente))
        p.addLine(to: CGPoint(x: rect.maxX, y: yFundo))
        p.addLine(to: CGPoint(x: rect.minX, y: yFundo))
        p.closeSubpath()
        return p
    }
}

// MARK: - Código de barras

/// Código de barras decorativo: padrão de 14 pt (2 cheio, 2 vazio, 3 cheio, 2 vazio, 1 cheio, 4 vazio).
struct BXCodigoBarras: View {
    var altura: CGFloat = 36
    var cor: Color = BXCor.tinta

    init(altura: CGFloat = 36, cor: Color = BXCor.tinta) {
        self.altura = altura
        self.cor = cor
    }

    var body: some View {
        Canvas { ctx, size in
            let barras: [(CGFloat, CGFloat)] = [(0, 2), (4, 3), (9, 1)]
            var x: CGFloat = 0
            var p = Path()
            while x < size.width {
                for (ini, larg) in barras where x + ini < size.width {
                    p.addRect(CGRect(x: x + ini, y: 0, width: min(larg, size.width - x - ini), height: size.height))
                }
                x += 14
            }
            ctx.fill(p, with: .color(cor))
        }
        .frame(height: altura)
        .accessibilityHidden(true)
    }
}

// MARK: - Tracejado

/// Linha tracejada horizontal (`.bx-tracejo`: 2 pt tinta). Sobre preto, use `BXCor.tinta3`.
struct BXTracejado: View {
    var cor: Color = BXCor.tinta
    var espessura: CGFloat = 2

    init(cor: Color = BXCor.tinta, espessura: CGFloat = 2) {
        self.cor = cor
        self.espessura = espessura
    }

    var body: some View {
        BXLinhaTracejada(orientacao: .horizontal, cor: cor, espessura: espessura)
            .frame(height: espessura)
            .frame(maxWidth: .infinity)
    }
}
