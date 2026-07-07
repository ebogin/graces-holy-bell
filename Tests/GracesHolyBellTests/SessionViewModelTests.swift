import XCTest
import SwiftData
@testable import Graces_Holy_Bell

@MainActor
final class SessionViewModelTests: XCTestCase {

    var container: ModelContainer!
    var viewModel: SessionViewModel!

    override func setUp() async throws {
        container = try ModelContainer(
            for: PrayerSession.self, PrayerEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        viewModel = SessionViewModel(modelContext: container.mainContext)
        // Tests log prayers back-to-back; the double-slide debounce would drop them.
        viewModel.prayerDebounceInterval = 0
    }

    override func tearDown() {
        // Clear persisted epoch so tests don't bleed into each other.
        UserDefaults.standard.removeObject(forKey: "prayer.lastClearedAt")
        viewModel = nil
        container = nil
    }

    // MARK: - Initial State

    func test_initialState_isIdle() {
        XCTAssertEqual(viewModel.appState, .idle)
        XCTAssertTrue(viewModel.sortedEntries.isEmpty)
        XCTAssertNil(viewModel.lastPrayerTimestamp)
        XCTAssertNil(viewModel.sessionStartedAt)
    }

    func test_elapsedSinceLastPrayer_returnsZero_whenNoSession() {
        XCTAssertEqual(viewModel.elapsedSinceLastPrayer(), 0)
    }

    // MARK: - startNewSession / logPrayer

    func test_startNewSession_transitionsToActive() {
        viewModel.startNewSession()
        XCTAssertEqual(viewModel.appState, .active)
    }

    func test_startNewSession_createsOneEntry() {
        viewModel.startNewSession()
        XCTAssertEqual(viewModel.sortedEntries.count, 1)
    }

    func test_startNewSession_setsLastPrayerTimestamp() {
        let before = Date.now
        viewModel.startNewSession()
        XCTAssertNotNil(viewModel.lastPrayerTimestamp)
        XCTAssertGreaterThanOrEqual(viewModel.lastPrayerTimestamp!, before)
    }

    func test_startNewSession_whenActive_startsOver() {
        viewModel.startNewSession()  // first session
        viewModel.logPrayer()        // two entries
        viewModel.startNewSession()  // replaces with a single-entry new session
        XCTAssertEqual(viewModel.sortedEntries.count, 1)
        XCTAssertEqual(viewModel.appState, .active)
    }

    func test_logPrayer_addsEntry() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        XCTAssertEqual(viewModel.sortedEntries.count, 2)
    }

    func test_logPrayer_entriesSortedAscending() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        viewModel.logPrayer()
        let timestamps = viewModel.sortedEntries.map(\.timestamp)
        XCTAssertEqual(timestamps, timestamps.sorted())
    }

    func test_logPrayer_setsOriginToPhone() {
        viewModel.logPrayer()
        XCTAssertEqual(viewModel.sortedEntries.first?.origin, PrayerEvent.Origin.phone.rawValue)
    }

    func test_logPrayer_withinDebounceInterval_isDropped() {
        viewModel.prayerDebounceInterval = 1.0
        viewModel.startNewSession()
        viewModel.logPrayer()  // immediate second fire — accidental double-slide
        XCTAssertEqual(viewModel.sortedEntries.count, 1)
        XCTAssertEqual(viewModel.appState, .active)
    }

    func test_logPrayer_assignsStableUUID() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        let ids = viewModel.sortedEntries.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)  // all unique
    }

    // MARK: - clearLog

    func test_clearLog_resetsToIdle() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        viewModel.clearLog()
        XCTAssertTrue(viewModel.sortedEntries.isEmpty)
        XCTAssertEqual(viewModel.appState, .idle)
    }

    func test_clearLog_safeWhenNoSession() {
        viewModel.clearLog()
        XCTAssertEqual(viewModel.appState, .idle)
    }

    func test_clearLog_setsLastClearedAt() {
        viewModel.startNewSession()
        XCTAssertNil(viewModel.lastClearedAt)
        viewModel.clearLog()
        XCTAssertNotNil(viewModel.lastClearedAt)
    }

    func test_prayerAfterClear_formsFreshSession() {
        viewModel.startNewSession()
        viewModel.clearLog()
        viewModel.startNewSession()
        XCTAssertEqual(viewModel.sortedEntries.count, 1)
        XCTAssertEqual(viewModel.appState, .active)
    }

    // MARK: - elapsedSinceLastPrayer

    func test_elapsedSinceLastPrayer_liveWhenActive() {
        viewModel.startNewSession()
        let future = Date.now.addingTimeInterval(120)
        let elapsed = viewModel.elapsedSinceLastPrayer(at: future)
        XCTAssertGreaterThan(elapsed, 119)
        XCTAssertLessThan(elapsed, 130)
    }

    // MARK: - duration(for:at:)

    func test_duration_outOfBounds_returnsNil() {
        viewModel.startNewSession()
        XCTAssertNil(viewModel.duration(for: -1))
        XCTAssertNil(viewModel.duration(for: 1))
    }

    func test_duration_lastEntryActive_isLive() {
        viewModel.startNewSession()
        let future = Date.now.addingTimeInterval(90)
        let dur = viewModel.duration(for: 0, at: future)!
        XCTAssertGreaterThan(dur, 89)
        XCTAssertLessThan(dur, 100)
    }

    func test_duration_nonLastEntry_isGapToNextEntry() {
        let ctx = container.mainContext
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 1060)
        let e0 = PrayerEntry(id: UUID(), timestamp: t0, origin: "phone")
        let e1 = PrayerEntry(id: UUID(), timestamp: t1, origin: "phone")
        ctx.insert(e0)
        ctx.insert(e1)
        try? ctx.save()

        let vm = SessionViewModel(modelContext: ctx)
        let dur = vm.duration(for: 0, at: .now)!
        XCTAssertEqual(dur, 60, accuracy: 0.001)
    }

    // MARK: - sessionStartedAt

    func test_sessionStartedAt_isFirstEntryTimestamp() {
        let before = Date.now
        viewModel.startNewSession()
        let started = viewModel.sessionStartedAt
        XCTAssertNotNil(started)
        XCTAssertGreaterThanOrEqual(started!, before)
        XCTAssertEqual(started, viewModel.sortedEntries.first?.timestamp)
    }

    // MARK: - onStateChanged callback

    func test_onStateChanged_calledOnStartNewSession() {
        var callCount = 0
        viewModel.onStateChanged = { callCount += 1 }
        viewModel.startNewSession()
        XCTAssertEqual(callCount, 1)
    }

    func test_onStateChanged_calledOnLogPrayer() {
        viewModel.startNewSession()
        var callCount = 0
        viewModel.onStateChanged = { callCount += 1 }
        viewModel.logPrayer()
        XCTAssertEqual(callCount, 1)
    }

    func test_onStateChanged_calledOnClearLog() {
        viewModel.startNewSession()
        var callCount = 0
        viewModel.onStateChanged = { callCount += 1 }
        viewModel.clearLog()
        XCTAssertEqual(callCount, 1)
    }
}
