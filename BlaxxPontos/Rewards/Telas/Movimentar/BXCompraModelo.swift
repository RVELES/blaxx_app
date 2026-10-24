//
//  BXCompraModelo.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Tipos da compra de pontos: o pedido que abre a folha de pagamento, as folhas da tela Comprar
//  e textos derivados (rótulo do pacote, status da cobrança). PIX aqui é só meio de pagamento.
//

import SwiftUI

/// O que a folha de pagamento deve cobrar.
enum BXPedidoCompra: Hashable, Identifiable {
    /// Pacote da vitrine (`POST /pix/charge {package}`).
    case pacote(chave: String, rotulo: String)
    /// Valor livre (`POST /pix/charge {amount_brl}`).
    case valor(Decimal)
    /// Cobrança pendente reaberta pelo histórico (consulta o status antes de mostrar o QR).
    case reabrir(BXCobrancaPix)

    var id: String {
        switch self {
        case .pacote(let chave, _): return "pacote-\(chave)"
        case .valor(let v): return "valor-\(v)"
        case .reabrir(let c): return "reabrir-\(c.id)"
        }
    }

    /// Pedido equivalente para "Gerar novo código" depois que uma cobrança expirou.
    var novoPedido: BXPedidoCompra {
        guard case .reabrir(let c) = self else { return self }
        if c.ehValorLivre { return .valor(c.valor) }
        let chave = c.pacote ?? ""
        return .pacote(chave: chave, rotulo: BXTextoCompra.rotuloPacote(chave))
    }
}

/// Folhas da tela Comprar (uma de cada vez).
enum BXFolhaCompra: Identifiable, Hashable {
    case valorLivre
    case pagamento(BXPedidoCompra)

    var id: String {
        switch self {
        case .valorLivre: return "valor-livre"
        case .pagamento(let p): return p.id
        }
    }
}

nonisolated enum BXTextoCompra {
    /// "Plus" para a chave "plus"; "Valor livre" sem pacote.
    static func rotuloPacote(_ chave: String?) -> String {
        guard let chave, !chave.isEmpty, chave != "custom" else { return "Valor livre" }
        return chave.prefix(1).uppercased() + chave.dropFirst()
    }

    /// Status da cobrança para o histórico e a folha.
    static func status(_ s: BXStatusCobranca) -> (texto: String, tipo: BXStatus.Tipo) {
        switch s {
        case .pendente, .aguardandoConfirmacao: return ("Aguardando pagamento", .aviso)
        case .paga: return ("Paga", .ok)
        case .expirada: return ("Expirada", .perigo)
        case .estornada: return ("Estornada", .info)
        case .recusada: return ("Recusada", .perigo)
        case .desconhecido: return ("Em análise", .info)
        }
    }

    /// "29:41"
    static func contagem(_ segundos: Int) -> String {
        let s = max(0, segundos)
        return String(format: "%02ld:%02ld", s / 60, s % 60)
    }
}

/// Cabeça das folhas do grupo: rótulo mono à esquerda e "Fechar" (glifo) à direita.
struct BXCabecaFolha: View {
    let rotulo: String
    let aoFechar: () -> Void

    init(_ rotulo: String, aoFechar: @escaping () -> Void) {
        self.rotulo = rotulo
        self.aoFechar = aoFechar
    }

    var body: some View {
        HStack {
            Text(rotulo).bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Button(action: aoFechar) {
                BXGlifo(.fechar, cor: BXCor.tinta, lado: 18)
                    .frame(width: 44, height: 44)
                    .background(BXCor.superficie2, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(BXEstiloPressao())
            .accessibilityLabel("Fechar")
        }
    }
}
