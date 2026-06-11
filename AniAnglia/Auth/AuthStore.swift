import Foundation
import Security

protocol KeychainStorage {
    func string(for account: String) throws -> String?
    func set(_ value: String, for account: String) throws
    func delete(_ account: String) throws
}

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            "Keychain вернул статус \(status)"
        }
    }
}

final class KeychainClient: KeychainStorage {
    private let service: String

    init(service: String = "io.github.deerbyy.AniAngliaMacOS") {
        self.service = service
    }

    func string(for account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class AuthStore: ObservableObject {
    @Published private(set) var currentSession: AuthSession?
    @Published var authError: String?

    var isAuthenticated: Bool {
        currentSession != nil
    }

    private let keychain: KeychainStorage
    private let tokenAccount = "profile_token"
    private let profileIdAccount = "profile_id"

    init(keychain: KeychainStorage = KeychainClient()) {
        self.keychain = keychain
        load()
    }

    func save(session: AuthSession) {
        do {
            try keychain.set(session.token, for: tokenAccount)
            try keychain.set("\(session.profileId)", for: profileIdAccount)
            currentSession = session
            authError = nil
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try keychain.delete(tokenAccount)
            try keychain.delete(profileIdAccount)
        } catch {
            authError = error.localizedDescription
        }
        currentSession = nil
    }

    private func load() {
        do {
            guard let token = try keychain.string(for: tokenAccount),
                  let profileIdString = try keychain.string(for: profileIdAccount),
                  let profileId = Int(profileIdString) else {
                currentSession = nil
                return
            }
            currentSession = AuthSession(token: token, profileId: profileId, profile: nil)
        } catch {
            authError = error.localizedDescription
            currentSession = nil
        }
    }
}
