//
//  BXCofre.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  Guarda o par de tokens (acesso 30 min + renovação 30 dias) no Keychain (§1.7.2 da spec).
//  Serviço NOVO "com.blaxx.pontos.sessao.v2" (não mistura com o TokenStore antigo), acessível só
//  depois do primeiro desbloqueio e só neste aparelho (fora de backup). Em modo demonstração: só memória.
//  Nunca guarda senha.
//

import Foundation
import Security

nonisolated struct BXTokens: Codable, Sendable, Equatable, CustomStringConvertible {
    let acesso: String
    let renovacao: String
    let emitidoEm: Date

    init(acesso: String, renovacao: String, emitidoEm: Date = .now) {
        self.acesso = acesso
        self.renovacao = renovacao
        self.emitidoEm = emitidoEm
    }

    /// Idade do token de acesso.
    func idade(agora: Date = .now) -> TimeInterval { agora.timeIntervalSince(emitidoEm) }

    /// Nunca imprime os tokens.
    var description: String { "BXTokens(emitidoEm: \(emitidoEm))" }
}

actor BXCofre {
    nonisolated static let shared = BXCofre(somenteMemoria: BXDemo.ativo || BXDemo.visitante)

    private let somenteMemoria: Bool
    private var memoria: BXTokens?
    private var carregado = false

    nonisolated private static let servico = "com.blaxx.pontos.sessao.v2"
    nonisolated private static let conta = "tokens"

    init(somenteMemoria: Bool) {
        self.somenteMemoria = somenteMemoria
    }

    func ler() -> BXTokens? {
        if somenteMemoria || carregado { return memoria }
        carregado = true
        memoria = Self.lerKeychain()
        return memoria
    }

    func gravar(_ t: BXTokens) {
        memoria = t
        carregado = true
        if !somenteMemoria { Self.gravarKeychain(t) }
    }

    func limpar() {
        memoria = nil
        carregado = true
        if !somenteMemoria { Self.apagarKeychain() }
    }

    /// Há sessão guardada (sem expor os tokens).
    func temSessao() -> Bool { ler() != nil }

    // MARK: - Keychain

    nonisolated private static func consultaBase() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: servico,
         kSecAttrAccount as String: conta]
    }

    nonisolated private static func lerKeychain() -> BXTokens? {
        var q = consultaBase()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var saida: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &saida) == errSecSuccess, let dados = saida as? Data else { return nil }
        return try? JSONDecoder().decode(BXTokens.self, from: dados)
    }

    nonisolated private static func gravarKeychain(_ t: BXTokens) {
        guard let dados = try? JSONEncoder().encode(t) else { return }
        let q = consultaBase()
        let atualizacao: [String: Any] = [kSecValueData as String: dados,
                                          kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let r = SecItemUpdate(q as CFDictionary, atualizacao as CFDictionary)
        if r == errSecItemNotFound {
            var novo = q
            novo[kSecValueData as String] = dados
            novo[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(novo as CFDictionary, nil)
        }
    }

    nonisolated private static func apagarKeychain() {
        SecItemDelete(consultaBase() as CFDictionary)
    }
}
