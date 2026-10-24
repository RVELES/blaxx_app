//
//  BXTelasSaldo.swift
//  BlaxxPontos · Redesenho "Embarque" · G2 (Saldo: Início, Carteira, Extrato, Cartão BlaXx, Notificações)
//
//  Contrato que a casca (G1) chama: `BXTelasSaldo.tela(_:)`, resolvendo .inicio, .carteira, .extrato(_),
//  .cartaoBlaxx e .notificacoes, SEM NavigationStack próprio e SEM barra de topo (a casca aplica
//  `.bxBarraTopo`). O detalhe do lançamento é um sheet interno (`BXLancamentoSheet`).
//  Demonstração (DEBUG): -BXTela inicio|carteira|extrato[:entradas|saidas]|cartao|notificacoes,
//  -BXSubtela lancamento (abre o comprovante), -BXAncora <id> (âncoras listadas em cada tela).
//

import SwiftUI

@MainActor enum BXTelasSaldo {
    @ViewBuilder static func tela(_ destino: BXDestino) -> some View {
        switch destino {
        case .inicio: BXInicioTela()
        case .carteira: BXCarteiraTela()
        case .extrato(let filtro): BXExtratoTela(filtroInicial: filtro)
        case .cartaoBlaxx: BXCartaoBlaxxTela()
        case .notificacoes: BXNotificacoesTela()
        default: BXInicioTela()
        }
    }

    static func titulo(_ destino: BXDestino) -> String {
        switch destino {
        case .inicio: return "Início"
        case .carteira: return "Carteira"
        case .extrato: return "Extrato"
        case .cartaoBlaxx: return "Cartão BlaXx"
        case .notificacoes: return "Notificações"
        default: return "Tela"
        }
    }
}
