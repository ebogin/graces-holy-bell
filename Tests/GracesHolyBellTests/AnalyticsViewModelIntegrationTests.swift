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
        // Tests log prayers back-to-back; the double-slide debounce would drop them.
        vm.prayerDebounceInterval = 0
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
    // The Watch has no transport of its own, so a watch-origin event is counted
    // when it FIRST reaches the phone, tagged device_source=watch. Echoes of
    // events the phone already knows must never re-emit.

    func test_mergeIncoming_newWatchPrayer_countedOnce_taggedWatch() {
        let (vm, spy) = makeViewModel()
        vm.startNewSession()                       // session_started + 1 prayer_logged (phone)
        let before = spy.captured.count

        // A new Watch-origin prayer arrives via sync — its one and only count.
        let timestamp = Date().addingTimeInterval(60)
        let watchEvent = PrayerEvent(id: UUID(), timestamp: timestamp, origin: .watch)
        vm.mergeIncoming(snapshot: SyncSnapshot(events: [watchEvent], lastClearedAt: nil, amenAlarmFireAt: nil))

        XCTAssertEqual(vm.sortedEntries.count, 2)
        XCTAssertEqual(spy.captured.count, before + 1)
        let event = spy.captured.last
        XCTAssertEqual(event?.name, "prayer_logged")
        XCTAssertEqual(event?.deviceSource, .watch)
        XCTAssertEqual(event?.properties["prayer_index_in_session"], .int(2))
        XCTAssertEqual(event?.captureTimestamp, timestamp, "true prayer time, not merge time")

        // The same event echoed again (e.g. via a second sync channel) must
        // not re-emit — it is no longer new to the phone.
        vm.mergeIncoming(snapshot: SyncSnapshot(events: [watchEvent], lastClearedAt: nil, amenAlarmFireAt: nil))
        XCTAssertEqual(spy.captured.count, before + 1)
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

    func test_mergeIncoming_clearFromWatch_closesTheSession_taggedWatch() {
        let (vm, spy) = makeViewModel()
        vm.startNewSession()
        let before = spy.captured.count

        // A clear performed on the Watch arrives via sync. The Watch never
        // emits, so the phone closes the session here — tagged watch.
        vm.mergeIncoming(snapshot: SyncSnapshot(events: [], lastClearedAt: Date().addingTimeInterval(60), amenAlarmFireAt: nil))

        XCTAssertEqual(vm.appState, .idle)
        XCTAssertEqual(spy.captured.count, before + 1)
        XCTAssertEqual(spy.captured.last?.name, "session_ended")
        XCTAssertEqual(spy.captured.last?.deviceSource, .watch)
        XCTAssertEqual(spy.captured.last?.properties["prayers_in_session"], .int(1))

        // The same clear replayed on another channel must not double-close.
        let clearedAt = vm.lastClearedAt
        vm.mergeIncoming(snapshot: SyncSnapshot(events: [], lastClearedAt: clearedAt, amenAlarmFireAt: nil))
        XCTAssertEqual(spy.captured.count, before + 1)
    }

    func test_mergeIncoming_watchOnlyOfflineSession_emitsFullLifecycle() {
        let (vm, spy) = makeViewModel()

        // The Watch ran a whole session offline — two prayers, then a clear —
        // and it all arrives in one snapshot. The phone owes the entire
        // lifecycle, backdated to the true times, tagged watch.
        let t0 = Date().addingTimeInterval(-1800)
        let t1 = t0.addingTimeInterval(600)
        let clearedAt = t1.addingTimeInterval(300)
        vm.mergeIncoming(snapshot: SyncSnapshot(
            events: [
                PrayerEvent(id: UUID(), timestamp: t0, origin: .watch),
                PrayerEvent(id: UUID(), timestamp: t1, origin: .watch)
            ],
            lastClearedAt: clearedAt,
            amenAlarmFireAt: nil
        ))

        XCTAssertEqual(vm.appState, .idle)
        XCTAssertEqual(
            spy.captured.map(\.name),
            ["session_started", "prayer_logged", "prayer_logged", "session_ended"]
        )
        XCTAssertTrue(spy.captured.allSatisfy { $0.deviceSource == .watch })
        XCTAssertEqual(spy.captured[0].captureTimestamp, t0)
        XCTAssertEqual(spy.captured[2].captureTimestamp, t1)
        XCTAssertEqual(spy.captured[2].properties["prayer_index_in_session"], .int(2))
        XCTAssertEqual(spy.captured[3].properties["prayers_in_session"], .int(2))
    }

    func test_mergeIncoming_watchPrayerStartsSession_whenPhoneIdle() {
        let (vm, spy) = makeViewModel()

        // Phone is idle; a single Watch prayer arrives (session still running).
        let timestamp = Date().addingTimeInterval(-60)
        vm.mergeIncoming(snapshot: SyncSnapshot(
            events: [PrayerEvent(id: UUID(), timestamp: timestamp, origin: .watch)],
            lastClearedAt: nil,
            amenAlarmFireAt: nil
        ))

        XCTAssertEqual(vm.appState, .active)
        XCTAssertEqual(spy.captured.map(\.name), ["session_started", "prayer_logged"])
        XCTAssertTrue(spy.captured.allSatisfy { $0.deviceSource == .watch })
        XCTAssertEqual(spy.captured[0].captureTimestamp, timestamp)
    }
}
