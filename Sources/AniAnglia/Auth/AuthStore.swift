import Foundation
import Combine
import Security

struct AuthSession {
    let token: String
    let profileId: Int64
    let profile: Profile?
}

protocol KeychainStorage: AnyObject {
    func string(for account: String) throws -> String?
    func set(_ value: String, for account: String) throws
    func delete(_ account: String) throws
}

enum KeychainStorageError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)"
        case .invalidData:
            return "Keychain item data is not valid UTF-8"
        }
    }
}

final class SystemKeychainStorage: KeychainStorage {
    private let service: String

    init(service: String = "io.github.deerbyy.AniAngliaMacOS.auth.v2") {
        self.service = service
    }

    func string(for account: String) throws -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainStorageError.invalidData
            }
            return value
        case errSecItemNotFound, errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
            return nil
        default:
            throw KeychainStorageError.unexpectedStatus(status)
        }
    }

    func set(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(for: account)
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery(for: account)
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStorageError.unexpectedStatus(addStatus)
            }
        case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
            throw KeychainStorageError.unexpectedStatus(updateStatus)
        default:
            throw KeychainStorageError.unexpectedStatus(updateStatus)
        }
    }

    func delete(_ account: String) throws {
        var query = baseQuery(for: account)
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStorageError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
    }
}

final class LegacyAniAngliaKeychainStorage: KeychainStorage {
    private let service = "AniAnglia"

    func string(for account: String) throws -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainStorageError.invalidData
            }
            return value
        case errSecItemNotFound, errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
            return nil
        default:
            throw KeychainStorageError.unexpectedStatus(status)
        }
    }

    func set(_ value: String, for account: String) throws {
        throw KeychainStorageError.unexpectedStatus(errSecUnimplemented)
    }

    func delete(_ account: String) throws {
        throw KeychainStorageError.unexpectedStatus(errSecUnimplemented)
    }

    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
    }
}

@MainActor
final class AuthStore: ObservableObject {
    private static let tokenKey = "profile_token"
    private static let profileIdKey = "profile_id"
    private static let legacyTokenKey = "com.deerbyy.AniAnglia.token"
    private static let legacyProfileIdKey = "com.deerbyy.AniAnglia.profileId"
    private let keychain: KeychainStorage
    private let legacyKeychain: KeychainStorage?

    @Published private(set) var token: String?
    @Published private(set) var profileId: Int64?

    init() {
        self.keychain = SystemKeychainStorage()
        self.legacyKeychain = LegacyAniAngliaKeychainStorage()
        loadSession()
    }

    init(keychain: KeychainStorage) {
        self.keychain = keychain
        self.legacyKeychain = nil
        loadSession()
    }

    var isAuthenticated: Bool { token != nil && profileId != nil }

    var currentSession: AuthSession? {
        guard let token, let profileId else { return nil }
        return AuthSession(token: token, profileId: profileId, profile: nil)
    }

    func save(session: AuthSession) {
        setCredentials(token: session.token, profileId: session.profileId)
    }

    func setCredentials(token: String, profileId: Int64) {
        self.token = token
        self.profileId = profileId
        try? keychain.set(token, for: Self.tokenKey)
        try? keychain.set(String(profileId), for: Self.profileIdKey)
    }

    func signOut() {
        self.token = nil
        self.profileId = nil
        try? keychain.delete(Self.tokenKey)
        try? keychain.delete(Self.profileIdKey)
    }

    private func loadSession() {
        if loadCurrentSession() {
            return
        }
        if migrateLegacySession() {
            return
        }
        token = nil
        profileId = nil
    }

    private func loadCurrentSession() -> Bool {
        let storedToken = (try? keychain.string(for: Self.tokenKey)) ?? nil
        let rawProfileId = (try? keychain.string(for: Self.profileIdKey)) ?? nil
        guard let storedToken,
              let rawProfileId,
              let storedProfileId = Int64(rawProfileId) else {
            return false
        }
        token = storedToken
        profileId = storedProfileId
        return true
    }

    private func migrateLegacySession() -> Bool {
        guard let legacyKeychain else { return false }
        let storedToken = (try? legacyKeychain.string(for: Self.legacyTokenKey)) ?? nil
        let rawProfileId = (try? legacyKeychain.string(for: Self.legacyProfileIdKey)) ?? nil
        guard let storedToken,
              let rawProfileId,
              let storedProfileId = Int64(rawProfileId) else {
            return false
        }
        token = storedToken
        profileId = storedProfileId
        try? keychain.set(storedToken, for: Self.tokenKey)
        try? keychain.set(String(storedProfileId), for: Self.profileIdKey)
        return true
    }
}
