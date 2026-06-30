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
        // SessionViewModel persists lastClearedAt in UserDefaults.standard (global).
        // Clear it so a clear epoch written by one test can't prune another's prayers.
        UserDefaults.standard.removeObject(forKey: "prayer.lastClearedAt")
        container = try ModelContainer(
            for: PrayerSession.self, PrayerEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "prayer.lastClearedAt")
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

    // MARK: - The analytics invariant: each prayer counted exactly once, at origin.
    // (Group G — the merge path must never emit prayer_logged.)

    func test_mergeIncoming_watchPrayer_isVisibleButEmitsNoAnalytics() {
        let (vm, spy) = makeViewModel()
        vm.startNewSession()                       // session_started + 1 prayer_logged (phone)
        let before = spy.captured.count

        // A Watch-origin prayer arrives via sync. It was already counted once at
        // its origin (the Watch); merging it on the phone must NOT re-emit.
        let watchEvent = PrayerEvent(id: UUID(), timestamp: Date().addingTimeInterval(60), origin: .watch)
        vm.mergeIncoming(snapshot: SyncSnapshot(events: [watchEvent], lastClearedAt: nil, amenAlarmFireAt: nil))

        XCTAssertEqual(vm.sortedEntries.count, 2)        // the Watch prayer is now shown
        XCTAssertEqual(spy.captured.count, before)       // ...but no analytics fired
    }

    func test_mergeIncoming_duplicateEvent_doesNotDoubleCountOrRelog() {
        let (vm, spy) = makeViewModel()
        vm.startNewSession()
        let before = spy.captured.count
        guard let existing = vm.sortedEntries.first else {
            return XCTFail("startNewSession should have logged one prayer")
        }

        // Re-deliver the phone's own event (a snapshot echo from the Watch).
        // Idempotent merge: no new entry, no analytics.
        let echo = PrayerEvent(id: existing.id, timestamp: existing.timestamp, origin: .phone)
        vm.mergeIncoming(snapshot: SyncSnapshot(events: [echo], lastClearedAt: nil, amenAlarmFireAt: nil))

        XCTAssertEqual(vm.sortedEntries.count, 1)
        XCTAssertEqual(spy.captured.count, before)
    }

    func test_mergeIncoming_clearFromWatch_emitsNoAnalytics() {
        let (vm, spy) = makeViewModel()
        vm.startNewSession()
        let before = spy.captured.count

        // A clear performed on the Watch arrives via sync. session_ended was
        // already emitted at the origin; the merge must not emit it again.
        vm.mergeIncoming(snapshot: SyncSnapshot(events: [], lastClearedAt: Date().addingTimeInterval(60), amenAlarmFireAt: nil))

        XCTAssertEqual(vm.appState, .idle)               // the clear took effect
        XCTAssertEqual(spy.captured.count, before)       // ...silently
    }
}
