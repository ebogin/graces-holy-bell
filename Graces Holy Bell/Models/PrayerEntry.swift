import Foundation
import SwiftData

/// Represents a single prayer event.
///
/// Each time the user slides PRAY, a new PrayerEntry is created with the current timestamp.
/// The `id` is a stable UUID used for deduplication across devices. Ordering is derived
/// from `timestamp` rather than `sequenceIndex` (which is kept for schema compatibility).
@Model
final class PrayerEntry {

    /// Stable identifier for deduplication during cross-device sync.
    var id: UUID

    /// The exact wall clock time when PRAY was slid.
    var timestamp: Date

    /// Device that originated this prayer ("phone" or "watch").
    var origin: String

    /// Legacy position field — kept for schema compatibility, not used in business logic.
    var sequenceIndex: Int

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
