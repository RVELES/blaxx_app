//
//  BXRotulos.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Rótulos mono MAIÚSC, chips, status, pílulas de filtro, abas segmentadas e barra de progresso
//  (02-inventario §2.6 e §2.7). Texto neon só no chip preto e na aba ativa `.neon` (sobre tinta).
//

import SwiftUI

// MARK: - Rótulo

struct BXRotulo: View {
    enum Nivel: Sendable { case dado, secao, aba }
    let texto: String
    let nivel: Nivel
    let cor: Color

    init(_ texto: String, _ nivel: Nivel = .dado, cor: Color = BXCor.cinza) {
        self.texto = texto
        self.nivel = nivel
        self.cor = cor
    }

    var body: some View {
        Text(texto)
            .bxFonte(nivel == .dado ? .rotulo : (nivel == .secao ? .rotuloSecao : .rotuloAba))
            .foregroundStyle(cor)
    }
}

// MARK: - Chip

struct BXChip: View {
    enum Estilo: Sendable {
        /// Mono 11, fundo superficie2, borda linha, pílula, padding 5/12 ("CARTEIRA BLAXX").
        case eyebrow
        /// Mono 11/700, fundo limaSuave, borda neon, padding 8/14 ("OLÁ, CLIENTE").
        case saudacao
        /// Fundo tinta, texto NEON (permitido sobre preto): "EM PROCESSAMENTO", "CLIENTE", "ATUAL".
        case preto
        /// Fundo neon, texto tinta ("+5.000 pts").
        case neon
    }

    let texto: String
    let estilo: Estilo

    init(_ texto: String, _ estilo: Estilo) {
        self.texto = texto
        self.estilo = estilo
    }

    var body: some View {
        switch estilo {
        case .eyebrow:
            Text(texto).bxFonte(.rotulo)
                .foregroundStyle(BXCor.tinta)
                .padding(.vertical, 5).padding(.horizontal, 12)
                .background(BXCor.superficie2, in: Capsule())
                .overlay(Capsule().strokeBorder(BXCor.linha, lineWidth: 1))
        case .saudacao:
            Text(texto).bxFonte(.monoForte)
                .foregroundStyle(BXCor.tinta)
                .padding(.vertical, 8).padding(.horizontal, 14)
                .background(BXCor.limaSuave, in: Capsule())
                .overlay(Capsule().strokeBorder(BXCor.neon, lineWidth: 1))
        case .preto:
            Text(texto).bxFonte(.monoForte)
                .bxTextoNeon()
                .padding(.vertical, 6).padding(.horizontal, 12)
                .background(BXCor.tinta, in: Capsule())
        case .neon:
            Text(texto).font(BXFonte.fonte(.monoForte, tamanho: 12))
                .foregroundStyle(BXCor.tinta)
                .padding(.vertical, 6).padding(.horizontal, 12)
                .background(BXCor.neon, in: Capsule())
        }
    }
}

// MARK: - Status

struct BXStatus: View {
    enum Tipo: Sendable { case ok, aviso, perigo, info }
    let texto: String
    let tipo: Tipo
    let ponto: Bool

    init(_ texto: String, _ tipo: Tipo, ponto: Bool = true) {
        self.texto = texto
        self.tipo = tipo
        self.ponto = ponto
    }

