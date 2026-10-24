//
//  BXTelasDescobrir.swift
//  BlaxxPontos · Redesenho "Embarque" · G4 (Descobrir e resgatar)
//
//  Contrato que a casca (G1) chama: `BXTelasDescobrir.tela(_ destino: BXDestino) -> some View`, resolvendo
//  .parceiros(busca:), .parceiro(id:), .resgates(_), .beneficio(id:), .voucher(id:), .campanhas,
//  SEM NavigationStack próprio (a casca já tem um por aba) e SEM barra de topo (a casca aplica `.bxBarraTopo`).
//  Os públicos funcionam para visitante; ações que exigem conta chamam `nav.pedirEntrada(depois:)`.
//  Telas internas (confirmar resgate, resgate concluído, mais categorias) ficam dentro do grupo.
//

import SwiftUI

@MainActor enum BXTelasDescobrir {
    @ViewBuilder static func tela(_ destino: BXDestino) -> some View {
        switch destino {
        case .parceiros(let busca):
            BXParceirosTela(busca: busca)
        case .parceiro(let id):
            BXParceiroTela(id: id)
        case .resgates(let aba):
            BXResgatesTela(aba: aba)
        case .beneficio(let id):
            BXBeneficioTela(id: id)
        case .voucher(let id):
            BXVoucherTela(id: id)
        case .campanhas:
            BXCampanhasTela()
        default:
            BXEstadoVazio(icone: .info, titulo: "Tela indisponível")
        }
    }

    /// Nome da tela (títulos de acessibilidade e da barra, se a casca quiser).
    static func titulo(_ destino: BXDestino) -> String {
        switch destino {
        case .parceiros: return "Parceiros"
        case .parceiro: return "Parceiro"
        case .resgates: return "Resgates"
        case .beneficio: return "Benefício"
        case .voucher: return "Voucher"
        case .campanhas: return "Campanhas"
        default: return "Tela"
        }
    }
}
