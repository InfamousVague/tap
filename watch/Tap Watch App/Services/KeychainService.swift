import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let relayURLKey = "com.mattssoftware.tap.relay-url"
    private let tokenKey = "com.mattssoftware.tap.token"

    private init() {}

    // MARK: - Relay URL

    func getRelayURL() -> String? {
        return getString(key: relayURLKey)
    }

    func setRelayURL(_ url: String) {
        setString(key: relayURLKey, value: url)
    }

    // MARK: - Token

    func getToken() -> String? {
        return getString(key: tokenKey)
    }

    func setToken(_ token: String) {
        setString(key: tokenKey, value: token)
    }

    // MARK: - Clear

    func clearAll() {
        delete(key: relayURLKey)
        delete(key: tokenKey)
    }

    // MARK: - Private Keychain Operations

    private func getString(key: String) -> String? {
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

    private func setString(key: String, value: String) {
        // Delete existing
        delete(key: key)

        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
