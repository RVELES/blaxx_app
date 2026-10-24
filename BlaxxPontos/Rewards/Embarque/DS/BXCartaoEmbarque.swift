//
//  BXCartaoEmbarque.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Cartão de embarque (`.bx-cartao`, fotos web 01-01/02, 13-01, 14b-02): miolo em cima, picote
//  horizontal e canhoto embaixo, superfície raio 24 com sombra macia. Inclui o título de capa
//  (uma linha por `Text`, linhas marcadas em neon), o letreiro que troca a 2ª linha e a grade de dados.
//

import SwiftUI

// MARK: - Cartão

struct BXCartaoEmbarque<Miolo: View, Canhoto: View>: View {
    let topo: (esquerda: String, direita: String)?
    let codigoDeBarras: Bool
    let miolo: Miolo
    let canhoto: Canhoto

    /// - Parameters:
    ///   - topo: linha mono 11 MAIÚSC cinza, ex.: ("Cartão de embarque · BlaXx Pontos", "Brasil · 2026").
    ///   - codigoDeBarras: código de barras de 36 pt no pé do canhoto.
    init(topo: (esquerda: String, direita: String)? = nil,
         codigoDeBarras: Bool = true,
         @ViewBuilder miolo: () -> Miolo,
         @ViewBuilder canhoto: () -> Canhoto) {
        self.topo = topo
        self.codigoDeBarras = codigoDeBarras
        self.miolo = miolo()
        self.canhoto = canhoto()
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                if let topo {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(topo.esquerda)
                            Spacer(minLength: 0)
                            Text(topo.direita)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topo.esquerda)
                            Text(topo.direita)
                        }
                    }
                    .bxFonte(.rotulo)
                    .foregroundStyle(BXCor.cinza)
                    .accessibilityElement(children: .combine)
                }
                miolo
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 22, leading: 16, bottom: 24, trailing: 16))

            BXPicote(.horizontal)

            VStack(spacing: 0) {
                VStack(spacing: 18) { canhoto }
                    .frame(maxWidth: .infinity)
                if codigoDeBarras {
                    BXCodigoBarras(altura: 36).padding(.top, 12)
                }
            }
            .padding(EdgeInsets(top: 20, leading: 20, bottom: 22, trailing: 20))
        }
        .foregroundStyle(BXCor.tinta)
        .bxSuperficie(raio: BXRaio.xl, sombra: .padrao)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Título de capa

/// Título de capa: uma linha por `Text` (altura de linha 0,9 do web), linhas marcadas com fundo neon
/// a 0,66 do tamanho. Opcionalmente, um letreiro entra depois das `linhas` e antes das `marcadas`.
struct BXTituloCapa: View {
    let linhas: [String]
    let marcadas: [String]
    let estilo: BXFonte.Estilo
    let letreiro: [String]?
    let intervaloLetreiro: Double

    @ScaledMetric private var tamanho: CGFloat
    @Environment(\.dynamicTypeSize) private var dts

    init(linhas: [String], marcadas: [String] = [], estilo: BXFonte.Estilo = .capa,
         letreiro: [String]? = nil, intervaloLetreiro: Double = 2.6) {
        self.linhas = linhas
        self.marcadas = marcadas
        self.estilo = estilo
        self.letreiro = letreiro
        self.intervaloLetreiro = intervaloLetreiro
        let s = BXFonte.spec(estilo)
        _tamanho = ScaledMetric(wrappedValue: s.tamanho, relativeTo: s.relativo)
    }

    private var espacoLinhas: CGFloat {
        dts.isAccessibilitySize ? 0 : 0.9 * tamanho - BXFonte.alturaLinha(estilo, tamanho: tamanho)
    }

