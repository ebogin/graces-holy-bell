import XCTest
@testable import Graces_Holy_Bell

/// Phase 1b — iPhone-side install_id minting & persistence.
///
/// The iPhone is the canonical generator. `resolve()` mints once, persists to
/// the store, and is stable forever after (until delete-and-reinstall clears
/// UserDefaults — "new install = new user").
final class InstallIDProviderTests: XCTestCase {

    func test_emptyStore_mintsUUIDShapedIDAndPersists() throws {
        let store = InMemoryInstallIDStore()
        let provider = InstallIDProvider(store: store)

        let id = provider.resolve()

        XCTAssertFalse(id.isEmpty)
        XCTAssertNotNil(UUID(uuidString: id), "minted id should be UUID-shaped, was \(id)")
        XCTAssertEqual(store.load(), id, "minted id must be persisted")
    }

    func test_resolveIsStableAcrossCalls() {
        let provider = InstallIDProvider(store: InMemoryInstallIDStore())
        XCTAssertEqual(provider.resolve(), provider.resolve())
    }

    func test_existingStoredID_isReturnedNotRegenerated() {
        let store = InMemoryInstallIDStore()
        store.save("preexisting-id")
        let provider = InstallIDProvider(store: store)
        XCTAssertEqual(provider.resolve(), "preexisting-id")
    }

    func test_freshStores_yieldDifferentIDs() {
        let a = InstallIDProvider(store: InMemoryInstallIDStore()).resolve()
        let b = InstallIDProvider(store: InMemoryInstallIDStore()).resolve()
        XCTAssertNotEqual(a, b, "independent installs must get distinct ids")
    }

    // MARK: - UserDefaults-backed store round-trip

    func test_userDefaultsStore_roundTripsThroughInjectedSuite() throws {
        let suiteName = "test.install_id.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsInstallIDStore(defaults: defaults)
        XCTAssertNil(store.load(), "missing key returns nil")

        store.save("abc-123")
        XCTAssertEqual(store.load(), "abc-123")
    }
}

/// In-memory store fake for hermetic provider tests.
final class InMemoryInstallIDStore: InstallIDStore {
    private var value: String?
    func load() -> String? { value }
    func save(_ id: String) { value = id }
}
