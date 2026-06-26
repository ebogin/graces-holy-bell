import Foundation

/// Maps a raw duration/interval to its anonymous bucket label (§3 of the plan).
///
/// Buckets align to Amen Alarm interval boundaries: a single `<30m` catch-all,
/// then 15-minute brackets out to 4 hours, then a `4h+` catch-all. Intervals are
/// half-open `[lo, hi)`. Raw seconds are NEVER emitted — only these labels.
enum DurationBucket {

    /// Ordered lower-bounds (seconds) paired with the label for `[lo, nextLo)`.
    /// 1800 = 30m; 14400 = 4h.
    private static let brackets: [(lowerBound: TimeInterval, label: String)] = [
        (0,     "<30m"),
        (1800,  "30–45m"),
        (2700,  "45–60m"),
        (3600,  "1h–1h15"),
        (4500,  "1h15–1h30"),
        (5400,  "1h30–1h45"),
        (6300,  "1h45–2h"),
        (7200,  "2h–2h15"),
        (8100,  "2h15–2h30"),
        (9000,  "2h30–2h45"),
        (9900,  "2h45–3h"),
        (10800, "3h–3h15"),
        (11700, "3h15–3h30"),
        (12600, "3h30–3h45"),
        (13500, "3h45–4h"),
        (14400, "4h+")
    ]

    /// Returns the bucket label for `interval`. Negative values clamp to `<30m`.
    static func label(for interval: TimeInterval) -> String {
        for bracket in brackets.reversed() where interval >= bracket.lowerBound {
            return bracket.label
        }
        return brackets[0].label // interval < 0
    }
}