    var body: some View {
        let s = BXFonte.spec(estilo)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: espacoLinhas) {
                ForEach(Array(linhas.enumerated()), id: \.offset) { _, l in
                    BXLinhaCapa(texto: l, estilo: estilo, tamanho: tamanho)
                }
                if let letreiro, !letreiro.isEmpty {
                    BXLetreiro(frases: letreiro, intervalo: intervaloLetreiro, estilo: estilo, espacoLinhas: espacoLinhas)
                }
            }
            if !marcadas.isEmpty {
                let m = tamanho * 0.66
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(marcadas.enumerated()), id: \.offset) { _, l in
                        Text(l)
                            .font(BXFonte.fonte(estilo, tamanho: m))
                            .tracking(s.tracking * tamanho)
                            .lineLimit(dts.isAccessibilitySize ? nil : 1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 0.18 * m)
                            .padding(.vertical, 0.05 * m)
                            .background(BXCor.neon, in: Rectangle())
                    }
                }
                .padding(.top, linhas.isEmpty && letreiro == nil ? 0 : 10)
            }
        }
        .foregroundStyle(BXCor.tinta)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Uma linha do título de capa (fonte do estilo, tracking −0,03 em, encolhe até 60 % antes de quebrar).
struct BXLinhaCapa: View {
    let texto: String
    let estilo: BXFonte.Estilo
    let tamanho: CGFloat
    @Environment(\.dynamicTypeSize) private var dts

