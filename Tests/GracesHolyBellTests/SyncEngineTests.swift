import XCTest
@testable import Graces_Holy_Bell

final class SyncEngineTests: XCTestCase {

    // Fixed reference epoch so tests aren't time-sensitive.
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func t(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    private func event(
        id: UUID = UUID(),
        at offset: TimeInterval,
        origin: PrayerEvent.Origin = .phone
    ) -> PrayerEvent {
        PrayerEvent(id: id, timestamp: t(offset), origin: origin)
    }

    // MARK: - Merge: union + dedupe

    func test_merge_unionsCombinesUniqueEvents() {
        let a = event(at: 10)
        let b = event(at: 20)
        let c = event(at: 30)

        let (merged, _) = SyncEngine.merge(
            localEvents: [a, b],
            localClearedAt: nil,
            incomingEvents: [b, c],
            incomingClearedAt: nil
        )

        let ids = Set(merged.map(\.id))
        XCTAssertEqual(ids, [a.id, b.id, c.id])
    }

    func test_merge_deduplicatesByID() {
        let shared = event(at: 10)
        let (merged, _) = SyncEngine.merge(
            localEvents: [shared],
            localClearedAt: nil,
            incomingEvents: [shared],
            incomingClearedAt: nil
        )
        XCTAssertEqual(merged.count, 1)
    }

    // MARK: - Idempotency

    func test_merge_idempotent_sameInputTwice() {
        let events = [event(at: 5), event(at: 15)]
        let cleared = t(0)

        let (first, firstCleared) = SyncEngine.merge(
            localEvents: events,
            localClearedAt: cleared,
            incomingEvents: events,
            incomingClearedAt: cleared
        )
        let (second, secondCleared) = SyncEngine.merge(
            localEvents: first,
            localClearedAt: firstCleared,
            incomingEvents: events,
            incomingClearedAt: cleared
        )

        XCTAssertEqual(Set(second.map(\.id)), Set(first.map(\.id)))
        XCTAssertEqual(secondCleared, firstCleared)
    }

    // MARK: - Commutativity

    func test_merge_commutative_AmergeB_equalsBmergeA() {
        let a = event(at: 10)
        let b = event(at: 20)
        let clearedA = t(5)
        let clearedB = t(8)

        let (ab, abCleared) = SyncEngine.merge(
            localEvents: [a],
            localClearedAt: clearedA,
            incomingEvents: [b],
            incomingClearedAt: clearedB
        )
        let (ba, baCleared) = SyncEngine.merge(
            localEvents: [b],
            localClearedAt: clearedB,
            incomingEvents: [a],
            incomingClearedAt: clearedA
        )

        XCTAssertEqual(Set(ab.map(\.id)), Set(ba.map(\.id)))
        XCTAssertEqual(abCleared, baCleared)
    }

    // MARK: - Clear-wins pruning

    func test_merge_prunesEventsAtOrBeforeClearedAt() {
        let before = event(at: 10)
        let atClear = event(at: 20)
        let after = event(at: 30)
        let cleared = t(20)   // exact boundary — events AT cleared are also pruned

        let (merged, _) = SyncEngine.merge(
            localEvents: [before, atClear, after],
            localClearedAt: cleared,
            incomingEvents: [],
            incomingClearedAt: nil
        )

        let ids = Set(merged.map(\.id))
        XCTAssertFalse(ids.contains(before.id))
        XCTAssertFalse(ids.contains(atClear.id))
        XCTAssertTrue(ids.contains(after.id))
    }

    func test_merge_maxClearedAtWins() {
        let e = event(at: 100)
        let olderCleared = t(50)
        let newerCleared = t(90)

        let (merged, clearedAt) = SyncEngine.merge(
            localEvents: [e],
            localClearedAt: olderCleared,
            incomingEvents: [],
            incomingClearedAt: newerCleared
        )

        XCTAssertEqual(clearedAt, newerCleared)
        // e is at t+100 > t+90, so it survives
        XCTAssertEqual(merged.count, 1)
    }

    func test_merge_clearedAt_nil_treatedAsDistantPast() {
        let e = event(at: 10)
        let (merged, clearedAt) = SyncEngine.merge(
            localEvents: [e],
            localClearedAt: nil,
            incomingEvents: [],
            incomingClearedAt: nil
        )
        XCTAssertNil(clearedAt)
        XCTAssertEqual(merged.count, 1)
    }

    // MARK: - Post-clear new session

    func test_merge_prayersAfterClear_formNewSession() {
        let old = event(at: 10)
        let cleared = t(20)
        let fresh = event(at: 30)

        let (merged, _) = SyncEngine.merge(
            localEvents: [old, fresh],
            localClearedAt: cleared,
            incomingEvents: [],
            incomingClearedAt: nil
        )

        let ids = Set(merged.map(\.id))
        XCTAssertFalse(ids.contains(old.id))
        XCTAssertTrue(ids.contains(fresh.id))
    }

    // MARK: - Origin preserved

    func test_merge_originPreserved() {
        let phoneEvent = event(at: 10, origin: .phone)
        let watchEvent = event(at: 20, origin: .watch)

        let (merged, _) = SyncEngine.merge(
            localEvents: [phoneEvent],
            localClearedAt: nil,
            incomingEvents: [watchEvent],
            incomingClearedAt: nil
        )

        let byID = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
        XCTAssertEqual(byID[phoneEvent.id]?.origin, .phone)
        XCTAssertEqual(byID[watchEvent.id]?.origin, .watch)
    }

    // MARK: - activeLog

    func test_activeLog_sortedAscendingByTimestamp() {
        let a = event(at: 30)
        let b = event(at: 10)
        let c = event(at: 20)

        let log = SyncEngine.activeLog(events: [a, b, c], lastClearedAt: nil)
        XCTAssertEqual(log.map(\.id), [b.id, c.id, a.id])
    }

    func test_activeLog_excludesEventsAtOrBeforeClear() {
        let before = event(at: 5)
        let atClear = event(at: 10)
        let after = event(at: 15)

        let log = SyncEngine.activeLog(events: [before, atClear, after], lastClearedAt: t(10))
        XCTAssertEqual(log.map(\.id), [after.id])
    }

    // MARK: - isActive

    func test_isActive_falseWhenEmpty() {
        XCTAssertFalse(SyncEngine.isActive(events: [], lastClearedAt: nil))
    }

    func test_isActive_falseWhenAllPruned() {
        let e = event(at: 10)
        XCTAssertFalse(SyncEngine.isActive(events: [e], lastClearedAt: t(20)))
    }

    func test_isActive_trueWhenEventAfterClear() {
        let e = event(at: 30)
        XCTAssertTrue(SyncEngine.isActive(events: [e], lastClearedAt: t(20)))
    }

    // MARK: - Last-writer-wins (phone edits vs stale Watch echoes)

    func test_merge_sameID_laterUpdatedAtWins() {
        let id = UUID()
        let original = PrayerEvent(id: id, timestamp: t(10), origin: .phone, updatedAt: t(10))
        let edited = PrayerEvent(id: id, timestamp: t(5), origin: .phone, updatedAt: t(50))

        // Edited version is local, stale echo incoming — edit survives.
        let (a, _) = SyncEngine.merge(
            localEvents: [edited], localClearedAt: nil,
            incomingEvents: [original], incomingClearedAt: nil
        )
        XCTAssertEqual(a.first?.timestamp, t(5))

        // Edited version incoming — it overwrites the stale local copy.
        let (b, _) = SyncEngine.merge(
            localEvents: [original], localClearedAt: nil,
            incomingEvents: [edited], incomingClearedAt: nil
        )
        XCTAssertEqual(b.first?.timestamp, t(5))
    }

    func test_merge_tombstoneSurvivesStaleEcho() {
        let id = UUID()
        let live = PrayerEvent(id: id, timestamp: t(10), origin: .phone, updatedAt: t(10))
        let deleted = PrayerEvent(id: id, timestamp: t(10), origin: .phone, updatedAt: t(40), isDeleted: true)

        // The Watch echoing the pre-delete version must not resurrect the prayer.
        let (merged, _) = SyncEngine.merge(
            localEvents: [deleted], localClearedAt: nil,
            incomingEvents: [live], incomingClearedAt: nil
        )
        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged.first?.isDeleted ?? false)
    }

