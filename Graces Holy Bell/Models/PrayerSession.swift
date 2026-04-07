import Foundation
import SwiftData

/// Represents a single prayer session.
///
/// At most one session exists in the database at any time.
/// Starting a new session deletes the previous one (cascade deletes its entries).
///
/// - `stoppedAt == nil` means the session is ACTIVE (timer running).
/// - `stoppedAt != nil` means the session is IDLE (timer frozen).
@Model
final class PrayerSession {

    /// When the session was started (first PRAY slide).
    var startedAt: Date

    /// When the session was stopped, or nil if still active.
    /// Used to compute the frozen final duration in IDLE state.
    var stoppedAt: Date?

    /// All prayer entries in this session. Deleted automatically when the session is deleted.
    @Relationship(deleteRule: .cascade, inverse: \PrayerEntry.session)
    var entries: [PrayerEntry] = []

    /// Whether this session is currently active (timer running).
    var isActive: Bool {
        stoppedAt == nil
    }

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }
}
