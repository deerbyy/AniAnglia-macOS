import Foundation
@testable import AniAngliaMacOS
import XCTest

final class AuthStoreTests: XCTestCase {
    func testPersistsAndLoadsSession() throws {
        let keychain = InMemoryKeychain()
        let store = AuthStore(keychain: keychain)

        store.save(session: AuthSession(token: "saved-token", profileId: 99, profile: nil))

        let reloaded = AuthStore(keychain: keychain)
        XCTAssertEqual(reloaded.currentSession?.token, "saved-token")
        XCTAssertEqual(reloaded.currentSession?.profileId, 99)
    }

    func testSignOutClearsSession() {
        let keychain = InMemoryKeychain()
        let store = AuthStore(keychain: keychain)
        store.save(session: AuthSession(token: "token", profileId: 1, profile: nil))

        store.signOut()

        XCTAssertNil(store.currentSession)
        XCTAssertNil(try? keychain.string(for: "profile_token"))
    }
}

final class InMemoryKeychain: KeychainStorage {
    private var values: [String: String] = [:]

    func string(for account: String) throws -> String? {
        values[account]
    }

    func set(_ value: String, for account: String) throws {
        values[account] = value
    }

    func delete(_ account: String) throws {
        values.removeValue(forKey: account)
    }
}
