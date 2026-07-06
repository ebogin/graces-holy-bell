import Foundation

/// Composes the plain-text session log that gets saved to the Notes app.
///
/// One session per block; the user appends successive sessions to the bottom
/// of a single note via the Notes share extension. Table-style columns,
/// followed by intentions and the post-hoc change history (deleted / edited
/// prayers) so the saved record is honest about after-the-fact changes.
@MainActor
enum SessionLogFormatter {

    struct Prayer {
        let timestamp: Date
        let note: String?
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()

    static func compose(
        prayers: [Prayer],
        endedAt: Date,
        changes: [PrayerLogChange]
    ) -> String {
        guard let first = prayers.first else { return "" }

        var lines: [String] = []
        lines.append("⛪️ GRACE'S HOLY BELL")
        lines.append(dayFormatter.string(from: first.timestamp))
        lines.append("")

        // ── Prayer table ─────────────────────────────────────────────
        lines.append("#\tTIME\tDURATION")
        for (index, prayer) in prayers.enumerated() {
            let next = index + 1 < prayers.count ? prayers[index + 1].timestamp : endedAt
            let duration = DurationFormatter.string(from: next.timeIntervalSince(prayer.timestamp))
            let time = TimeFormatter.wallClockString(from: prayer.timestamp)
            lines.append("\(index + 1)\t\(time)\t\(duration)")
        }
        lines.append("")

        let sessionLength = endedAt.timeIntervalSince(first.timestamp)
        lines.append("Prayers: \(prayers.count) — Session: \(DurationFormatter.string(from: sessionLength))")
        lines.append("Ended: \(TimeFormatter.wallClockString(from: endedAt))")

        // ── Intentions ───────────────────────────────────────────────
        let intentions = prayers.enumerated().compactMap { index, prayer -> String? in
            guard let note = prayer.note, !note.isEmpty else { return nil }
            return "#\(index + 1) — \(note)"
        }
        if !intentions.isEmpty {
            lines.append("")
            lines.append("Intentions:")
            lines.append(contentsOf: intentions)
        }

        // ── Change history ───────────────────────────────────────────
        if !changes.isEmpty {
            lines.append("")
            lines.append("Changes:")
            for change in changes {
                let at = TimeFormatter.wallClockString(from: change.occurredAt)
                let original = TimeFormatter.wallClockString(from: change.originalTimestamp)
                switch change.kind {
                case .deleted:
                    lines.append("\(at) — deleted the \(original) prayer")
                case .timeEdited:
                    let new = change.newTimestamp.map(TimeFormatter.wallClockString(from:)) ?? "?"
                    lines.append("\(at) — moved the \(original) prayer to \(new)")
                }
            }
        }

        lines.append("")
        lines.append("─────────────────")
        return lines.joined(separator: "\n")
    }
}
