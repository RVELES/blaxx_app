//
//  BXRotaEscalas.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Rota com escalas (`.bx-rota-grid` / `.bx-escala` no celular, fotos 01-02/03, 13-08):
//  linha do tempo vertical. Cada escala: rótulo mono 12 MAIÚSC cinza com recuo 38, ponto 24 tinta
//  (o último neon com borda tinta) + palavra 34/800, texto 15 cinza com recuo 38, 30 pt abaixo.
//  Um tracejado de 2 pt tinta liga o centro de cada ponto ao centro do seguinte.
//

import SwiftUI

struct BXEscala: Identifiable, Hashable, Sendable {
    let id: Int
    /// "Escala 01 · Comprar" (exibido em MAIÚSCULAS).
    let rotulo: String
    /// "Compre"
    let palavra: String
    /// Texto de apoio (15 cinza).
    let texto: String

    init(id: Int, rotulo: String, palavra: String, texto: String) {
        self.id = id
        self.rotulo = rotulo
        self.palavra = palavra
        self.texto = texto
    }
}

struct BXRotaEscalas: View {
    let escalas: [BXEscala]
    init(_ escalas: [BXEscala]) { self.escalas = escalas }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(escalas.enumerated()), id: \.element.id) { i, e in
                let ultima = i == escalas.count - 1
                VStack(alignment: .leading, spacing: 6) {
                    Text(e.rotulo)
                        .bxFonte(.rotuloMedio)
                        .foregroundStyle(BXCor.cinza)
                        .padding(.leading, 38)
                    HStack(spacing: 14) {
                        Circle()
                            .fill(ultima ? BXCor.neon : BXCor.tinta)
                            .overlay(Circle().strokeBorder(BXCor.tinta, lineWidth: 2))
                            .frame(width: 24, height: 24)
                            .anchorPreference(key: BXPontosRota.self, value: .center) { [$0] }
                        Text(e.palavra)
                            .bxFonte(.palavraEscala)
                            .foregroundStyle(BXCor.tinta)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    Text(e.texto)
                        .bxFonte(.corpo)
                        .foregroundStyle(BXCor.cinza)
                        .padding(.leading, 38)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, ultima ? 0 : 30)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(e.rotulo). \(e.palavra). \(e.texto)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .backgroundPreferenceValue(BXPontosRota.self) { pontos in
            GeometryReader { g in
                let ps = pontos.map { g[$0] }
                Path { p in
                    for i in ps.indices.dropLast() {
                        p.move(to: ps[i]); p.addLine(to: ps[i + 1])
                    }
                }
                .stroke(BXCor.tinta, style: StrokeStyle(lineWidth: 2, dash: BXTraco.tracejado))
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
}

nonisolated struct BXPontosRota: PreferenceKey {
    static var defaultValue: [Anchor<CGPoint>] { [] }
    static func reduce(value: inout [Anchor<CGPoint>], nextValue: () -> [Anchor<CGPoint>]) {
        value.append(contentsOf: nextValue())
    }
}
