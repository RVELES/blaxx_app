//
//  BXVisitanteCasca.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Casca)
//
//  Casca do visitante (§2.3): uma pilha com a boas-vindas na raiz. Topo: wordmark · "Entrar" · hambúrguer
//  (gaveta pela DIREITA, como no web). Destinos públicos empilham; os que exigem conta viram Entrar e seguem
//  para o destino depois do login (`nav.pedirEntrada(depois:)`).
//

import SwiftUI

struct BXVisitanteCasca: View {
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXConectividade.self) private var conectividade
    @Environment(\.accessibilityReduceMotion) private var reduzido

    var body: some View {
        @Bindable var nav = nav
        NavigationStack(path: nav.vinculoVisitante) {
            BXRoteador.tela(.boasVindas)
                .bxBarraDaCasca(raiz: true, destino: .boasVindas)
                .navigationDestination(for: BXDestino.self) { d in
                    BXRoteador.tela(d)
                        .bxBarraDaCasca(raiz: false, destino: d)
                }
        }
        .overlay(alignment: .bottom) {
            if conectividade.mostrarFaixa {
                BXFaixaOffline(verificando: conectividade.verificando) { conectividade.verificar() }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido), value: conectividade.mostrarFaixa)
        .overlay {
            BXGavetaConteiner(aberta: $nav.gavetaAberta, lado: .direita) {
                BXGavetaMenuVisitante()
            }
        }
    }
}
