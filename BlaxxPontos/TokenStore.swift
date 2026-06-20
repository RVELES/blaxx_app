//
//  TokenStore.swift
//  BlaxxPontos
//
//  Armazenamento seguro (Keychain) dos dados sensíveis da sessão:
//    - JWT de autenticação
//    - perfil do usuário (contém CPF/e-mail = PII)
//
//  Antes ambos ficavam em UserDefaults — texto claro no container do app,
//  incluídos em backups (iTunes/Finder/iCloud) e legíveis por qualquer cópia
//  do sandbox. Para um app financeiro isso é OWASP Mobile M9 (Insecure Data
//  Storage). O Keychain mantém o segredo cifrado pelo Secure Enclave e fora
//  de backups quando usamos *ThisDeviceOnly.
//

import Foundation
import Security

enum TokenStore {
    private static let service = "com.blaxx.pontos.auth"
    private static let tokenAccount = "blaxx_auth_token"
    private static let profileAccount = "blaxx_user"
    // Chaves antigas em UserDefaults, migradas uma única vez.
    private static let legacyTokenKey = "blaxx_auth_token"
    private static let legacyProfileKey = "blaxx_user"

    // MARK: - Token (String)

    static func get() -> String? {
        guard let data = read(account: tokenAccount),
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    static func set(_ token: String) {
        write(Data(token.utf8), account: tokenAccount)
    }

    static func clear() {
        delete(account: tokenAccount)
    }

    // MARK: - Perfil do usuário (Data — JSON do BlaxxUser, contém PII)

    static func getProfileData() -> Data? {
        read(account: profileAccount)
    }

    static func setProfile(_ data: Data) {
        write(data, account: profileAccount)
    }

    static func clearProfile() {
        delete(account: profileAccount)
    }

    // MARK: - Migração única de UserDefaults → Keychain

    static func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard

        if let legacyToken = defaults.string(forKey: legacyTokenKey), !legacyToken.isEmpty {
            if get() == nil { set(legacyToken) }
            defaults.removeObject(forKey: legacyTokenKey)
        }
        if let legacyProfile = defaults.data(forKey: legacyProfileKey) {
            if getProfileData() == nil { setProfile(legacyProfile) }
            defaults.removeObject(forKey: legacyProfileKey)
        }
    }

    // MARK: - Primitivas Keychain

    private static func read(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    private static func write(_ data: Data, account: String) {
        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary,
                                         attrs as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery(account: account)
            addQuery[kSecValueData as String] = data
            // Disponível após o primeiro unlock (necessário p/ refresh em
            // background) e nunca sincronizado em iCloud/backup.
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
