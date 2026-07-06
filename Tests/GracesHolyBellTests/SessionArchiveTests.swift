import XCTest
import SwiftData
@testable import Graces_Holy_Bell

/// Session archive: JSON store round-trip, calendar-day grouping, and the
/// ViewModel archiving a session whenever it ends (local clear, restart,
/// remote Watch clear).
@MainActor
final class SessionArchiveTests: XCTestCase {

    private var tempDir: URL!
    private var store: SessionArchiveStore!
    /// Retained here — the ViewModel's ModelContext dies with its container.
    private var container: ModelContainer!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-test-\(UUID().uuidString)")
        store = SessionArchiveStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        UserDefaults.standard.removeObject(forKey: "prayer.lastClearedAt")
        UserDefaults.standard.removeObject(forKey: "prayer.sessionChanges")
        container = nil
    }

    private func session(startingAt start: Date, prayers: Int = 2, gap: TimeInterval = 600) -> ArchivedSession {
        let stamps = (0..<prayers).map { start.addingTimeInterval(Double($0) * gap) }
        return ArchivedSession(
            id: UUID(),
            endedAt: stamps.last!.addingTimeInterval(gap),
            prayers: stamps.map { ArchivedPrayer(timestamp: $0, note: nil) },
            changes: []
        )
    }

    // MARK: - Store

    func test_appendAndLoad_roundTrips() {
        let s = session(startingAt: Date(timeIntervalSince1970: 1_000_000))
        store.append(s)
        XCTAssertEqual(store.load(), [s])
    }

    func test_sessionsByDay_groupsByStartDay_newestDayFirst() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now).addingTimeInterval(9 * 3600)
        let yesterday = today.addingTimeInterval(-24 * 3600)

        store.append(session(startingAt: yesterday))
        store.append(session(startingAt: today))
        store.append(session(startingAt: today.addingTimeInterval(3600)))

        let days = store.sessionsByDay(calendar: calendar)

        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].sessions.count, 2, "today's two sessions grouped together")
        XCTAssertGreaterThan(days[0].day, days[1].day, "newest day first")
        XCTAssertLessThan(
            days[0].sessions[0].startedAt, days[0].sessions[1].startedAt,
            "sessions within a day read oldest first"
        )
    }

    // MARK: - ViewModel archiving

    private func makeViewModel() throws -> SessionViewModel {
        container = try ModelContainer(
            for: PrayerSession.self, PrayerEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SessionViewModel(modelContext: container.mainContext, archiveStore: store)
    }

    func test_clearLog_archivesTheSession_withIntentionsAndChanges() throws {
        let vm = try makeViewModel()
        vm.startNewSession()
        vm.logPrayer()
        vm.setIntention(vm.sortedEntries[0], note: "Peace")
        vm.deletePrayer(vm.sortedEntries[1])

        vm.clearLog()

        let archived = store.load()
        XCTAssertEqual(archived.count, 1)
        XCTAssertEqual(archived.first?.prayers.count, 1)
        XCTAssertEqual(archived.first?.prayers.first?.note, "Peace")
        XCTAssertEqual(archived.first?.changes.count, 1)
        XCTAssertEqual(archived.first?.changes.first?.kind, .deleted)
    }

    func test_changeHistory_doesNotLeakIntoNextArchivedSession() throws {
        let vm = try makeViewModel()
        vm.startNewSession()
        vm.logPrayer()
        vm.deletePrayer(vm.sortedEntries[1])
        vm.clearLog()

        vm.startNewSession()
        vm.clearLog()

        let archived = store.load()
        XCTAssertEqual(archived.count, 2)
        XCTAssertEqual(archived[0].changes.count, 1)
        XCTAssertTrue(archived[1].changes.isEmpty, "change history must reset per session")
    }

    func test_clearLog_whenIdle_archivesNothing() throws {
        let vm = try makeViewModel()
        vm.clearLog()
        XCTAssertTrue(store.load().isEmpty)
    }

    func test_remoteClear_archivesSession_includingUnseenWatchPrayers() throws {
        let vm = try makeViewModel()
        vm.startNewSession()
        let localCount = vm.sortedEntries.count

        // Watch logged a prayer offline, then cleared; both arrive in one snapshot.
        let watchPrayer = PrayerEvent(id: UUID(), timestamp: Date().addingTimeInterval(-60), origin: .watch)
        let clearedAt = Date()
        vm.mergeIncoming(snapshot: SyncSnapshot(
            events: [watchPrayer], lastClearedAt: clearedAt, amenAlarmFireAt: nil
        ))

        XCTAssertEqual(vm.appState, .idle)
        let archived = store.load()
        XCTAssertEqual(archived.count, 1)
        XCTAssertEqual(archived.first?.prayers.count, localCount + 1,
                       "the offline Watch prayer belongs to the archived session")
    }
}
