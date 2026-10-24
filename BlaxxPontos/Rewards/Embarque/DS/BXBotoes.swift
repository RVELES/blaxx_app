//
//  BXBotoes.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Botões do tema (02-inventario §2.7). Desabilitado = opacidade 0,45 no botão inteiro: como o texto
//  do primário é tinta, nunca vira "neon sobre cinza". Carregando = indicador no lugar do texto,
//  mantendo a largura.
//

import SwiftUI

struct BXBotao: View {
    enum Estilo: Sendable {
        /// Neon, texto tinta, 15/700, raio 12, padding 13/20, mín. 48; pressionado neonPressionado.
        case primario
        /// Tinta, texto superfície ("Entrar →", "Continuar →").
        case preto
        /// Superfície, borda 1 linha, texto tinta.
        case secundario
        /// Transparente, borda papel 35 %, texto papel (sobre o cartão preto).
        case vazadoSobrePreto
        /// CTA do cartão de embarque: neon, raio 12, padding 16, 16/700.
        case cartao
        /// Superfície, borda perigoTexto, texto perigoTexto (excluir conta).
        case perigo
    }

    let titulo: String
    let estilo: Estilo
    let icone: BXIconeNome?
    let carregando: Bool
    let larguraTotal: Bool
    let acao: () -> Void

    init(_ titulo: String, estilo: Estilo = .primario, icone: BXIconeNome? = nil,
         carregando: Bool = false, larguraTotal: Bool = true, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.estilo = estilo
        self.icone = icone
        self.carregando = carregando
        self.larguraTotal = larguraTotal
        self.acao = acao
    }

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 10) {
                if let icone {
                    // Sobre fundo neon o quadrado neon sumiria: ganha contorno tinta.
                    BXIcone(icone, tamanho: .livre(lado: 26, raio: 7),
                            contorno: estilo == .primario || estilo == .cartao)
                }
                Text(titulo)
                    .bxFonte(estilo == .cartao ? .botaoCartao : .botao)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .opacity(carregando ? 0 : 1)
            .overlay {
                if carregando {
                    ProgressView().tint(BXEstiloBotao.corTexto(estilo))
                }
            }
            .frame(maxWidth: larguraTotal ? .infinity : nil)
        }
        .buttonStyle(BXEstiloBotao(estilo: estilo))
        .allowsHitTesting(!carregando)
        .accessibilityLabel(carregando ? "\(titulo), carregando" : titulo)
    }
}

/// Estilo de botão do tema (pode ser usado direto em `Button` quando o rótulo for custom).
struct BXEstiloBotao: ButtonStyle {
    let estilo: BXBotao.Estilo
    @Environment(\.isEnabled) private var habilitado

    init(estilo: BXBotao.Estilo) { self.estilo = estilo }

    static func corTexto(_ e: BXBotao.Estilo) -> Color {
        switch e {
        case .primario, .cartao, .secundario: return BXCor.tinta
        case .preto: return BXCor.superficie
        case .vazadoSobrePreto: return BXCor.papel
        case .perigo: return BXCor.perigoTexto
        }
    }

    private func fundo(_ pressionado: Bool) -> Color {
        switch estilo {
        case .primario, .cartao: return pressionado ? BXCor.neonPressionado : BXCor.neon
        case .preto: return pressionado ? BXCor.tinta2 : BXCor.tinta
        case .secundario, .perigo: return pressionado ? BXCor.superficie2 : BXCor.superficie
        case .vazadoSobrePreto: return pressionado ? BXCor.papel.opacity(0.08) : .clear
        }
    }

    private var borda: Color? {
        switch estilo {
        case .secundario: return BXCor.linha
        case .vazadoSobrePreto: return BXCor.bordaSobrePreto
        case .perigo: return BXCor.perigoTexto
        default: return nil
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let forma = RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous)
        let vertical: CGFloat = estilo == .cartao ? 16 : 13
        let horizontal: CGFloat = estilo == .cartao ? 16 : 20
        configuration.label
            .foregroundStyle(Self.corTexto(estilo))
            .padding(.vertical, vertical)
            .padding(.horizontal, horizontal)
            .frame(minHeight: BXToque.botao)
            .background(fundo(configuration.isPressed), in: forma)
            .overlay { if let borda { forma.strokeBorder(borda, lineWidth: 1) } }
            .contentShape(forma)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(habilitado ? 1 : 0.45)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Link de seção: texto tinta 16 com sublinhado de 2 pt e seta tipográfica ("Valor livre →").
struct BXLinkSeta: View {
    let titulo: String
    let acao: () -> Void

    init(_ titulo: String, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.acao = acao
    }

    var body: some View {
        Button(action: acao) {
            Text("\(titulo) →")
                .bxFonte(.corpoKit)
                .foregroundStyle(BXCor.tinta)
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) { Rectangle().fill(BXCor.tinta).frame(height: 2) }
                .frame(minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(BXEstiloPressao())
        .accessibilityLabel(titulo)
        .accessibilityAddTraits(.isLink)
    }
}
