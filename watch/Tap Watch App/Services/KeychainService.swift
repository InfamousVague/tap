import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let relayURLKey = "com.mattssoftware.tap.relay-url"
    private let tokenKey = "com.mattssoftware.tap.token"

    /// Shared UserDefaults suite for widget extension access.
    /// Widgets can't reliably access the keychain on watchOS,
    /// so we mirror credentials here.
    private let sharedDefaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp")

    private init() {}

    // MARK: - Relay URL

    func getRelayURL() -> String? {
        // Try shared defaults first (works in both app and widget)
        if let url = sharedDefaults?.string(forKey: relayURLKey), !url.isEmpty {
            return url
        }
        // Fall back to keychain (app only)
        return getKeychainString(key: relayURLKey)
    }

    func setRelayURL(_ url: String) {
        setKeychainString(key: relayURLKey, value: url)
        sharedDefaults?.set(url, forKey: relayURLKey)
    }

    // MARK: - Token

    func getToken() -> String? {
        if let token = sharedDefaults?.string(forKey: tokenKey), !token.isEmpty {
            return token
        }
        return getKeychainString(key: tokenKey)
    }

    func setToken(_ token: String) {
        setKeychainString(key: tokenKey, value: token)
        sharedDefaults?.set(token, forKey: tokenKey)
    }

    // MARK: - Clear

    func clearAll() {
        deleteKeychain(key: relayURLKey)
        deleteKeychain(key: tokenKey)
        sharedDefaults?.removeObject(forKey: relayURLKey)
        sharedDefaults?.removeObject(forKey: tokenKey)
    }

    // MARK: - Sync to shared defaults (call on app launch to backfill)

    func syncToSharedDefaults() {
        if let url = getKeychainString(key: relayURLKey), !url.isEmpty {
            sharedDefaults?.set(url, forKey: relayURLKey)
        }
        if let token = getKeychainString(key: tokenKey), !token.isEmpty {
            sharedDefaults?.set(token, forKey: tokenKey)
        }
    }

    // MARK: - Private Keychain Operations

    private func getKeychainString(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func setKeychainString(key: String, value: String) {
        deleteKeychain(key: key)

        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
