import Foundation
import Combine
import Security

@MainActor
final class AuthStore: ObservableObject {
    private let tokenKey = "com.deerbyy.AniAnglia.token"
    private let profileIdKey = "com.deerbyy.AniAnglia.profileId"

    @Published private(set) var token: String?
    @Published private(set) var profileId: Int64?

    init() {
        self.token = Self.keychainString(forKey: tokenKey)
        if let raw = Self.keychainString(forKey: profileIdKey), let pid = Int64(raw) {
            self.profileId = pid
        }
    }

    var isAuthenticated: Bool { token != nil && profileId != nil }

    func setCredentials(token: String, profileId: Int64) {
        self.token = token
        self.profileId = profileId
        Self.keychainSet(token, forKey: tokenKey)
        Self.keychainSet(String(profileId), forKey: profileIdKey)
    }

    func signOut() {
        self.token = nil
        self.profileId = nil
        Self.keychainDelete(forKey: tokenKey)
        Self.keychainDelete(forKey: profileIdKey)
    }

    // MARK: - Keychain helpers
    private static func keychainQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "AniAnglia",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    private static func keychainSet(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        var query = keychainQuery(forKey: key)
        // Delete any existing item first to avoid duplicate error
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecUseDataProtectionKeychain as String] = true
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Fallback without data protection flag for older macOS
            query.removeValue(forKey: kSecUseDataProtectionKeychain as String)
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private static func keychainString(forKey key: String) -> String? {
        var query = keychainQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseDataProtectionKeychain as String] = true
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess {
            query.removeValue(forKey: kSecUseDataProtectionKeychain as String)
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainDelete(forKey key: String) {
        var query = keychainQuery(forKey: key)
        query[kSecUseDataProtectionKeychain as String] = true
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess {
            query.removeValue(forKey: kSecUseDataProtectionKeychain as String)
            SecItemDelete(query as CFDictionary)
        }
    }
}
