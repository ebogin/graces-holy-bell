import Foundation

/// A single prayer event. Compiles into both iPhone and Watch targets.
///
/// Events are versioned rather than immutable: the phone can edit a prayer's
/// time, attach an intention note, or delete it (a tombstone — `isDeleted`).
/// `updatedAt` orders competing versions of the same `id` during merge
/// (last-writer-wins), so phone-side edits win over the stale copies the
/// Watch echoes back in its snapshots.
struct PrayerEvent: Codable, Equatable, Identifiable {

    let id: UUID
    var timestamp: Date
    let origin: Origin
    /// When this version of the event was written. Drives LWW merge.
    var updatedAt: Date
    /// Tombstone — a deleted prayer stays in the event set (so the deletion
    /// syncs) but is excluded from the active log.
    var isDeleted: Bool
    /// Optional prayer intention attached on the phone.
    var note: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        origin: Origin,
        updatedAt: Date? = nil,
        isDeleted: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.origin = origin
        self.updatedAt = updatedAt ?? timestamp
        self.isDeleted = isDeleted
        self.note = note
    }

    enum Origin: String, Codable {
        case phone
        case watch
    }

    // MARK: - Codable (backward compatible)

    /// Pre-1.44 payloads (persisted Watch store, in-flight snapshots) lack the
    /// new fields — default them so old data decodes cleanly.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        origin = try container.decode(Origin.self, forKey: .origin)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? timestamp
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}
