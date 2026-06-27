import XCTest
@testable import Graces_Holy_Bell

/// Phase 3a — consent persistence.
final class ConsentStoreTests: XCTestCase {

    func test_userDefaultsStore_roundTrips() throws {
        let suite = "test.consent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserDefaultsConsentStore(defaults: defaults)
        XCTAssertNil(store.consentState, "unset until chosen")

        store.consentState = .denied
        XCTAssertEqual(UserDefaultsConsentStore(defaults: defaults).consentState, .denied)
    }
}
