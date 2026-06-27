import XCTest
import SwiftData
@testable import Graces_Holy_Bell

/// Phase 2d — the additive hooks fire through the real SessionViewModel, and the
/// app's behavior is unchanged when no analytics sink is attached.
@MainActor
final class AnalyticsViewModelIntegrationTests: XCTestCase {

    // Held as a stored property so the in-memory store stays alive for the whole
    // test — a local would be deallocated mid-action and tear SwiftData down.
    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: PrayerSession.self, PrayerEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() {
        container = nil
    }

    private func makeViewModel() -> (SessionViewModel, SpyAnalytics) {
        let vm = SessionViewModel(modelContext: container.mainContext)
        let spy = SpyAnalytics()
        vm.analytics = AnalyticsService(transport: spy, stateStore: InMemoryAnalyticsStateStore()) {
            EventContext(deviceSource: .phone, alarmStatus: .off, alarmDurationSeconds: 5400,
                         environment: StubAppEnvironment(appVersion: "1.0.0", osVersion: "26.4.0"))
        }
        return (vm, spy)
    }

    func test_fullSessionLifecycle_emitsExpectedSequence() {
        let (vm, spy) = makeViewModel()

        vm.startNewSession()  // session_started + opening prayer_logged
        vm.logPrayer()        // prayer_logged (index 2)
        vm.clearLog()         // session_ended

        XCTAssertEqual(
            spy.captured.map(\.name),
            ["session_started", "prayer_logged", "prayer_logged", "session_ended"]
        )
        XCTAssertEqual(spy.captured[2].properties["prayer_index_in_session"], .int(2))
        XCTAssertEqual(spy.captured[3].properties["prayers_in_session"], .int(2))
    }

    func test_replacingSession_closesOldBeforeStartingNew() {
        let (vm, spy) = makeViewModel()

        vm.startNewSession() // first session begins
        vm.startNewSession() // replace: old must close, then new starts

        XCTAssertEqual(
            spy.captured.map(\.name),
            ["session_started", "prayer_logged", "session_ended", "session_started", "prayer_logged"]
        )
    }

    func test_noAnalyticsSink_appBehavesNormally() {
        let vm = SessionViewModel(modelContext: container.mainContext) // analytics nil
        vm.startNewSession()
        vm.logPrayer()
        XCTAssertEqual(vm.appState, .active)
        XCTAssertEqual(vm.sortedEntries.count, 2)
    }
}
