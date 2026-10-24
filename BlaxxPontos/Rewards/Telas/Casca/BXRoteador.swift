//
//  BXRoteador.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Casca)
//
//  Resolve cada `BXDestino` na tela do grupo dono (§5.1 de 06-nucleo.md) e aplica a barra preta do topo
//  conforme o contexto (raiz/empilhada, logado/visitante). As telas dos grupos não têm NavigationStack
//  nem barra própria.
//

import SwiftUI

@MainActor enum BXRoteador {
    @ViewBuilder static func tela(_ d: BXDestino) -> some View {
        switch d.grupo {
        case .acesso: BXTelasAcesso.tela(d)
        case .saldo: BXTelasSaldo.tela(d)
        case .movimentar: BXTelasMovimentar.tela(d)
        case .descobrir: BXTelasDescobrir.tela(d)
        case .conta: BXTelasConta.tela(d)
        }
    }

    static func titulo(_ d: BXDestino) -> String {
        switch d.grupo {
        case .acesso: return BXTelasAcesso.titulo(d)
        case .saldo: return BXTelasSaldo.titulo(d)
        case .movimentar: return BXTelasMovimentar.titulo(d)
        case .descobrir: return BXTelasDescobrir.titulo(d)
        case .conta: return BXTelasConta.titulo(d)
        }
    }

    /// Mesmo "lugar" ignorando parâmetros (para marcar o item atual da gaveta).
    static func mesmoLugar(_ a: BXDestino, _ b: BXDestino) -> Bool {
        switch (a, b) {
        case (.extrato, .extrato), (.comprar, .comprar), (.enviar, .enviar), (.parceiros, .parceiros),
             (.resgates, .resgates), (.redefinirSenha, .redefinirSenha):
            return true
        default:
            return a == b
        }
    }
}

extension View {
    /// Barra preta do topo da casca. `raiz`: wordmark à esquerda; empilhada: voltar do sistema + wordmark no centro.
    func bxBarraDaCasca(raiz: Bool, destino: BXDestino) -> some View {
        modifier(BXBarraDaCasca(raiz: raiz, destino: destino))
    }
}

private struct BXBarraDaCasca: ViewModifier {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    let raiz: Bool
    let destino: BXDestino

    private var modo: BXBarraTopoModo {
        switch (nav.logado, raiz) {
        case (true, true): return .raizLogado
        case (true, false): return .empilhadaLogado
        case (false, true): return .raizVisitante
        case (false, false): return .empilhadaVisitante
        }
    }

    func body(content: Content) -> some View {
        content
            .bxBarraTopo(modo, naoLidas: sessao.naoLidas, inicial: sessao.usuario?.primeiroNome,
                         aoSino: { nav.ir(.notificacoes) },
                         aoAvatar: { nav.ir(.perfil) },
                         aoEntrar: { nav.ir(.entrar) },
                         aoMenu: { nav.abrirGaveta() })
            #if os(iOS)
            .toolbarRole(.editor)          // botão voltar sem o título da tela anterior
            #endif
    }
}
