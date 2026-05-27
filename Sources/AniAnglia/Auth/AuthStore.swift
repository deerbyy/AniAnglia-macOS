import Foundation
import Combine

struct AuthSession {
    let token: String
    let profileId: Int64
    let profile: Profile?
}

protocol SessionStorage: AnyObject {
    func string(for key: String) -> String?
    func set(_ value: String, for key: String)
    func delete(_ key: String)
}

/// Persists the API session without invoking Keychain access dialogs.
///
/// CI artifacts are ad-hoc signed, so replacing the app changes its Keychain
/// identity and causes macOS to prompt on every access to a previous session.
final class PreferencesSessionStorage: SessionStorage {
    private let defaults: UserDefaults
    private let prefix: String

    init(defaults: UserDefaults = .standard, prefix: String = "auth.session.") {
        self.defaults = defaults
        self.prefix = prefix
    }

    func string(for key: String) -> String? {
        defaults.string(forKey: prefix + key)
    }

    func set(_ value: String, for key: String) {
        defaults.set(value, forKey: prefix + key)
    }

    func delete(_ key: String) {
        defaults.removeObject(forKey: prefix + key)
    }
}

@MainActor
final class AuthStore: ObservableObject {
    private static let tokenKey = "profile_token"
    private static let profileIdKey = "profile_id"
    private let storage: SessionStorage

    @Published private(set) var token: String?
    @Published private(set) var profileId: Int64?

    init() {
        self.storage = PreferencesSessionStorage()
        loadSession()
    }

    init(storage: SessionStorage) {
        self.storage = storage
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
        storage.set(token, for: Self.tokenKey)
        storage.set(String(profileId), for: Self.profileIdKey)
    }

    func signOut() {
        self.token = nil
        self.profileId = nil
        storage.delete(Self.tokenKey)
        storage.delete(Self.profileIdKey)
    }

    private func loadSession() {
        guard let storedToken = storage.string(for: Self.tokenKey),
              let rawProfileId = storage.string(for: Self.profileIdKey),
              let storedProfileId = Int64(rawProfileId) else {
            token = nil
            profileId = nil
            return
        }
        token = storedToken
        profileId = storedProfileId
    }
}
