//
//  BXFavoritos.swift
//  BlaxxPontos · Redesenho "Embarque" · G4 (Descobrir e resgatar)
//
//  Favoritos de parceiros guardados SÓ neste aparelho (UserDefaults), como o web guarda no navegador
//  (`localStorage['blaxx_fav_partners']`). Nada vai para o servidor.
//

import Foundation
import Observation
import SwiftUI

@MainActor @Observable final class BXFavoritos {
    static let shared = BXFavoritos()

    private static let chave = "blaxx_fav_partners"
    private(set) var ids: Set<String>

    private init() {
        if BXDemo.ativo || BXDemo.visitante {
            // Modo demonstração: começa com um favorito de exemplo e não toca no que o aparelho guardou.
            ids = BXDemo.ativo ? ["cafe-ponto-doce"] : []
        } else {
            let lista = (UserDefaults.standard.array(forKey: Self.chave) as? [String]) ?? []
            ids = Set(lista)
        }
    }

    func contem(_ id: String) -> Bool { ids.contains(id) }

    func alternar(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        guard !(BXDemo.ativo || BXDemo.visitante) else { return }
        UserDefaults.standard.set(Array(ids).sorted(), forKey: Self.chave)
    }

    /// Quantos favoritos existem na lista dada (favorito de parceiro que saiu da rede não conta).
    func contagem(em parceiros: [BXParceiro]) -> Int {
        parceiros.reduce(0) { $0 + (ids.contains($1.id) ? 1 : 0) }
    }
}

/// Cache em memória do que as telas de Descobrir já trouxeram (a lista de parceiros alimenta o detalhe
/// enquanto ele carrega e o resumo dos benefícios). Some ao fechar o app; nunca é dado inventado.
@MainActor enum BXCatalogo {
    static var parceiros: [BXParceiro] = []
    static func parceiro(id: String) -> BXParceiro? { parceiros.first { $0.id == id } }
}

/// Layout que quebra linha (pílulas de categoria e de filtro).
struct BXFluxoDescobrir: Layout {
    var espaco: CGFloat = 8
    var espacoLinha: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largura = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, alturaLinha: CGFloat = 0, maiorX: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(ProposedViewSize(width: largura, height: nil))
            if x > 0 && x + t.width > largura {
                y += alturaLinha + espacoLinha
                x = 0
                alturaLinha = 0
            }
            x += t.width + espaco
            maiorX = max(maiorX, x - espaco)
            alturaLinha = max(alturaLinha, t.height)
        }
        return CGSize(width: proposal.width ?? maiorX, height: y + alturaLinha)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, alturaLinha: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + t.width > bounds.maxX {
                y += alturaLinha + espacoLinha
                x = bounds.minX
                alturaLinha = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(t.width, bounds.width), height: t.height))
            x += t.width + espaco
            alturaLinha = max(alturaLinha, t.height)
        }
    }
}

/// Coluna padrão das telas de Descobrir: margem 16, no máximo 560 pt, fundo chão.
struct BXColunaDescobrir<Conteudo: View>: View {
    let conteudo: Conteudo
    init(@ViewBuilder conteudo: () -> Conteudo) { self.conteudo = conteudo() }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { conteudo }
            .padding(.horizontal, BXEspaco.margem)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: BXEspaco.colunaMax)
            .frame(maxWidth: .infinity)
    }
}

/// Rola até a âncora de `-BXAncora` (fotos de telas longas, só DEBUG lê o argumento).
struct BXAncoraDemo: ViewModifier {
    let pronto: Bool
    let proxy: ScrollViewProxy
    func body(content: Content) -> some View {
        content.task(id: pronto) {
            guard pronto, let a = BXDemo.ancora else { return }
            try? await Task.sleep(for: .milliseconds(450))
            proxy.scrollTo(a, anchor: .top)
        }
    }
}

/// Farelo mono "INÍCIO / PARCEIROS / NOME" (detalhes de parceiro e benefício).
struct BXFarelo: View {
    let itens: [(String, (() -> Void)?)]
    var body: some View {
        BXFluxoDescobrir(espaco: 6, espacoLinha: 4) {
            ForEach(Array(itens.enumerated()), id: \.offset) { i, item in
                HStack(spacing: 6) {
                    if let acao = item.1 {
                        Button(action: acao) {
                            Text(item.0).underline(true, color: BXCor.pontilhado)
                                .foregroundStyle(BXCor.tinta)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(item.0).foregroundStyle(BXCor.cinza).lineLimit(1)
                    }
                    if i < itens.count - 1 { Text("/").foregroundStyle(BXCor.cinza).accessibilityHidden(true) }
                }
            }
        }
        .bxFonte(.rotuloMedio)
        .accessibilityElement(children: .contain)
    }
}