    var body: some View {
        Text(texto)
            .font(BXFonte.fonte(estilo, tamanho: tamanho))
            .tracking(BXFonte.spec(estilo).tracking * tamanho)
            .lineLimit(dts.isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Letreiro

/// Linha do título que alterna de frase a cada `intervalo` segundos, subindo (transição push de baixo, 0,55 s).
/// Para com "Reduzir movimento", fora da tela e enquanto o usuário rola. No celular, cada frase vira
/// duas linhas na primeira palavra ("Novos / destinos."), como o web.
struct BXLetreiro: View {
    let frases: [String]
    let intervalo: Double
    var estilo: BXFonte.Estilo = .capa
    var espacoLinhas: CGFloat? = nil
    var quebrar: Bool = true

    @ScaledMetric private var tamanho: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduzido
    @Environment(\.dynamicTypeSize) private var dts
    @State private var indice = 0
    @State private var visivel = true
    @State private var ultimoMovimento = Date.distantPast

    /// Contrato (§1.6.1): `prefixo` + cada palavra ("Novos" + ["destinos.", "sonhos."]).
    /// Com `prefixo` vazio, cada item de `palavras` é a frase inteira ("Novas aventuras.").
    init(prefixo: String, palavras: [String], intervalo: Double = 2.6) {
        self.init(frases: palavras.map { prefixo.isEmpty ? $0 : "\(prefixo) \($0)" }, intervalo: intervalo)
    }

    init(frases: [String], intervalo: Double = 2.6, estilo: BXFonte.Estilo = .capa,
         espacoLinhas: CGFloat? = nil, quebrar: Bool = true) {
        self.frases = frases
        self.intervalo = intervalo
        self.estilo = estilo
        self.espacoLinhas = espacoLinhas
        self.quebrar = quebrar
        let s = BXFonte.spec(estilo)
        _tamanho = ScaledMetric(wrappedValue: s.tamanho, relativeTo: s.relativo)
    }

    private func linhas(_ f: String) -> [String] {
        guard quebrar, let i = f.firstIndex(of: " ") else { return [f, ""] }
        return [String(f[..<i]), String(f[f.index(after: i)...])]
    }

    var body: some View {
        let atual = frases.isEmpty ? "" : frases[indice % frases.count]
        let ls = linhas(atual)
        let espaco = espacoLinhas ?? (dts.isAccessibilitySize ? 0 : 0.9 * tamanho - BXFonte.alturaLinha(estilo, tamanho: tamanho))
        VStack(alignment: .leading, spacing: espaco) {
            ForEach(0..<(quebrar ? 2 : 1), id: \.self) { i in
                ZStack(alignment: .leading) {
                    BXLinhaCapa(texto: ls[i], estilo: estilo, tamanho: tamanho)
                        .id(ls[i])
                        .transition(.push(from: .bottom))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(frases.first ?? "")
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { _ in
            ultimoMovimento = .now
        }
        .onScrollVisibilityChange(threshold: 0.2) { visivel = $0 }
        .task(id: reduzido) {
            guard !reduzido, !BXDemo.congelar, frases.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalo))
                if Task.isCancelled { break }
                let rolando = Date.now.timeIntervalSince(ultimoMovimento) < 0.4
                if visivel && !rolando {
                    withAnimation(BXMovimento.letreiro) { indice += 1 }
                }
            }
        }
    }
}

// MARK: - Grade de dados

struct BXDado: Hashable, Sendable {
    let rotulo: String
    let valor: String
    init(_ rotulo: String, _ valor: String) { self.rotulo = rotulo; self.valor = valor }
    init(rotulo: String, valor: String) { self.rotulo = rotulo; self.valor = valor }
}

/// Grade de pares rótulo/valor do cartão de embarque: linha de 1 pt em cima, padding 18, gap 16/14.
/// Em tamanhos de acessibilidade vira uma coluna.
struct BXGradeDados: View {
    let dados: [BXDado]
    var colunas: Int = 2
    @Environment(\.dynamicTypeSize) private var dts

    init(_ dados: [BXDado], colunas: Int = 2) {
        self.dados = dados
        self.colunas = max(1, colunas)
    }

    var body: some View {
        let n = dts.isAccessibilitySize ? 1 : colunas
        let linhas = stride(from: 0, to: dados.count, by: n).map { Array(dados[$0..<min($0 + n, dados.count)]) }
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(BXCor.linha).frame(height: 1)
            Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 16) {
                ForEach(Array(linhas.enumerated()), id: \.offset) { _, linha in
                    GridRow {
                        ForEach(linha, id: \.self) { d in
                            BXCelulaDado(dado: d)
                        }
                        if linha.count < n {
                            ForEach(0..<(n - linha.count), id: \.self) { _ in Color.clear.frame(height: 0) }
                        }
                    }
                }
            }
            .padding(.top, 18)
        }
    }
}

/// Um par rótulo (mono 10 MAIÚSC cinza) / valor (14/700).
struct BXCelulaDado: View {
    let dado: BXDado
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dado.rotulo).bxFonte(.rotuloGrade).foregroundStyle(BXCor.cinza)
            Text(dado.valor).bxFonte(.valorDado).foregroundStyle(BXCor.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Dados do canhoto em uma linha ("Passageiro Você · Portão Cadastro · Assento Livre"), espaçados entre si.
/// Em tamanhos de acessibilidade, empilha.
struct BXDadosCanhoto: View {
    let dados: [BXDado]
    @Environment(\.dynamicTypeSize) private var dts
    init(_ dados: [BXDado]) { self.dados = dados }

    var body: some View {
        let layout = dts.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        layout {
            ForEach(Array(dados.enumerated()), id: \.offset) { i, d in
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.rotulo).bxFonte(.rotuloGrade).foregroundStyle(BXCor.cinza)
                    Text(d.valor).bxFonte(.valorDado).foregroundStyle(BXCor.tinta)
                }
                .accessibilityElement(children: .combine)
                if i < dados.count - 1 && !dts.isAccessibilitySize { Spacer(minLength: 0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Linha "Já tenho conta · **Entrar →**" do canhoto (15 pt, a ação em negrito).
struct BXLinkCanhoto: View {
    let prefixo: String
    let titulo: String
    let acao: () -> Void

    init(prefixo: String, titulo: String, acao: @escaping () -> Void) {
        self.prefixo = prefixo
        self.titulo = titulo
        self.acao = acao
    }

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 0) {
                Text("\(prefixo) · ").bxFonte(.corpo)
                Text("\(titulo) →").bxFonte(.botao)
            }
            .foregroundStyle(BXCor.tinta)
            .frame(maxWidth: .infinity, minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(prefixo). \(titulo)")
    }
}
