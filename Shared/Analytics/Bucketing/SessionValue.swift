import Foundation

/// On-device classification of a prayer session's engagement quality (§4) —
/// the crucial signal for W1 cohort quality.
enum SessionValue: String {
    case high
    case low
}

/// Classifies a session as high- or low-value from its prayer timestamps.
enum SessionValueClassifier {

    /// Taps closer than this collapse into one "real" prayer, so accidental
    /// double/triple taps (e.g. a slow display) cannot drag a session down.
    static let rapidTapWindow: TimeInterval = 60

    /// Minimum gap between distinct prayers for a high-value session.
    static let highValueGap: TimeInterval = 1800 // 30 min

    /// High iff, after collapsing rapid taps, there are 2+ distinct prayers AND
    /// every consecutive gap is >= `highValueGap`. Low otherwise (1 prayer, or
    /// rapid succession).
    static func classify(prayerTimestamps: [Date]) -> SessionValue {
        let distinct = collapseRapidTaps(prayerTimestamps.sorted())
        guard distinct.count >= 2 else { return .low }

        for i in 1..<distinct.count where distinct[i].timeIntervalSince(distinct[i - 1]) < highValueGap {
            return .low
        }
        return .high
    }

    /// Keeps the first tap of each rapid-succession cluster. Input must be sorted.
    private static func collapseRapidTaps(_ sorted: [Date]) -> [Date] {
        var distinct: [Date] = []
        for t in sorted {
            if let anchor = distinct.last, t.timeIntervalSince(anchor) < rapidTapWindow {
                continue
            }
            distinct.append(t)
        }
        return distinct
    }
}
