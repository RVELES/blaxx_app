//
//  WalletCache.swift
//  BlaxxPontos
//
//  Cache leve do último wallet conhecido — UserDefaults (JSON). Evita
//  flash de "tela em branco" enquanto o backend carrega após reabertura
//  do app. Cache é considerado válido por 1 hora; depois disso a UI deve
//  marcar como "sem conexão" caso a request real falhe.
//
//  Não substitui o cache SwiftData (Item.swift) — é um buffer rápido para
//  uso imediato no `start()` do RewardsBackend.
//

import Foundation

enum WalletCache {
    private static let key = "wallet_cache_v1"
    private static let timestampKey = "wallet_cache_v1_savedAt"
    private static let validityInterval: TimeInterval = 60 * 60 // 1h

    /// Lê o cache se ainda válido (salvo nos últimos 60min). Retorna nil
    /// caso ausente ou expirado.
    static func read() -> WalletDTO? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let savedAt = UserDefaults.standard.object(forKey: timestampKey) as? Date else {
            return nil
        }
        if Date().timeIntervalSince(savedAt) > validityInterval { return nil }
        return try? JSONDecoder().decode(WalletDTO.self, from: data)
    }

    /// Persiste o wallet atual. Chamar após cada refresh bem-sucedido.
    static func write(_ dto: WalletDTO) {
        if let data = try? JSONEncoder().encode(dto) {
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.set(Date(), forKey: timestampKey)
        }
    }

    /// Apaga o cache (chamar no logout).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: timestampKey)
    }
}
