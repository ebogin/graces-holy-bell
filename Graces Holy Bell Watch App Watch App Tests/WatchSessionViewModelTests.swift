import XCTest
@testable import Graces_Holy_Bell_Watch_App_Watch_App

/// Unit tests for WatchSessionViewModel covering the optimistic-update fixes
/// committed in claude/fix-watch-slider-state-FRESO.
///
/// All tests run on @MainActor because WatchSessionViewModel is @MainActor-isolated.
@MainActor
final class WatchSessionViewModelTests: XCTestCase {

    var mock: MockWatchConnectivityManager!
    var sut: WatchSessionViewModel!

    override func setUp() async throws {
        mock = MockWatchConnectivityManager()
        sut = WatchSessionViewModel(connectivityManager: mock)
    }

    // MARK: - sendPray() optimistic update

    func testSendPrayOptimisticallyAppendsEntryBeforeConnectivityReply() {
        XCTAssertEqual(sut.sortedEntries.count, 0)
        sut.sendPray()
        // The fix: entry appears immediately, not after WatchConnectivity round-trip.
        XCTAssertEqual(sut.sortedEntries.count, 1)
    }

    func testSendPraySendsActionToConnectivityManager() {
        sut.sendPray()
        XCTAssertEqual(mock.sentActions, ["PRAY"])
    }

    func testSendPrayTimestampIsWithinCurrentSecond() {
        let before = Date()
        sut.sendPray()
        let after = Date()
        let ts = sut.sortedEntries[0].timestamp
        XCTAssertGreaterThanOrEqual(ts, before)
        XCTAssertLessThanOrEqual(ts, after)
    }

    func testSendPrayOptimisticEntryHasCorrectSequenceIndex() {
        sut.sendPray()
        XCTAssertEqual(sut.sortedEntries[0].sequenceIndex, 0)
    }

    func testSendPrayMultipleTimesIncreasesSequenceIndices() {
        sut.sendPray()
        sut.sendPray()
        sut.sendPray()
        XCTAssertEqual(sut.sortedEntries.count, 3)
        XCTAssertEqual(sut.sortedEntries[0].sequenceIndex, 0)
        XCTAssertEqual(sut.sortedEntries[1].sequenceIndex, 1)
        XCTAssertEqual(sut.sortedEntries[2].sequenceIndex, 2)
    }

    // MARK: - sendPray() rapid activation (threshold boundary)

    func testRapidSendPrayFiresDoNotLoseEntries() {
        // Simulates fast slider activations before any apply() arrives.
        for _ in 0..<10 {
            sut.sendPray()
        }
        XCTAssertEqual(sut.sortedEntries.count, 10)
        XCTAssertEqual(mock.sentActions.filter { $0 == "PRAY" }.count, 10)
    }

    func testSendPrayAtExactlyZeroEntriesStartsAtSequenceIndexZero() {
        XCTAssertEqual(sut.sortedEntries.count, 0)
        sut.sendPray()
        XCTAssertEqual(sut.sortedEntries.first?.sequenceIndex, 0)
    }

    // MARK: - sendStop() optimistic freeze

    func testSendStopFreezesSessionStoppedAtImmediately() {
        // The fix: sessionStoppedAt is set before the iPhone replies.
        XCTAssertNil(sut.sessionStoppedAt)
        let before = Date()
        sut.sendStop()
        let after = Date()
        XCTAssertNotNil(sut.sessionStoppedAt)
        let frozenAt = sut.sessionStoppedAt!
        XCTAssertGreaterThanOrEqual(frozenAt, before)
        XCTAssertLessThanOrEqual(frozenAt, after)
    }

    func testSendStopSendsStopActionToConnectivityManager() {
        sut.sendStop()
        XCTAssertEqual(mock.sentActions, ["STOP"])
    }

    func testSendStopHidesLogPanel() {
        sut.showingLog = true
        sut.sendStop()
        XCTAssertFalse(sut.showingLog)
    }

    // MARK: - apply() replaces optimistic entry

    func testApplyOverwritesOptimisticEntryWithConfirmedTimestamp() {
        sut.sendPray()
        XCTAssertEqual(sut.sortedEntries.count, 1)

        let confirmedTS = Date().addingTimeInterval(-0.5) // confirmed slightly in the past
        let confirmedState = makeState(appState: "active", entries: [
            SyncedEntry(timestamp: confirmedTS, sequenceIndex: 0)
        ])
        sut.apply(confirmedState)

        XCTAssertEqual(sut.sortedEntries.count, 1)
        XCTAssertEqual(sut.sortedEntries[0].timestamp, confirmedTS)
    }

    func testApplyAfterMultipleOptimisticPraysUsesIPhoneAsSource() {
        // Watch fired sendPray twice optimistically; iPhone confirmed only one
        // (e.g. dedup happened on iPhone side).
        sut.sendPray()
        sut.sendPray()
        XCTAssertEqual(sut.sortedEntries.count, 2)

        let confirmedState = makeState(appState: "active", entries: [
            SyncedEntry(timestamp: Date().addingTimeInterval(-0.3), sequenceIndex: 0)
        ])
        sut.apply(confirmedState)

        XCTAssertEqual(sut.sortedEntries.count, 1,
            "apply() must replace all optimistic entries with the iPhone's confirmed state")
    }

