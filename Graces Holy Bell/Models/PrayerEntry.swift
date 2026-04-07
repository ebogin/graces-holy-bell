import Foundation
import SwiftData

/// Represents a single prayer event within a session.
///
/// Each time the user slides PRAY, a new PrayerEntry is created with the current timestamp.
/// The `sequenceIndex` determines display order and provides the "Prayer #N" number.
@Model
final class PrayerEntry {

    /// The exact wall clock time when PRAY was slid.
    /// This is the source of truth for all elapsed time calculations.
    var timestamp: Date

    /// Zero-based position in the session (0 = first prayer, 1 = second, etc.).
    /// Used for deterministic ordering and "Prayer #N" display.
    var sequenceIndex: Int

    /// The session this entry belongs to.
    var session: PrayerSession?

    init(timestamp: Date = .now, sequenceIndex: Int) {
        self.timestamp = timestamp
        self.sequenceIndex = sequenceIndex
    }
}
