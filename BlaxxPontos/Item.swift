//
//  Item.swift (substituído — agora contém os modelos SwiftData do Blaxx Pontos)
//  BlaxxPontos
//
//  Cache local com SwiftData. Os dados de verdade vivem no backend Flask;
//  esses modelos servem para mostrar os últimos valores conhecidos quando
//  o backend estiver offline ou ainda carregando.
//

import Foundation
import SwiftData

@Model
final class CachedWallet {
    @Attribute(.unique) var userId: String
    var balancePts: Int
    var pendingPts: Int
    var balanceBRLEquiv: Double
    var updatedAt: Date

    init(userId: String, balancePts: Int = 0, pendingPts: Int = 0, balanceBRLEquiv: Double = 0) {
        self.userId = userId
        self.balancePts = balancePts
        self.pendingPts = pendingPts
        self.balanceBRLEquiv = balanceBRLEquiv
        self.updatedAt = Date()
    }

    func apply(_ dto: WalletDTO) {
        balancePts = dto.balance_pts
        pendingPts = dto.pending_pts
        balanceBRLEquiv = dto.balance_brl_equiv
        updatedAt = Date()
    }
}

@Model
final class CachedTransaction {
    @Attribute(.unique) var id: String
    var type: String
    var status: String
    var amountPts: Int
    var transactionDescription: String
    var reference: String?
    var createdAt: Date

    init(dto: TransactionDTO) {
        self.id = dto.id
        self.type = dto.type
        self.status = dto.status
        self.amountPts = dto.amount_pts
        self.transactionDescription = dto.description
        self.reference = dto.reference
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.createdAt = f.date(from: dto.created_at) ?? Date()
    }
}
