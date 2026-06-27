import XCTest
@testable import Graces_Holy_Bell

/// Phase 2d — durable analytics-only state.
final class AnalyticsStateStoreTests: XCTestCase {

    func test_userDefaultsStore_roundTrips() throws {
        let suite = "test.analyticsstate.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserDefaultsAnalyticsStateStore(defaults: defaults)
        XCTAssertNil(store.installDate)
        XCTAssertNil(store.closedSessionStart)

        let installed = Date(timeIntervalSince1970: 1_700_000_000)
        let closed = Date(timeIntervalSince1970: 1_700_100_000)
        store.installDate = installed
        store.closedSessionStart = closed

        // Re-read through a fresh instance on the same suite.
        let reopened = UserDefaultsAnalyticsStateStore(defaults: defaults)
        XCTAssertEqual(reopened.installDate, installed)
        XCTAssertEqual(reopened.closedSessionStart, closed)
    }
}

/// In-test fake — hermetic, no UserDefaults.
final class InMemoryAnalyticsStateStore: AnalyticsStateStore {
    var installDate: Date?
    var closedSessionStart: Date?
}
