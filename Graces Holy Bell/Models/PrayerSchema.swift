import Foundation
import SwiftData

// MARK: - Schema V1 (1.41 and earlier)

/// The store layout shipped through 1.41: session-based, no `id`/`origin` on
/// entries. Kept verbatim so Core Data can hash-match old on-disk stores and
/// route them through `PrayerMigrationPlan`. Never used by app code.
enum PrayerSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [PrayerEntry.self, PrayerSession.self]
    }

    @Model
    final class PrayerEntry {
        var timestamp: Date
        var sequenceIndex: Int
        var session: PrayerSession?

        init(timestamp: Date = .now, sequenceIndex: Int) {
            self.timestamp = timestamp
            self.sequenceIndex = sequenceIndex
        }
    }

    @Model
    final class PrayerSession {
        var startedAt: Date
        @Relationship(deleteRule: .cascade, inverse: \PrayerEntry.session)
        var entries: [PrayerEntry] = []

        init(startedAt: Date = .now) {
            self.startedAt = startedAt
        }
    }
}

// MARK: - Schema V2 (1.42+, CRDT event set)

/// Current layout: standalone prayer events with a stable `id` for cross-device
/// dedup and an `origin` device tag. The stored-property defaults are load-bearing:
/// they are what lets Core Data lightweight-migrate V1 rows (which lack both
/// columns) instead of failing with "missing attribute values on mandatory
/// destination attribute" — the 1.42 (16) data-loss bug.
enum PrayerSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [PrayerEntry.self, PrayerSession.self]
    }

    /// Represents a single prayer event.
    ///
    /// Each time the user slides PRAY, a new PrayerEntry is created with the current
    /// timestamp. The `id` is a stable UUID used for deduplication across devices.
    /// Ordering is derived from `timestamp` rather than `sequenceIndex` (which is
    /// kept for schema compatibility).
    @Model
    final class PrayerEntry {

        /// Stable identifier for deduplication during cross-device sync.
        var id: UUID = UUID()

        /// The exact wall clock time when PRAY was slid.
        var timestamp: Date = Date.now

        /// Device that originated this prayer ("phone" or "watch").
        var origin: String = "phone"

        /// Legacy position field — kept for schema compatibility, not used in business logic.
        var sequenceIndex: Int = 0

        /// Legacy session relationship — kept for schema compatibility.
        var session: PrayerSession?

        init(
            id: UUID = UUID(),
            timestamp: Date = .now,
            origin: String = PrayerEvent.Origin.phone.rawValue,
            sequenceIndex: Int = 0
        ) {
            self.id = id
            self.timestamp = timestamp
            self.origin = origin
            self.sequenceIndex = sequenceIndex
        }
    }

    /// Represents a single prayer session.
    ///
    /// Legacy container from the V1 model — retained only so old stores migrate.
    /// The active log is now derived from PrayerEntry timestamps + the clear epoch.
    @Model
    final class PrayerSession {

        /// When the session was started (first PRAY slide).
        var startedAt: Date = Date.now

        /// All prayer entries in this session. Deleted automatically when the session is deleted.
        @Relationship(deleteRule: .cascade, inverse: \PrayerEntry.session)
        var entries: [PrayerEntry] = []

        init(startedAt: Date = .now) {
            self.startedAt = startedAt
        }
    }
}

// MARK: - Schema V3 (1.44+, editable events)

/// Adds phone-side editing support: `updatedAt` (last-writer-wins ordering for
/// cross-device merge), `isRemoved` (tombstone — deleted prayers stay in the
/// store so the deletion syncs to the Watch; named to avoid colliding with
/// PersistentModel's built-in `isDeleted`, which silently swallows writes),
/// and `note` (prayer intention).
/// As with V2, the stored-property defaults are load-bearing: they let Core
/// Data lightweight-migrate V2 rows that lack the new columns.
enum PrayerSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [PrayerEntry.self, PrayerSession.self]
    }

    @Model
    final class PrayerEntry {

        /// Stable identifier for deduplication during cross-device sync.
        var id: UUID = UUID()

        /// The exact wall clock time when PRAY was slid (editable post-hoc).
        var timestamp: Date = Date.now

        /// Device that originated this prayer ("phone" or "watch").
        var origin: String = "phone"

        /// When this version of the event was last written — LWW merge ordering.
        var updatedAt: Date = Date.now

        /// Tombstone: excluded from the active log but kept so the deletion syncs.
        var isRemoved: Bool = false

        /// Optional prayer intention text.
        var note: String?

        /// Legacy position field — kept for schema compatibility, not used in business logic.
        var sequenceIndex: Int = 0

        /// Legacy session relationship — kept for schema compatibility.
        var session: PrayerSession?

        init(
            id: UUID = UUID(),
            timestamp: Date = .now,
            origin: String = PrayerEvent.Origin.phone.rawValue,
            updatedAt: Date? = nil,
            isRemoved: Bool = false,
            note: String? = nil,
            sequenceIndex: Int = 0
        ) {
            self.id = id
            self.timestamp = timestamp
            self.origin = origin
            self.updatedAt = updatedAt ?? timestamp
            self.isRemoved = isRemoved
            self.note = note
            self.sequenceIndex = sequenceIndex
        }
    }

    /// Legacy container from the V1 model — retained only so old stores migrate.
    @Model
    final class PrayerSession {

        var startedAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \PrayerEntry.session)
        var entries: [PrayerEntry] = []

        init(startedAt: Date = .now) {
            self.startedAt = startedAt
        }
    }
}

/// App code always speaks the current schema.
typealias PrayerEntry = PrayerSchemaV3.PrayerEntry
typealias PrayerSession = PrayerSchemaV3.PrayerSession

// MARK: - Migration plan

enum PrayerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PrayerSchemaV1.self, PrayerSchemaV2.self, PrayerSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// Custom (not lightweight) because the schema default stamps every migrated
    /// row with the *same* UUID — `didMigrate` reassigns a unique id per row so
    /// cross-device dedup (a Set of ids) stays sound. Only V1 stores enter this
    /// stage; rows minted on V2 keep the ids they were created with.
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: PrayerSchemaV1.self,
        toVersion: PrayerSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let entries = try context.fetch(FetchDescriptor<PrayerSchemaV2.PrayerEntry>())
            for entry in entries {
                entry.id = UUID()
                entry.origin = PrayerEvent.Origin.phone.rawValue
            }
            try context.save()
        }
    )

    /// Lightweight: the new V3 columns (`updatedAt`, `isRemoved`, `note`) all
    /// have schema defaults, so V2 rows migrate in place. `updatedAt` defaulting
    /// to migration time is sound — the migrated row is the only version of the
    /// event anywhere, so LWW has nothing to lose against.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: PrayerSchemaV2.self,
        toVersion: PrayerSchemaV3.self
    )
}
