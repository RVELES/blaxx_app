//
//  BXTelasAcesso.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Contrato que a casca chama: `BXTelasAcesso.tela(_ destino:)` resolve .boasVindas, .entrar, .cadastro,
//  .recuperarSenha, .redefinirSenha(token:) e .verificarEmail, sem NavigationStack próprio e sem barra de topo
//  (a casca aplica `.bxBarraTopo`). `.verificarEmail` normalmente é sheet do logado (BXRaiz); aqui também abre
//  como tela para o caso de chegar por pilha.
//

import SwiftUI

@MainActor enum BXTelasAcesso {
    @ViewBuilder static func tela(_ destino: BXDestino) -> some View {
        switch destino {
        case .boasVindas: BXBoasVindasTela()
        case .entrar: BXEntrarTela()
        case .cadastro: BXCadastroTela()
        case .recuperarSenha: BXRecuperarSenhaTela()
        case .redefinirSenha(let token): BXRedefinirSenhaTela(token: token)
        case .verificarEmail: BXVerificarEmailTela()
        default: EmptyView()
        }
    }

    /// Nome da tela (títulos de acessibilidade).
    static func titulo(_ destino: BXDestino) -> String {
        switch destino {
        case .boasVindas: return "Boas-vindas"
        case .entrar: return "Entrar"
        case .cadastro: return "Criar conta"
        case .recuperarSenha: return "Recuperar senha"
        case .redefinirSenha: return "Redefinir senha"
        case .verificarEmail: return "Verificar e-mail"
        default: return "Tela"
        }
    }
}
