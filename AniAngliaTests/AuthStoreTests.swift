import Foundation
@testable import AniAngliaMacOS
import XCTest

final class AuthStoreTests: XCTestCase {
    func testPersistsAndLoadsSession() throws {
        let storage = InMemorySessionStorage()
        let store = AuthStore(storage: storage)

        store.save(session: AuthSession(token: "saved-token", profileId: 99, profile: nil))

        let reloaded = AuthStore(storage: storage)
        XCTAssertEqual(reloaded.currentSession?.token, "saved-token")
        XCTAssertEqual(reloaded.currentSession?.profileId, 99)
    }

    func testSignOutClearsSession() {
        let storage = InMemorySessionStorage()
        let store = AuthStore(storage: storage)
        store.save(session: AuthSession(token: "token", profileId: 1, profile: nil))

        store.signOut()

        XCTAssertNil(store.currentSession)
        XCTAssertNil(storage.string(for: "profile_token"))
    }
}

final class InMemorySessionStorage: SessionStorage {
    private var values: [String: String] = [:]

    func string(for key: String) -> String? {
        values[key]
    }

    func set(_ value: String, for key: String) {
        values[key] = value
    }

    func delete(_ key: String) {
        values.removeValue(forKey: key)
    }
}
