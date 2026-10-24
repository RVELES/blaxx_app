//
//  BXCasca.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Casca)
//
//  Casca do logado (§2.3 da spec): quatro pilhas (Início, Carteira, Comprar, Resgates), uma por aba,
//  mantidas vivas depois da primeira visita; barra de abas preta igual à `.bx-tabbar` (Menu abre a gaveta
//  pela esquerda); faixa offline acima da barra de abas. A barra de abas fica atrás do teclado.
//  Toque duplo na aba ativa volta à raiz (`nav.retocar`).
//

import SwiftUI

struct BXCasca: View {
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXConectividade.self) private var conectividade
    @Environment(\.accessibilityReduceMotion) private var reduzido

    @State private var visitadas: Set<BXAba> = []
    @State private var alturaBarra: CGFloat = 72

    var body: some View {
        @Bindable var nav = nav
        ZStack {
            ForEach(BXAba.visiveis, id: \.self) { aba in
                if visitadas.contains(aba) || aba == nav.aba {
                    let ativa = aba == nav.aba
                    pilha(aba)
                        .opacity(ativa ? 1 : 0)
                        .allowsHitTesting(ativa)
                        .accessibilityHidden(!ativa)
                        .zIndex(ativa ? 1 : 0)
                }
            }
        }
        .safeAreaPadding(.bottom, alturaBarra)
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if conectividade.mostrarFaixa {
                    BXFaixaOffline(verificando: conectividade.verificando) { conectividade.verificar() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                BXTabBar(selecionada: $nav.aba,
                         aoTocarMenu: { nav.abrirGaveta() },
                         aoRetocar: { nav.retocar($0) })
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { alturaBarra = $0 }
            }
            .animation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido), value: conectividade.mostrarFaixa)
            .ignoresSafeArea(.keyboard)
        }
        .overlay {
            BXGavetaConteiner(aberta: $nav.gavetaAberta, lado: .esquerda) {
                BXGavetaMenuLogado()
            }
        }
        .onAppear { visitadas.insert(nav.aba) }
        .onChange(of: nav.aba) { _, nova in visitadas.insert(nova) }
    }

    private func pilha(_ aba: BXAba) -> some View {
        NavigationStack(path: nav.vinculo(pilha: aba)) {
            BXRoteador.tela(nav.raiz(da: aba))
                .id(nav.raiz(da: aba))
                .bxBarraDaCasca(raiz: true, destino: nav.raiz(da: aba))
                .navigationDestination(for: BXDestino.self) { d in
                    BXRoteador.tela(d)
                        .bxBarraDaCasca(raiz: false, destino: d)
                }
        }
    }
}
