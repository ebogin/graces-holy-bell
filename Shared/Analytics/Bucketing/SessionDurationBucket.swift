import Foundation

/// Maps a whole-SESSION duration (start → last prayer) to its anonymous bucket
/// label.
///
/// Distinct from ``DurationBucket``: that ladder times a *single prayer gap*
/// (avg ~1.5h) in 15-minute brackets capped at `4h+`, which is the wrong scale
/// for a session. A session is a run of prayers and can span many hours — up to
/// and past 24h — so long as each inter-prayer gap stays under the 12h
/// forgotten-timer threshold (see `SessionLifecycleReducer`). This ladder keeps
/// fine (30-minute) resolution at the low end where most sessions land, then
/// coarsens upward, ending in a `24h+` catch-all.
///
/// As with ``DurationBucket``, raw seconds are NEVER emitted — only these
/// labels. Intervals are half-open `[lo, hi)`.
enum SessionDurationBucket {

    /// Ordered lower-bounds (seconds) paired with the label for `[lo, nextLo)`.
    private static let brackets: [(lowerBound: TimeInterval, label: String)] = [
        (0,     "<30m"),
        (1800,  "30m–1h"),
        (3600,  "1–1.5h"),
        (5400,  "1.5–2h"),
        (7200,  "2–3h"),
        (10800, "3–4h"),
        (14400, "4–5h"),
        (18000, "5–7h"),
        (25200, "7–9h"),
        (32400, "9–12h"),
        (43200, "12–16h"),
        (57600, "16–20h"),
        (72000, "20–24h"),
        (86400, "24h+")
    ]

    /// Returns the bucket label for `interval`. Negative values clamp to `<30m`.
    static func label(for interval: TimeInterval) -> String {
        for bracket in brackets.reversed() where interval >= bracket.lowerBound {
            return bracket.label
        }
        return brackets[0].label // interval < 0
    }
}
