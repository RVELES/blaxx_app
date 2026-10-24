//
//  BXTelasMovimentar.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Contrato que a casca (G1) chama:
//    BXTelasMovimentar.tela(_ destino: BXDestino) -> some View
//  resolvendo .comprar(pacote:), .historicoCompras, .enviar(para:), .receber,
//  SEM NavigationStack próprio (a casca já tem um por aba) e SEM barra de topo (a casca aplica `.bxBarraTopo`).
//  Sheets e passos internos (valor livre, pagamento, compra concluída, confirmar envio, envio concluído,
//  leitor de QR) ficam dentro do grupo.
//
//  Regra do dono: a palavra "PIX" só aparece nos arquivos de compra (Comprar, Valor livre, Pagamento,
//  Compra concluída, Histórico). Enviar e Receber nunca falam em PIX.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

@MainActor enum BXTelasMovimentar {
    @ViewBuilder static func tela(_ destino: BXDestino) -> some View {
        switch destino {
        case .comprar(let pacote):
            BXComprarTela(pacoteInicial: pacote)
        case .historicoCompras:
            BXHistoricoComprasTela()
        case .enviar(let para):
            BXEnviarTela(paraInicial: para)
        case .receber:
            BXReceberTela()
        default:
            BXEstadoVazio(icone: .info, titulo: "Tela indisponível")
                .padding(BXEspaco.margem)
        }
    }

    /// Nome da tela (títulos de acessibilidade e da barra).
    static func titulo(_ destino: BXDestino) -> String {
        switch destino {
        case .comprar: return "Comprar pontos"
        case .historicoCompras: return "Histórico de compras"
        case .enviar: return "Enviar pontos"
        case .receber: return "Receber pontos"
        default: return "Tela"
        }
    }
}

// MARK: - Peças comuns do grupo

/// Coluna padrão das telas do grupo: rolagem, chão, margem 16, coluna de no máximo 560 pt centralizada,
/// teclado recolhe ao rolar e rola até `BXDemo.ancora` (fotos de telas longas).
struct BXColunaMovimentar<Conteudo: View>: View {
    let conteudo: Conteudo
    let atualizar: (() async -> Void)?

    init(atualizar: (() async -> Void)? = nil, @ViewBuilder conteudo: () -> Conteudo) {
        self.atualizar = atualizar
        self.conteudo = conteudo()
    }

    var body: some View {
        ScrollViewReader { leitor in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { conteudo }
                    .padding(.horizontal, BXEspaco.margem)
                    .padding(.top, 24)
                    .padding(.bottom, BXEspaco.secao)
                    .frame(maxWidth: BXEspaco.colunaMax)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BXCor.chao, in: Rectangle())
            .modifier(BXAtualizavel(atualizar: atualizar))
            .task {
                guard let ancora = BXDemo.ancora else { return }
                try? await Task.sleep(for: .milliseconds(700))
                leitor.scrollTo(ancora, anchor: .top)
            }
        }
    }
}

/// `.refreshable` só quando a tela tem o que recarregar.
private struct BXAtualizavel: ViewModifier {
    let atualizar: (() async -> Void)?
    func body(content: Content) -> some View {
        if let atualizar {
            content.refreshable { await atualizar() }
        } else {
            content
        }
    }
}

/// Aviso legal mono, igual ao rodapé das páginas de compra do web.
struct BXAvisoLegalPontos: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BXIcone(.info, tamanho: .atalho)
            VStack(alignment: .leading, spacing: 6) {
                Text("Aviso importante").bxFonte(.monoForte).foregroundStyle(BXCor.tinta)
                Text("Os pontos BlaXx não são moeda, depósito, investimento, valor mobiliário ou criptoativo. São créditos promocionais de uso restrito dentro da plataforma BlaXx.")
                    .bxFonte(.legenda)
                    .foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BXEspaco.cartao)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
        .accessibilityElement(children: .combine)
    }
}

/// Caixa de aviso (amarela) ou de erro (vermelha) dentro de formulários e sheets.
struct BXCaixaAviso: View {
    enum Tipo { case aviso, erro, info }
    let texto: String
    let tipo: Tipo

    init(_ texto: String, _ tipo: Tipo = .aviso) {
        self.texto = texto
        self.tipo = tipo
    }

    private var cores: (Color, Color) {
        switch tipo {
        case .aviso: return (BXCor.avisoFundo, BXCor.avisoTexto)
        case .erro: return (BXCor.perigoFundo, BXCor.perigoTexto)
        case .info: return (BXCor.infoFundo, BXCor.infoTexto)
        }
    }

    var body: some View {
        let c = cores
        let forma = RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous)
        HStack(alignment: .top, spacing: 12) {
            BXIcone(tipo == .info ? .info : .alerta, tamanho: .livre(lado: 26, raio: 7))
            Text(texto)
                .bxFonte(.corpo)
                .foregroundStyle(c.1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(c.0, in: forma)
        .overlay(forma.strokeBorder(c.1.opacity(0.22), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

#if os(iOS)
/// Brilho da tela no máximo enquanto a vista estiver visível e o app ativo (QR de pagamento e Receber).
/// Restaura o brilho anterior ao sumir ou ao ir para o segundo plano.
struct BXBrilhoMaximo: ViewModifier {
    @Environment(\.scenePhase) private var fase
    @State private var anterior: CGFloat?

    private var tela: UIScreen? {
        let cenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (cenas.first { $0.activationState == .foregroundActive } ?? cenas.first)?.screen
    }

    private func aumentar() {
        guard anterior == nil, let tela else { return }
        anterior = tela.brightness
        tela.brightness = 1
    }

    private func restaurar() {
        guard let a = anterior else { return }
        tela?.brightness = a
        anterior = nil
    }

    func body(content: Content) -> some View {
        content
            .onAppear { aumentar() }
            .onDisappear { restaurar() }
            .onChange(of: fase) { _, f in
                if f == .active { aumentar() } else { restaurar() }
            }
    }
}
#endif

extension View {
    /// Brilho máximo enquanto visível (só iOS; nas outras plataformas não faz nada).
    @ViewBuilder func bxBrilhoMaximo() -> some View {
        #if os(iOS)
        modifier(BXBrilhoMaximo())
        #else
        self
        #endif
    }

    /// Aparência padrão das sheets do grupo (§3.1 item 6).
    func bxFolhaMovimentar(_ detents: Set<PresentationDetent>) -> some View {
        self
            .presentationDetents(detents)
            .presentationCornerRadius(24)
            .presentationBackground(BXCor.superficie)
            .presentationDragIndicator(.visible)
            .environment(\.colorScheme, .light)
    }
}
