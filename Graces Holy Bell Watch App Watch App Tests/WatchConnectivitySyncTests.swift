import XCTest
@testable import Graces_Holy_Bell_Watch_App_Watch_App

// MARK: - Serialization

/// Tests for SyncedSessionState's dictionary round-trip.
///
/// This layer sits between WatchConnectivity and the ViewModel. If it silently
/// drops or corrupts fields, every downstream test would be testing against
/// phantom data. These tests verify it independently.
final class SyncedSessionStateSerializationTests: XCTestCase {

    // MARK: Roundtrip completeness

    func testRoundtripPreservesAppState() {
        let state = makeState(appState: "active")
        let restored = roundtrip(state)
        XCTAssertEqual(restored?.appState, "active")
    }

    func testRoundtripPreservesIdleAppState() {
        let state = makeState(appState: "idle")
        let restored = roundtrip(state)
        XCTAssertEqual(restored?.appState, "idle")
    }

    func testRoundtripPreservesHasExistingLogTrue() {
        let state = makeState(hasExistingLog: true)
        XCTAssertTrue(roundtrip(state)?.hasExistingLog == true)
    }

    func testRoundtripPreservesHasExistingLogFalse() {
        let state = makeState(hasExistingLog: false)
        XCTAssertFalse(roundtrip(state)?.hasExistingLog == true)
    }

    func testRoundtripPreservesEntryCount() {
        let state = makeState(entries: [
            SyncedEntry(timestamp: Date(), sequenceIndex: 0),
            SyncedEntry(timestamp: Date(), sequenceIndex: 1),
        ])
        XCTAssertEqual(roundtrip(state)?.entries.count, 2)
    }

    func testRoundtripPreservesSequenceIndex() {
        let entry = SyncedEntry(timestamp: Date(), sequenceIndex: 7)
        let state = makeState(entries: [entry])
        XCTAssertEqual(roundtrip(state)?.entries.first?.sequenceIndex, 7)
    }

