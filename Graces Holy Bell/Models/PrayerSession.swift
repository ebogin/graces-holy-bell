import Foundation
import SwiftData

/// Represents a single prayer session.
///
/// At most one session exists in the database at any time, and an existing
/// session is always ACTIVE — ending a session deletes it (Clear Log).
/// Starting a new session deletes the previous one (cascade deletes its entries).
@Model
final class PrayerSession {

    /// When the session was started (first PRAY slide).
    var startedAt: Date

    /// All prayer entries in this session. Deleted automatically when the session is deleted.
    @Relationship(deleteRule: .cascade, inverse: \PrayerEntry.session)
    var entries: [PrayerEntry] = []

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }
}
