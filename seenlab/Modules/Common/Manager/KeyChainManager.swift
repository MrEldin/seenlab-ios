//
//  KeyChainManager.swift
//  seenlab
//
//  Keeps the JWT in the keychain (never in UserDefaults).
//

import Foundation
import Security

final class KeyChainManager {
    static let shared = KeyChainManager()
    private let service = "io.seenlab.app"
    private let account = "jwt"
    private var cached: String?
    private var loaded = false

    var token: String? {
        get {
            if !loaded { cached = read(); loaded = true }
            return cached
        }
        set {
            cached = newValue; loaded = true
            if let newValue { write(newValue) } else { delete() }
        }
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    private func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String) {
        delete()
        var q = query
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    private func delete() { SecItemDelete(query as CFDictionary) }
}
