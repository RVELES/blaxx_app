//
//  BXTelasConta.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Contrato que a casca (G1) chama:
//    BXTelasConta.tela(_ destino: BXDestino) -> some View
//  resolvendo .perfil, .seguranca, .privacidade, .convidar, .ajuda, .faq,
//  SEM NavigationStack próprio (a casca já tem um por aba) e SEM barra de topo (a casca aplica `.bxBarraTopo`).
//  Telas internas do grupo (sheets, passos) ficam dentro do grupo. API do núcleo: docs/redesenho/06-nucleo.md.
//
//  Demonstração (só DEBUG, §4): -BXTela perfil|seguranca|privacidade|convidar|ajuda|faq
//    -BXSubtela senha|totp|2fa|celular|excluir|chamado|chamado-preenchido|sair
//    -BXAncora dados|risco (perfil) · autenticacao|sessoes|historico|praticas (segurança)
//              consentimentos|dados|excluir (privacidade) · perguntas|chamado (ajuda) · <id da seção> (faq)
//

import SwiftUI

@MainActor enum BXTelasConta {
    @ViewBuilder static func tela(_ destino: BXDestino) -> some View {
        switch destino {
        case .perfil: BXPerfilTela()
        case .seguranca: BXSegurancaTela()
        case .privacidade: BXPrivacidadeTela()
        case .convidar: BXConvidarTela()
        case .ajuda: BXAjudaTela()
        case .faq: BXFaqTela()
        default: BXEmConstrucaoConta(titulo: titulo(destino))
        }
    }

    /// Nome da tela (título de acessibilidade e da barra quando empilhada).
    static func titulo(_ destino: BXDestino) -> String {
        switch destino {
        case .perfil: return "Perfil"
        case .seguranca: return "Segurança"
        case .privacidade: return "Privacidade e dados"
        case .convidar: return "Convidar amigos"
        case .ajuda: return "Central de ajuda"
        case .faq: return "Perguntas frequentes"
        default: return "Tela"
        }
    }
}

/// Destino que não é deste grupo (não deve acontecer): estado honesto, nada inventado.
private struct BXEmConstrucaoConta: View {
    let titulo: String

    var body: some View {
        ScrollView {
            BXEstadoVazio(icone: .info, titulo: "Tela indisponível",
                          texto: "\(titulo): esta tela não pertence à área de conta.")
                .padding(.horizontal, BXEspaco.margem)
                .padding(.vertical, BXEspaco.secao)
                .frame(maxWidth: BXEspaco.colunaMax)
                .frame(maxWidth: .infinity)
        }
        .background(BXCor.chao, in: Rectangle())
    }
}
