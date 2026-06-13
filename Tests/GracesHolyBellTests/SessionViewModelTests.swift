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
    }

    override func tearDown() async throws {
        viewModel = nil
        container = nil
    }

    // MARK: - Initial State

    func test_initialState_isIdle() {
        XCTAssertEqual(viewModel.appState, .idle)
        XCTAssertNil(viewModel.currentSession)
        XCTAssertTrue(viewModel.sortedEntries.isEmpty)
        XCTAssertNil(viewModel.lastPrayerTimestamp)
    }

    func test_elapsedSinceLastPrayer_returnsZero_whenNoSession() {
        XCTAssertEqual(viewModel.elapsedSinceLastPrayer(), 0)
    }

    // MARK: - startNewSession

    func test_startNewSession_transitionsToActive() {
        viewModel.startNewSession()
        XCTAssertEqual(viewModel.appState, .active)
    }

    func test_startNewSession_createsOneEntry() {
        viewModel.startNewSession()
        XCTAssertEqual(viewModel.sortedEntries.count, 1)
        XCTAssertEqual(viewModel.sortedEntries.first?.sequenceIndex, 0)
    }

    func test_startNewSession_setsLastPrayerTimestamp() {
        let before = Date.now
        viewModel.startNewSession()
        XCTAssertNotNil(viewModel.lastPrayerTimestamp)
        XCTAssertGreaterThanOrEqual(viewModel.lastPrayerTimestamp!, before)
    }

    func test_startNewSession_replacesExistingSession() {
        viewModel.startNewSession()
        let firstSessionId = viewModel.currentSession?.persistentModelID
        viewModel.startNewSession()
        XCTAssertNotEqual(viewModel.currentSession?.persistentModelID, firstSessionId)
    }

    // MARK: - logPrayer

    func test_logPrayer_addsEntry() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        XCTAssertEqual(viewModel.sortedEntries.count, 2)
    }

    func test_logPrayer_incrementsSequenceIndex() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        viewModel.logPrayer()
        let indices = viewModel.sortedEntries.map { $0.sequenceIndex }
        XCTAssertEqual(indices, [0, 1, 2])
    }

    func test_logPrayer_doesNothing_whenNoSession() {
        viewModel.logPrayer()
        XCTAssertTrue(viewModel.sortedEntries.isEmpty)
    }

    // MARK: - clearLog

    func test_clearLog_resetsToEmpty() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        viewModel.clearLog()
        XCTAssertNil(viewModel.currentSession)
        XCTAssertTrue(viewModel.sortedEntries.isEmpty)
        XCTAssertEqual(viewModel.appState, .idle)
    }

    func test_clearLog_safeWhenNoSession() {
        viewModel.clearLog()
        XCTAssertNil(viewModel.currentSession)
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
        // Insert session with known timestamps directly into model context
        let ctx = container.mainContext
        let session = PrayerSession(startedAt: Date(timeIntervalSince1970: 1000))
        let e0 = PrayerEntry(timestamp: Date(timeIntervalSince1970: 1000), sequenceIndex: 0)
        let e1 = PrayerEntry(timestamp: Date(timeIntervalSince1970: 1060), sequenceIndex: 1)
        e0.session = session
        e1.session = session
        session.entries = [e0, e1]
        ctx.insert(session)
        try? ctx.save()

        // Fresh VM loads from context
        let vm = SessionViewModel(modelContext: ctx)
        let dur = vm.duration(for: 0, at: .now)!
        XCTAssertEqual(dur, 60, accuracy: 0.001)
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