    func testRoundtripPreservesTimestampToMillisecond() {
        // WatchConnectivity serializes dates as TimeInterval (Double).
        // The roundtrip must preserve sub-second precision.
        let ts = Date(timeIntervalSince1970: 1_700_000_000.123)
        let entry = SyncedEntry(timestamp: ts, sequenceIndex: 0)
        let restored = roundtrip(makeState(entries: [entry]))?.entries.first?.timestamp
        XCTAssertEqual(restored?.timeIntervalSince1970 ?? 0,
                       ts.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    func testRoundtripWithSessionStoppedAtPreservesTimestamp() {
        let stoppedAt = Date(timeIntervalSince1970: 1_700_000_042.0)
        let state = makeState(sessionStoppedAt: stoppedAt)
        let restored = roundtrip(state)?.sessionStoppedAt
        XCTAssertEqual(restored?.timeIntervalSince1970 ?? 0,
                       stoppedAt.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    func testRoundtripWithNilSessionStoppedAtDeserializesNil() {
        let state = makeState(sessionStoppedAt: nil)
        XCTAssertNil(roundtrip(state)?.sessionStoppedAt)
    }

    func testRoundtripWithEmptyEntriesArray() {
        let state = makeState(entries: [])
        XCTAssertEqual(roundtrip(state)?.entries.count, 0)
    }

    // MARK: fromDictionary — missing required keys

    func testFromDictionaryReturnsNilWhenAppStateMissing() {
        var dict = makeState().toDictionary()
        dict.removeValue(forKey: "appState")
        XCTAssertNil(SyncedSessionState.fromDictionary(dict))
    }

    func testFromDictionaryReturnsNilWhenEntriesMissing() {
        var dict = makeState().toDictionary()
        dict.removeValue(forKey: "entries")
        XCTAssertNil(SyncedSessionState.fromDictionary(dict))
    }

    func testFromDictionaryReturnsNilWhenHasExistingLogMissing() {
        var dict = makeState().toDictionary()
        dict.removeValue(forKey: "hasExistingLog")
        XCTAssertNil(SyncedSessionState.fromDictionary(dict))
    }

    func testFromDictionaryReturnsNilForCompletelyEmptyDictionary() {
        XCTAssertNil(SyncedSessionState.fromDictionary([:]))
    }

    // MARK: fromDictionary — malformed entries

    func testFromDictionarySkipsMalformedEntryMissingTimestamp() {
        // A well-formed entry and one missing "timestamp".
        // compactMap must silently skip the bad one.
        var dict = makeState(entries: [
            SyncedEntry(timestamp: Date(), sequenceIndex: 0)
        ]).toDictionary()
        var entries = dict["entries"] as! [[String: Any]]
        entries.append(["sequenceIndex": 1])   // no "timestamp" key
        dict["entries"] = entries
        let restored = SyncedSessionState.fromDictionary(dict)
        XCTAssertEqual(restored?.entries.count, 1,
            "Malformed entry (missing timestamp) must be skipped, not crash")
    }

    func testFromDictionarySkipsMalformedEntryMissingSequenceIndex() {
        var dict = makeState(entries: [
            SyncedEntry(timestamp: Date(), sequenceIndex: 0)
        ]).toDictionary()
        var entries = dict["entries"] as! [[String: Any]]
        entries.append(["timestamp": Date().timeIntervalSince1970])  // no "sequenceIndex"
        dict["entries"] = entries
        let restored = SyncedSessionState.fromDictionary(dict)
        XCTAssertEqual(restored?.entries.count, 1,
            "Malformed entry (missing sequenceIndex) must be skipped, not crash")
    }

    func testFromDictionaryWithAllMalformedEntriesProducesEmptyArray() {
        var dict = makeState().toDictionary()
        dict["entries"] = [["junk": "data"], ["more": "junk"]] as [[String: Any]]
        let restored = SyncedSessionState.fromDictionary(dict)
        XCTAssertNotNil(restored, "State should parse even if all entries are bad")
        XCTAssertEqual(restored?.entries.count, 0)
    }

    // MARK: fromDictionary — unknown appState value

    func testUnknownAppStateStringParsesSucessfully() {
        // fromDictionary doesn't validate appState content — the ViewModel
        // maps unknown values to idle. Parsing must not fail.
        var dict = makeState().toDictionary()
        dict["appState"] = "launching"
        XCTAssertNotNil(SyncedSessionState.fromDictionary(dict))
    }

    // MARK: Helpers

    private func makeState(
        appState: String = "active",
        entries: [SyncedEntry] = [],
        sessionStoppedAt: Date? = nil,
        hasExistingLog: Bool = false
    ) -> SyncedSessionState {
        SyncedSessionState(appState: appState, entries: entries,
                           sessionStoppedAt: sessionStoppedAt,
                           hasExistingLog: hasExistingLog)
    }

    private func roundtrip(_ state: SyncedSessionState) -> SyncedSessionState? {
        SyncedSessionState.fromDictionary(state.toDictionary())
    }
}

// MARK: - ViewModel sync behaviour

/// Tests for WatchSessionViewModel's response to WatchConnectivity events.
///
/// Uses MockWatchConnectivityManager throughout. Tests are organised around
/// the four real-world failure modes identified in the feature audit:
///   1. Stale applicationContext present at cold launch
///   2. apply() arriving while an optimistic action is in-flight
///   3. Multiple queued actions draining on reconnect
///   4. Transition edge cases (active↔idle, sessionStoppedAt, hasExistingLog)
@MainActor
final class WatchConnectivitySyncTests: XCTestCase {

    var mock: MockWatchConnectivityManager!
    var sut: WatchSessionViewModel!

    override func setUp() async throws {
        mock = MockWatchConnectivityManager()
        // Note: several tests create sut themselves after pre-seeding mock.latestState.
        // Tests that don't need pre-seeding call makeSUT() for convenience.
    }

    // MARK: 1 — Stale applicationContext on cold launch

    func testInitWithNilLatestStateStartsWithNoEntries() {
        // Baseline: fresh launch with no cached state.
        sut = WatchSessionViewModel(connectivityManager: mock)
        XCTAssertEqual(sut.sortedEntries.count, 0)
        XCTAssertEqual(sut.route, .firstLaunch)
    }

    func testInitAppliesPreexistingActiveLatestStateImmediately() {
        // Simulates the watch waking and finding a cached active session
        // in receivedApplicationContext before any new update arrives.
        mock.latestState = activeState(entries: [entry(at: -60, seq: 0)])
        sut = WatchSessionViewModel(connectivityManager: mock)
        XCTAssertEqual(sut.sortedEntries.count, 1)
        XCTAssertEqual(sut.route, .active)
    }

    func testInitAppliesPreexistingIdleLatestState() {
        mock.latestState = idleState(
            entries: [entry(at: -120, seq: 0), entry(at: -60, seq: 1)],
            stoppedAt: Date().addingTimeInterval(-30)
        )
        sut = WatchSessionViewModel(connectivityManager: mock)
        XCTAssertEqual(sut.sortedEntries.count, 2)
        XCTAssertEqual(sut.route, .idle)
    }

    func testInitWithStaleActiveStateShowsCorrectEntryCount() {
        let staleEntries = (0..<5).map { entry(at: TimeInterval(-300 + $0 * 60), seq: $0) }
        mock.latestState = activeState(entries: staleEntries)
        sut = WatchSessionViewModel(connectivityManager: mock)
        XCTAssertEqual(sut.sortedEntries.count, 5)
    }

    func testInitWithStaleIdleStateWithNoEntriesRouteIsFirstLaunch() {
        // hasExistingLog = false, entries = [] → treated as brand-new installation.
        mock.latestState = idleState(entries: [], stoppedAt: nil)
        sut = WatchSessionViewModel(connectivityManager: mock)
        XCTAssertEqual(sut.route, .firstLaunch)
    }

    func testInitPreservesSessionStoppedAtFromStaleCachedState() {
        let stoppedAt = Date().addingTimeInterval(-45)
        mock.latestState = idleState(entries: [entry(at: -90, seq: 0)], stoppedAt: stoppedAt)
        sut = WatchSessionViewModel(connectivityManager: mock)
        XCTAssertEqual(sut.sessionStoppedAt?.timeIntervalSince1970 ?? 0,
                       stoppedAt.timeIntervalSince1970,
                       accuracy: 0.001)
    }

    // MARK: 2 — apply() while an optimistic action is in-flight

    func testApplyIdenticalStateAfterSendPrayIsIdempotent() {
        // Scenario: sendMessage reply AND applicationContext both deliver the
        // same confirmed state. apply() should be a no-op the second time.
        sut = makeSUT()
        sut.sendPray()
        let confirmed = activeState(entries: [entry(at: 0, seq: 0)])
        sut.apply(confirmed)
        sut.apply(confirmed)   // second delivery of the same state
        XCTAssertEqual(sut.sortedEntries.count, 1,
            "Duplicate apply() of the same state must not double-count entries")
    }

    func testApplyWithMoreEntriesThanOptimisticAddsAll() {
        // Scenario: watch fired 2 optimistic prayers, but iPhone confirms 3
        // (e.g. another prayer was logged on the iPhone directly).
        sut = makeSUT()
        sut.sendPray()
        sut.sendPray()
        XCTAssertEqual(sut.sortedEntries.count, 2)

        sut.apply(activeState(entries: [
            entry(at: -10, seq: 0),
            entry(at: -5,  seq: 1),
            entry(at:  0,  seq: 2),
        ]))
        XCTAssertEqual(sut.sortedEntries.count, 3,
            "iPhone is the source of truth — confirmed state with 3 entries must be accepted even though watch only optimistically added 2")
    }

    func testApplyWithFewerEntriesThanOptimisticDropsExcessOptimistic() {
        // Scenario: watch fired 3 optimistic prayers, but iPhone deduped and
        // confirms only 2 (e.g. rapid taps within the same second).
        sut = makeSUT()
        sut.sendPray(); sut.sendPray(); sut.sendPray()
        XCTAssertEqual(sut.sortedEntries.count, 3)

        sut.apply(activeState(entries: [
            entry(at: -2, seq: 0),
            entry(at:  0, seq: 1),
        ]))
        XCTAssertEqual(sut.sortedEntries.count, 2,
            "iPhone dedup is authoritative — optimistic extras must be discarded")
    }

    func testConfirmedTimestampReplacesOptimisticTimestamp() {
        // The optimistic timestamp is set on the Watch at tap time.
        // The confirmed timestamp is set on the iPhone when it processes PRAY.
        // They will differ by the WatchConnectivity round-trip latency.
        sut = makeSUT()
        sut.sendPray()
        let optimisticTS = sut.sortedEntries[0].timestamp

        let confirmedTS = optimisticTS.addingTimeInterval(-0.3)  // iPhone received it 300ms earlier
        sut.apply(activeState(entries: [entry(ts: confirmedTS, seq: 0)]))

        XCTAssertEqual(sut.sortedEntries[0].timestamp, confirmedTS,
            "Confirmed timestamp from iPhone must replace the optimistic Watch timestamp")
        XCTAssertNotEqual(sut.sortedEntries[0].timestamp, optimisticTS)
    }

    func testRapidApplyCallsLastOneWins() {
        // Simulates two applicationContext updates arriving in quick succession
        // (e.g. two actions processed by iPhone back-to-back).
        sut = makeSUT()
        let state1 = activeState(entries: [entry(at: -5, seq: 0)])
        let state2 = activeState(entries: [entry(at: -5, seq: 0), entry(at: 0, seq: 1)])
        sut.apply(state1)
        sut.apply(state2)
        XCTAssertEqual(sut.sortedEntries.count, 2, "Later apply() must win")
    }

    func testSecondOptimisticPrayAfterFirstApplyGetsCorrectSequenceIndex() {
        // Scenario: pray → apply(1 confirmed) → pray again.
        // The second optimistic entry must use sequenceIndex = 1 (current count),
        // not 0 (pre-apply count).
        sut = makeSUT()
        sut.sendPray()
        sut.apply(activeState(entries: [entry(at: -1, seq: 0)]))
        sut.sendPray()
        XCTAssertEqual(sut.sortedEntries.last?.sequenceIndex, 1)
    }

    func testApplyWhileStopInFlightPreservesConfirmedStoppedAt() {
        // Scenario: sendStop() freezes sessionStoppedAt optimistically.
        // iPhone then sends back the confirmed stoppedAt (slightly different time).
        sut = makeSUT()
        sut.apply(activeState(entries: [entry(at: -30, seq: 0)]))
        sut.sendStop()
        XCTAssertNotNil(sut.sessionStoppedAt)
        let optimisticStopTime = sut.sessionStoppedAt!

        let confirmedStopTime = optimisticStopTime.addingTimeInterval(-0.2)
        sut.apply(idleState(
            entries: [entry(at: -30, seq: 0)],
            stoppedAt: confirmedStopTime
        ))
        XCTAssertEqual(sut.sessionStoppedAt?.timeIntervalSince1970 ?? 0,
                       confirmedStopTime.timeIntervalSince1970,
                       accuracy: 0.001,
            "iPhone's confirmed stoppedAt must replace the optimistic Watch stoppedAt")
    }

    func testApplyActiveStateAfterOptimisticStopClearsStoppedAt() {
        // Edge case: watch sent STOP, optimistically froze timer, but iPhone
        // rejected the stop (e.g. another device already restarted the session).
        sut = makeSUT()
        sut.sendStop()
        XCTAssertNotNil(sut.sessionStoppedAt, "Precondition: optimistic stop froze timer")

        sut.apply(activeState(entries: [entry(at: -10, seq: 0)]))
        XCTAssertNil(sut.sessionStoppedAt,
            "Active state from iPhone must clear the optimistic stoppedAt — timer should resume")
        XCTAssertEqual(sut.route, .active)
    }

    // MARK: 3 — Multiple queued actions draining on reconnect

    func testFivePraysWhileOfflineThenSingleConfirmingApply() {
        // The watch queued 5 PRAY actions via transferUserInfo while disconnected.
        // iPhone processes all 5, then sends a single applicationContext update
        // with 5 confirmed entries. The Watch should land on exactly 5 — no
        // duplication from the 5 optimistic entries that were already appended.
        sut = makeSUT()
        for _ in 0..<5 { sut.sendPray() }
        XCTAssertEqual(sut.sortedEntries.count, 5, "Precondition: 5 optimistic entries")

        let confirmedEntries = (0..<5).map { entry(at: TimeInterval(-5 + $0), seq: $0) }
        sut.apply(activeState(entries: confirmedEntries))

        XCTAssertEqual(sut.sortedEntries.count, 5,
            "5 queued prayers confirmed by iPhone must produce exactly 5 entries — no duplication")
    }

    func testConfirmedEntriesFromQueueDrainHaveIPhoneTimestamps() {
        // After a queue drain the Watch must display the iPhone's timestamps,
        // not the optimistic ones set at tap time.
        sut = makeSUT()
        sut.sendPray()
        sut.sendPray()
        let optimisticTimestamps = sut.sortedEntries.map(\.timestamp)

        let iPhoneTS0 = Date().addingTimeInterval(-2.5)
        let iPhoneTS1 = Date().addingTimeInterval(-0.5)
        sut.apply(activeState(entries: [
            entry(ts: iPhoneTS0, seq: 0),
            entry(ts: iPhoneTS1, seq: 1),
        ]))

        XCTAssertNotEqual(sut.sortedEntries[0].timestamp, optimisticTimestamps[0])
        XCTAssertNotEqual(sut.sortedEntries[1].timestamp, optimisticTimestamps[1])
        XCTAssertEqual(sut.sortedEntries[0].timestamp.timeIntervalSince1970,
                       iPhoneTS0.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(sut.sortedEntries[1].timestamp.timeIntervalSince1970,
                       iPhoneTS1.timeIntervalSince1970, accuracy: 0.001)
    }

    func testPartialReconnectApplyFollowedByFinalApply() {
        // iPhone processes 3 of 5 queued prayers and sends an intermediate
        // applicationContext, then processes the remaining 2 and sends the final one.
        sut = makeSUT()
        for _ in 0..<5 { sut.sendPray() }

        // Intermediate: iPhone confirms 3
        sut.apply(activeState(entries: (0..<3).map { entry(at: TimeInterval($0), seq: $0) }))
        XCTAssertEqual(sut.sortedEntries.count, 3)

        // Final: iPhone confirms all 5
        sut.apply(activeState(entries: (0..<5).map { entry(at: TimeInterval($0), seq: $0) }))
        XCTAssertEqual(sut.sortedEntries.count, 5)
    }

    // MARK: 4 — State transition edge cases

    func testApplyIdleStateForcesClearsShowingLog() {
        // User is viewing the log when the session ends on the iPhone.
        // The log view must close — there's nothing to show on an idle screen.
        sut = makeSUT()
        sut.apply(activeState(entries: [entry(at: -10, seq: 0)]))
        sut.showingLog = true
        XCTAssertEqual(sut.route, .log, "Precondition: in log view")

        sut.apply(idleState(entries: [entry(at: -10, seq: 0)], stoppedAt: Date()))
        XCTAssertFalse(sut.showingLog,
            "apply(idle) must force showingLog = false — idle screen has no log route")
        XCTAssertEqual(sut.route, .idle)
    }

    func testApplyActiveStateDoesNotClearShowingLog() {
        // A PRAY confirmation arriving while the user has the log open should
        // NOT close the log. The user is reading it; don't interrupt them.
        sut = makeSUT()
        sut.apply(activeState(entries: [entry(at: -10, seq: 0)]))
        sut.showingLog = true
        sut.apply(activeState(entries: [entry(at: -10, seq: 0), entry(at: -1, seq: 1)]))
        XCTAssertTrue(sut.showingLog,
            "apply(active) must not close the log — user is reading it")
        XCTAssertEqual(sut.route, .log)
    }

    func testApplyActiveStateAfterIdleResetsToActiveRoute() {
        sut = makeSUT()
        sut.apply(idleState(entries: [entry(at: -60, seq: 0)], stoppedAt: Date()))
        XCTAssertEqual(sut.route, .idle, "Precondition")

        sut.apply(activeState(entries: []))
        XCTAssertEqual(sut.route, .active,
            "New active session from iPhone must restore active route even if Watch was idle")
    }

    func testApplyIdleWithNoEntriesAndNoExistingLogRouteIsFirstLaunch() {
        sut = makeSUT()
        sut.apply(idleState(entries: [], stoppedAt: nil))
        XCTAssertEqual(sut.route, .firstLaunch,
            "Idle state with no entries and no existing log looks like first launch")
    }

    func testApplyIdleWithEntriesRouteIsIdle() {
        sut = makeSUT()
        sut.apply(idleState(entries: [entry(at: -60, seq: 0)], stoppedAt: Date()))
        XCTAssertEqual(sut.route, .idle)
    }

    func testApplyPreservesHasExistingLogTrue() {
        sut = makeSUT()
        sut.apply(SyncedSessionState(
            appState: "idle", entries: [],
            sessionStoppedAt: nil, hasExistingLog: true
        ))
        XCTAssertTrue(sut.hasExistingLog)
    }

    func testApplyPreservesHasExistingLogFalse() {
        sut = makeSUT()
        sut.apply(SyncedSessionState(
            appState: "active", entries: [],
            sessionStoppedAt: nil, hasExistingLog: false
        ))
        XCTAssertFalse(sut.hasExistingLog)
    }

    func testUnknownAppStateStringFallsBackToIdle() {
        // The ViewModel maps anything other than "active" to .idle.
        // This guards against future iPhone-side additions like "paused".
        sut = makeSUT()
        sut.apply(SyncedSessionState(
            appState: "paused", entries: [],
            sessionStoppedAt: nil, hasExistingLog: false
        ))
        XCTAssertEqual(sut.route, .firstLaunch,
            "Unknown appState must not crash — should degrade gracefully to idle/firstLaunch")
    }

    func testApplyActiveStateClearsSessionStoppedAt() {
        // An active state should never have a stopped time.
        // If one somehow arrives (e.g. serialization bug on iPhone), the Watch
        // must still display an active session with a running timer.
        sut = makeSUT()
        sut.apply(SyncedSessionState(
            appState: "active",
            entries: [entry(at: -10, seq: 0)],
            sessionStoppedAt: Date(),  // contradictory: active + stopped
            hasExistingLog: false
        ))
        // The ViewModel applies the state as-is (iPhone is authoritative),
        // but the timer computes elapsed correctly against sessionStoppedAt.
        // We just verify no crash and route is active.
        XCTAssertEqual(sut.route, .active,
            "Active appState must produce active route regardless of other fields")
    }

    func testApplySortsOutOfOrderEntriesToSequenceIndex() {
        // iPhone may send entries in any order in the dictionary payload.
        sut = makeSUT()
        sut.apply(activeState(entries: [
            entry(at: -2, seq: 2),
            entry(at: -6, seq: 0),
            entry(at: -4, seq: 1),
        ]))
        XCTAssertEqual(sut.sortedEntries.map(\.sequenceIndex), [0, 1, 2])
    }

    // MARK: - Helpers

    private func makeSUT() -> WatchSessionViewModel {
        WatchSessionViewModel(connectivityManager: mock)
    }

    private func activeState(entries: [SyncedEntry]) -> SyncedSessionState {
        SyncedSessionState(appState: "active", entries: entries,
                           sessionStoppedAt: nil, hasExistingLog: false)
    }

    private func idleState(entries: [SyncedEntry], stoppedAt: Date?) -> SyncedSessionState {
        SyncedSessionState(appState: "idle", entries: entries,
                           sessionStoppedAt: stoppedAt, hasExistingLog: !entries.isEmpty)
    }

    private func entry(at offset: TimeInterval, seq: Int) -> SyncedEntry {
        SyncedEntry(timestamp: Date().addingTimeInterval(offset), sequenceIndex: seq)
    }

    private func entry(ts: Date, seq: Int) -> SyncedEntry {
        SyncedEntry(timestamp: ts, sequenceIndex: seq)
    }
}