    func test_merge_notePropagates() {
        let id = UUID()
        let plain = PrayerEvent(id: id, timestamp: t(10), origin: .phone, updatedAt: t(10))
        let noted = PrayerEvent(id: id, timestamp: t(10), origin: .phone, updatedAt: t(30), note: "For Grandma")

        let (merged, _) = SyncEngine.merge(
            localEvents: [plain], localClearedAt: nil,
            incomingEvents: [noted], incomingClearedAt: nil
        )
        XCTAssertEqual(merged.first?.note, "For Grandma")
    }

    // MARK: - Tombstones excluded from derivations

    func test_activeLog_excludesDeletedEvents() {
        let live = event(at: 10)
        let dead = PrayerEvent(id: UUID(), timestamp: t(20), origin: .phone, isDeleted: true)

        let log = SyncEngine.activeLog(events: [live, dead], lastClearedAt: nil)
        XCTAssertEqual(log.map(\.id), [live.id])
    }

    func test_isActive_falseWhenOnlyTombstonesRemain() {
        let dead = PrayerEvent(id: UUID(), timestamp: t(20), origin: .phone, isDeleted: true)
        XCTAssertFalse(SyncEngine.isActive(events: [dead], lastClearedAt: nil))
    }

    func test_lastTimestamp_skipsTombstones() {
        let live = event(at: 10)
        let dead = PrayerEvent(id: UUID(), timestamp: t(30), origin: .phone, isDeleted: true)
        XCTAssertEqual(SyncEngine.lastTimestamp(events: [live, dead], lastClearedAt: nil), t(10))
    }

    // MARK: - lastTimestamp

    func test_lastTimestamp_isMaxActiveTimestamp() {
        let a = event(at: 10)
        let b = event(at: 30)
        let c = event(at: 20)

        let last = SyncEngine.lastTimestamp(events: [a, b, c], lastClearedAt: nil)
        XCTAssertEqual(last, t(30))
    }

    func test_lastTimestamp_nilWhenNoneActive() {
        let e = event(at: 10)
        let last = SyncEngine.lastTimestamp(events: [e], lastClearedAt: t(20))
        XCTAssertNil(last)
    }

    func test_lastTimestamp_ignoresEventsAtOrBeforeClear() {
        let pruned = event(at: 10)
        let surviving = event(at: 30)
        let last = SyncEngine.lastTimestamp(events: [pruned, surviving], lastClearedAt: t(20))
        XCTAssertEqual(last, t(30))
    }
}