    func testApplyClearsEntriesWhenConfirmedStateHasNone() {
        sut.sendPray()
        sut.apply(makeState(appState: "active", entries: []))
        XCTAssertEqual(sut.sortedEntries.count, 0)
    }

    func testApplySortsEntriesBySequenceIndex() {
        let t0 = Date().addingTimeInterval(-10)
        let t1 = Date().addingTimeInterval(-5)
        let t2 = Date()
        let state = makeState(appState: "active", entries: [
            SyncedEntry(timestamp: t2, sequenceIndex: 2),
            SyncedEntry(timestamp: t0, sequenceIndex: 0),
            SyncedEntry(timestamp: t1, sequenceIndex: 1),
        ])
        sut.apply(state)
        XCTAssertEqual(sut.sortedEntries.map(\.sequenceIndex), [0, 1, 2])
    }

    // MARK: - Concurrent apply() during in-flight action

    func testApplyDuringInFlightPrayProducesCorrectFinalState() {
        // This is the exact race condition the fix addresses:
        // 1. sendPray() fires optimistic update immediately
        // 2. apply() arrives from iPhone before the reply handler fires
        sut.sendPray()
        XCTAssertEqual(sut.sortedEntries.count, 1, "Optimistic append must happen immediately")

        let confirmedTS = Date().addingTimeInterval(-0.3)
        sut.apply(makeState(appState: "active", entries: [
            SyncedEntry(timestamp: confirmedTS, sequenceIndex: 0)
        ]))

        XCTAssertEqual(sut.sortedEntries.count, 1,
            "No double-counting: apply() replaces the optimistic entry")
        XCTAssertEqual(sut.sortedEntries[0].timestamp, confirmedTS)
        XCTAssertEqual(mock.sentActions.filter { $0 == "PRAY" }.count, 1,
            "Exactly one PRAY was sent to connectivity")
    }

    // MARK: - Elapsed time with optimistic entries

    func testElapsedTimeResetsNearZeroImmediatelyAfterSendPray() {
        sut.sendPray()
        let elapsed = sut.elapsedSinceLastPrayer()
        XCTAssertLessThan(elapsed, 0.05, "Timer should reset to near-zero on sendPray")
    }

    func testElapsedTimeFreezesAfterSendStop() {
        sut.sendPray()
        Thread.sleep(forTimeInterval: 0.05)
        sut.sendStop()
        let frozen = sut.elapsedSinceLastPrayer()
        Thread.sleep(forTimeInterval: 0.05)
        let later = sut.elapsedSinceLastPrayer()
        XCTAssertEqual(frozen, later, accuracy: 0.001,
            "Elapsed must freeze immediately after sendStop")
    }

    func testElapsedTimeIsZeroWithNoEntries() {
        XCTAssertEqual(sut.elapsedSinceLastPrayer(), 0)
    }

    // MARK: - Route logic

    func testRouteIsFirstLaunchOnEmptyInitialState() {
        XCTAssertEqual(sut.route, .firstLaunch)
    }

    func testRouteIsActiveAfterApplyWithActiveState() {
        sut.apply(makeState(appState: "active", entries: []))
        XCTAssertEqual(sut.route, .active)
    }

    func testRouteIsIdleAfterApplyWithIdleStateAndEntries() {
        sut.apply(makeState(
            appState: "idle",
            entries: [SyncedEntry(timestamp: .now, sequenceIndex: 0)],
            sessionStoppedAt: Date(),
            hasExistingLog: true
        ))
        XCTAssertEqual(sut.route, .idle)
    }

    func testRouteBecomesLogWhenShowingLogIsTrue() {
        sut.apply(makeState(appState: "active", entries: []))
        sut.showingLog = true
        XCTAssertEqual(sut.route, .log)
    }

    // MARK: - sendClearLog()

    func testSendClearLogEmptiesEntriesImmediately() {
        sut.sendPray()
        sut.sendClearLog()
        XCTAssertEqual(sut.sortedEntries.count, 0)
    }

    func testSendClearLogResetsSessionStoppedAt() {
        sut.sendStop()
        XCTAssertNotNil(sut.sessionStoppedAt)
        sut.sendClearLog()
        XCTAssertNil(sut.sessionStoppedAt)
    }

    func testSendClearLogCallsConnectivitySendClearLog() {
        sut.sendClearLog()
        XCTAssertEqual(mock.clearLogCallCount, 1)
    }

    // MARK: - Helpers

    private func makeState(
        appState: String,
        entries: [SyncedEntry],
        sessionStoppedAt: Date? = nil,
        hasExistingLog: Bool = false
    ) -> SyncedSessionState {
        SyncedSessionState(
            appState: appState,
            entries: entries,
            sessionStoppedAt: sessionStoppedAt,
            hasExistingLog: hasExistingLog
        )
    }
}