    private var cores: (fundo: Color, texto: Color) {
        switch tipo {
        case .ok: return (BXCor.okFundo, BXCor.okTexto)
        case .aviso: return (BXCor.avisoFundo, BXCor.avisoTexto)
        case .perigo: return (BXCor.perigoFundo, BXCor.perigoTexto)
        case .info: return (BXCor.infoFundo, BXCor.infoTexto)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if ponto { Circle().fill(cores.texto).frame(width: 6, height: 6) }
            Text(texto).bxFonte(.monoForte)
        }
        .foregroundStyle(cores.texto)
        .padding(.vertical, 6).padding(.horizontal, 11)
        .background(cores.fundo, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pílula de filtro

struct BXPilula: View {
    enum Estilo: Sendable {
        /// Raio 8, altura 40, mono 11 MAIÚSC, contador dentro da pílula (filtros de parceiros).
        case kit
        /// Raio 999, altura 44, 13/700 (filtros das páginas de conta).
        case conta
    }

    let texto: String
    let contador: Int?
    let ativa: Bool
    let tracejada: Bool
    let estilo: Estilo
    let animacao: Namespace.ID?
    let acao: () -> Void

    /// - Parameter animacao: namespace compartilhado pelas pílulas de um mesmo grupo; com ele, o fundo
    ///   neon da pílula ativa desliza de uma para outra (`matchedGeometryEffect`).
    init(_ texto: String, contador: Int? = nil, ativa: Bool, tracejada: Bool = false,
         estilo: Estilo = .kit, animacao: Namespace.ID? = nil, acao: @escaping () -> Void) {
        self.texto = texto
        self.contador = contador
        self.ativa = ativa
        self.tracejada = tracejada
        self.estilo = estilo
        self.animacao = animacao
        self.acao = acao
    }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: estilo == .kit ? BXRaio.xxs : 22, style: .continuous)
        Button(action: acao) {
            HStack(spacing: 8) {
                Text(texto)
                    .bxFonte(estilo == .kit ? .rotulo : .botao)
                if let contador {
                    Text(estilo == .kit ? "\(contador)" : BXFormato.pontos(contador))
                        .font(BXFonte.fonte(.recibo, tamanho: 11))
                        .foregroundStyle(ativa ? BXCor.tinta : BXCor.cinza)
                }
            }
            .foregroundStyle(BXCor.tinta)
            .lineLimit(1)
            .padding(.horizontal, estilo == .kit ? 12 : 16)
            .frame(minHeight: estilo == .kit ? 40 : 44)
            .background {
                if ativa {
                    forma.fill(BXCor.neon).modifier(BXGeometriaCompartilhada(id: "bx-pilula-ativa", ns: animacao))
                } else {
                    forma.fill(BXCor.superficie)
                }
            }
            .overlay {
                if tracejada {
                    forma.strokeBorder(BXCor.pontilhado, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                } else if !ativa {
                    forma.strokeBorder(BXCor.linha, lineWidth: 1)
                }
            }
            .contentShape(forma)
        }
        .buttonStyle(BXEstiloPressao())
        .sensoryFeedback(.selection, trigger: ativa)
        .accessibilityAddTraits(ativa ? .isSelected : [])
        .accessibilityLabel(contador.map { "\(texto), \($0)" } ?? texto)
    }
}

/// `matchedGeometryEffect` só quando há namespace (o grupo decide se as pílulas animam juntas).
struct BXGeometriaCompartilhada: ViewModifier {
    let id: String
    let ns: Namespace.ID?
    func body(content: Content) -> some View {
        if let ns { content.matchedGeometryEffect(id: id, in: ns) } else { content }
    }
}

// MARK: - Abas segmentadas

struct BXAbas<Valor: Hashable>: View {
    enum Ativo: Sendable {
        /// Texto papel sobre tinta (extrato).
        case papel
        /// Texto neon sobre tinta (resgates).
        case neon
    }

    @Binding var selecao: Valor
    let opcoes: [(Valor, String)]
    let ativo: Ativo
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduzido

    init(selecao: Binding<Valor>, opcoes: [(Valor, String)], ativo: Ativo = .papel) {
        self._selecao = selecao
        self.opcoes = opcoes
        self.ativo = ativo
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(opcoes.enumerated()), id: \.offset) { _, op in
                let marcada = op.0 == selecao
                Button {
                    withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido)) { selecao = op.0 }
                } label: {
                    Group {
                        if marcada && ativo == .neon {
                            Text(op.1).bxTextoNeon()
                        } else {
                            Text(op.1).foregroundStyle(marcada ? BXCor.papel : BXCor.tinta)
                        }
                    }
                    .font(BXFonte.fonte(.botao, tamanho: 13.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background {
                        if marcada {
                            Capsule().fill(BXCor.tinta)
                                .matchedGeometryEffect(id: "aba-ativa", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(marcada ? .isSelected : [])
            }
        }
        .padding(5)
        .background(BXCor.superficie, in: Capsule())
        .overlay(Capsule().strokeBorder(BXCor.linha, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: selecao)
    }
}

// MARK: - Progresso

struct BXProgresso: View {
    let fracao: Double
    let altura: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduzido

    init(fracao: Double, altura: CGFloat = 12) {
        self.fracao = fracao
        self.altura = altura
    }

    var body: some View {
        let f = max(0, min(1, fracao.isFinite ? fracao : 0))
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(BXCor.superficie2)
                Capsule().fill(BXCor.neon)
                    .frame(width: f == 0 ? 0 : max(altura, g.size.width * f))
            }
            .overlay(Capsule().strokeBorder(BXCor.linha, lineWidth: 1))
        }
        .frame(height: altura)
        .animation(BXMovimento.ou(.easeOut(duration: 0.6), reduzido: reduzido), value: f)
        .accessibilityElement()
        .accessibilityLabel("Progresso")
        .accessibilityValue("\(Int((f * 100).rounded())) por cento")
    }
}
