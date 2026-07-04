import XCTest
import SwiftData
@testable import Graces_Holy_Bell

/// Regression tests for the 1.42 (16) data-loss bug: a 1.41-era store (no
/// `id`/`origin` on PrayerEntry) must migrate in place instead of failing with
/// "missing attribute values on mandatory destination attribute" and leaving
/// the app running against a store that never loaded.
final class PrayerSchemaMigrationTests: XCTestCase {

    private var storeURL: URL!

    override func setUp() {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-test-\(UUID().uuidString).store")
    }

    override func tearDown() {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
        }
    }

    /// Builds a 1.41-layout store on disk: one session holding one prayer per timestamp.
    private func makeV1Store(timestamps: [Date]) throws {
        let schema = Schema(versionedSchema: PrayerSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: storeURL)
        )
        let context = ModelContext(container)
        let session = PrayerSchemaV1.PrayerSession(startedAt: timestamps.first ?? .now)
        context.insert(session)
        for (index, timestamp) in timestamps.enumerated() {
            let entry = PrayerSchemaV1.PrayerEntry(timestamp: timestamp, sequenceIndex: index)
            entry.session = session
            context.insert(entry)
        }
        try context.save()
    }

    private func openCurrent() throws -> ModelContainer {
        let schema = Schema(versionedSchema: PrayerSchemaV2.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: PrayerMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: storeURL)
        )
    }

    private func fetchEntries(_ container: ModelContainer) throws -> [PrayerEntry] {
        try ModelContext(container).fetch(
            FetchDescriptor<PrayerEntry>(sortBy: [SortDescriptor(\.timestamp)])
        )
    }

    // MARK: - V1 → V2 (the 1.41 upgrade path that build 16 broke)

    func test_v1Store_opensThroughMigrationPlan_preservingRows() throws {
        let timestamps = [
            Date(timeIntervalSinceNow: -7200),
            Date(timeIntervalSinceNow: -3600),
            Date(timeIntervalSinceNow: -60)
        ]
        try makeV1Store(timestamps: timestamps)

        let container = try openCurrent() // 1.42 (16) threw here
        let entries = try fetchEntries(container)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(
            entries.map(\.timestamp.timeIntervalSince1970),
            timestamps.sorted().map(\.timeIntervalSince1970)
        )
    }

    func test_v1Store_migratedRows_getUniqueIDs_andPhoneOrigin() throws {
        try makeV1Store(timestamps: [
            Date(timeIntervalSinceNow: -120),
            Date(timeIntervalSinceNow: -60),
            Date(timeIntervalSinceNow: -1)
        ])

        let entries = try fetchEntries(try openCurrent())

        // Unique ids are load-bearing for cross-device dedup (SyncEngine keys on them).
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        XCTAssertTrue(entries.allSatisfy { $0.origin == PrayerEvent.Origin.phone.rawValue })
    }

    func test_v1Store_migratesDurably_acrossReopen() throws {
        try makeV1Store(timestamps: [Date(timeIntervalSinceNow: -60)])

        let firstOpenIDs = try fetchEntries(try openCurrent()).map(\.id)
        let secondOpen = try fetchEntries(try openCurrent())

        // Second open must not re-run the stage (ids stable, no duplicates).
        XCTAssertEqual(secondOpen.map(\.id), firstOpenIDs)
    }

    // MARK: - Already-V2 stores (fresh 1.42 installs) are untouched

    func test_v2Store_reopensThroughPlan_withIDsUnchanged() throws {
        let schema = Schema(versionedSchema: PrayerSchemaV2.self)
        let knownID = UUID()
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: storeURL)
            )
            let context = ModelContext(container)
            context.insert(PrayerEntry(id: knownID, timestamp: .now, origin: "watch"))
            try context.save()
        }

        let entries = try fetchEntries(try openCurrent())

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, knownID)
        XCTAssertEqual(entries.first?.origin, "watch")
    }
}
