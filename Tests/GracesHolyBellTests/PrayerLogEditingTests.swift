import XCTest
import SwiftData
@testable import Graces_Holy_Bell

/// Phone-side log editing: delete / edit time / intention, plus how those
/// changes flow through snapshots and merges (tombstones, LWW).
@MainActor
final class PrayerLogEditingTests: XCTestCase {

    var container: ModelContainer!
    var viewModel: SessionViewModel!

    override func setUp() async throws {
        container = try ModelContainer(
            for: PrayerSession.self, PrayerEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        viewModel = SessionViewModel(modelContext: container.mainContext)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "prayer.lastClearedAt")
        UserDefaults.standard.removeObject(forKey: "prayer.sessionChanges")
        viewModel = nil
        container = nil
    }

    // MARK: - Delete

    func test_deletePrayer_removesFromLog_andRecalculates() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        viewModel.logPrayer()
        let middle = viewModel.sortedEntries[1]

        viewModel.deletePrayer(middle)

        XCTAssertEqual(viewModel.sortedEntries.count, 2)
        XCTAssertFalse(viewModel.sortedEntries.contains(where: { $0.id == middle.id }))
    }

    func test_deleteLastRemainingPrayer_returnsToIdle() {
        viewModel.startNewSession()
        viewModel.deletePrayer(viewModel.sortedEntries[0])
        XCTAssertEqual(viewModel.appState, .idle)
        XCTAssertNil(viewModel.lastPrayerTimestamp)
    }

    func test_deletePrayer_keepsTombstoneInSnapshot() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        let victim = viewModel.sortedEntries[0]

        viewModel.deletePrayer(victim)

        let snapshot = viewModel.makeSnapshot(amenAlarmSettings: nil)
        let tombstone = snapshot.events.first(where: { $0.id == victim.id })
        XCTAssertNotNil(tombstone, "deletion must sync to the Watch as a tombstone")
        XCTAssertTrue(tombstone?.isDeleted ?? false)
    }

    func test_deletedPrayer_notResurrectedByStaleWatchEcho() {
        viewModel.startNewSession()
        let victim = viewModel.sortedEntries[0]
        let staleEcho = PrayerEvent(
            id: victim.id, timestamp: victim.timestamp, origin: .phone, updatedAt: victim.timestamp
        )

        viewModel.deletePrayer(victim)
        viewModel.mergeIncoming(snapshot: SyncSnapshot(
            events: [staleEcho], lastClearedAt: nil, amenAlarmFireAt: nil
        ))

        XCTAssertTrue(viewModel.sortedEntries.isEmpty)
    }

    // MARK: - Edit time

    func test_editPrayerTime_updatesTimestamp_andResorts() {
        viewModel.startNewSession()
        viewModel.logPrayer()
        let second = viewModel.sortedEntries[1]
        let newTime = viewModel.sortedEntries[0].timestamp.addingTimeInterval(-600)

        viewModel.editPrayerTime(second, to: newTime)

        XCTAssertEqual(viewModel.sortedEntries.first?.id, second.id)
        XCTAssertEqual(viewModel.sortedEntries.first?.timestamp, newTime)
    }

    func test_editPrayerTime_movesLastPrayer_timerBaseFollows() {
        viewModel.startNewSession()
        let entry = viewModel.sortedEntries[0]
        let newTime = entry.timestamp.addingTimeInterval(-1200)

        viewModel.editPrayerTime(entry, to: newTime)

        XCTAssertEqual(viewModel.lastPrayerTimestamp, newTime)
        XCTAssertGreaterThanOrEqual(viewModel.elapsedSinceLastPrayer(), 1200)
    }

    func test_editPrayerTime_winsOverStaleWatchEcho() {
        viewModel.startNewSession()
        let entry = viewModel.sortedEntries[0]
        let originalTime = entry.timestamp
        let staleEcho = PrayerEvent(
            id: entry.id, timestamp: originalTime, origin: .phone, updatedAt: originalTime
        )
        let newTime = originalTime.addingTimeInterval(-900)

        viewModel.editPrayerTime(entry, to: newTime)
        viewModel.mergeIncoming(snapshot: SyncSnapshot(
            events: [staleEcho], lastClearedAt: nil, amenAlarmFireAt: nil
        ))

        XCTAssertEqual(viewModel.sortedEntries.first?.timestamp, newTime)
    }

    // MARK: - Intention

    func test_setIntention_storesTrimmedNote() {
        viewModel.startNewSession()
        let entry = viewModel.sortedEntries[0]

        viewModel.setIntention(entry, note: "  For Grandma  ")

        XCTAssertEqual(viewModel.sortedEntries[0].note, "For Grandma")
    }

    func test_setIntention_emptyClearsNote() {
        viewModel.startNewSession()
        let entry = viewModel.sortedEntries[0]
        viewModel.setIntention(entry, note: "For Grandma")

        viewModel.setIntention(entry, note: "   ")

        XCTAssertNil(viewModel.sortedEntries[0].note)
    }

    func test_setIntention_syncsNoteInSnapshot() {
        viewModel.startNewSession()
        let entry = viewModel.sortedEntries[0]

        viewModel.setIntention(entry, note: "Peace")

        let snapshot = viewModel.makeSnapshot(amenAlarmSettings: nil)
        XCTAssertEqual(snapshot.events.first(where: { $0.id == entry.id })?.note, "Peace")
    }

    // MARK: - Incoming LWW updates (phone applies newer versions from merge)

    func test_mergeIncoming_newerVersion_updatesExistingEntry() {
        viewModel.startNewSession()
        let entry = viewModel.sortedEntries[0]
        let editedRemotely = PrayerEvent(
            id: entry.id,
            timestamp: entry.timestamp.addingTimeInterval(-300),
            origin: .phone,
            updatedAt: Date().addingTimeInterval(60)
        )

        viewModel.mergeIncoming(snapshot: SyncSnapshot(
            events: [editedRemotely], lastClearedAt: nil, amenAlarmFireAt: nil
        ))

        XCTAssertEqual(viewModel.sortedEntries.first?.timestamp, editedRemotely.timestamp)
    }

    // MARK: - Exported log composition

    func test_composeDay_containsPrayersIntentionsAndChanges() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let session = ArchivedSession(
            id: UUID(),
            endedAt: start.addingTimeInterval(1800),
            prayers: [
                ArchivedPrayer(timestamp: start, note: nil),
                ArchivedPrayer(timestamp: start.addingTimeInterval(600), note: "For Grandma")
            ],
            changes: [PrayerLogChange(
                kind: .deleted,
                occurredAt: start.addingTimeInterval(700),
                originalTimestamp: start.addingTimeInterval(650),
                newTimestamp: nil
            )]
        )

        let text = SessionLogFormatter.composeDay(sessions: [session])

        XCTAssertTrue(text.contains("GRACE'S HOLY BELL"))
        XCTAssertTrue(text.contains("Prayers: 2"))
        XCTAssertTrue(text.contains("For Grandma"))
        XCTAssertTrue(text.contains("deleted"))
    }
}
