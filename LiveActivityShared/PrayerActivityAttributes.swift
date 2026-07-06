import ActivityKit
import Foundation

/// Live Activity contract shared between the iOS app (which starts/updates the
/// activity) and the GraceTimerWidget extension (which renders it).
///
/// Everything lives in ContentState — a Watch-side merge can insert an earlier
/// prayer and shift the session start, so nothing here is fixed at request time.
struct PrayerActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        /// Timestamp of the most recent prayer — the timer counts up from here.
        var lastPrayerAt: Date
        /// Timestamp of the first prayer in the session.
        var sessionStartedAt: Date
        /// Number of prayers logged this session.
        var prayerCount: Int
    }
}
