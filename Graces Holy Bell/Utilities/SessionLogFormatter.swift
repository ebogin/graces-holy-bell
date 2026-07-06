import Foundation

/// Composes the plain-text prayer logs exported from Prayer History.
///
/// Table-style columns, followed by intentions and the post-hoc change
/// history (deleted / re-timed prayers) so the exported record is honest
/// about after-the-fact changes.
@MainActor
enum SessionLogFormatter {

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()

    /// All of a day's sessions as one shareable text block.
    static func composeDay(sessions: [ArchivedSession]) -> String {
        sessions.map(compose(session:)).joined(separator: "\n\n")
    }

    static func compose(session: ArchivedSession) -> String {
        guard let first = session.prayers.first else { return "" }

        var lines: [String] = []
        lines.append("⛪️ GRACE'S HOLY BELL")
        lines.append(dayFormatter.string(from: first.timestamp))
        lines.append("")

        // ── Prayer table ─────────────────────────────────────────────
        lines.append("#\tTIME\tDURATION")
        for (index, prayer) in session.prayers.enumerated() {
            let next = index + 1 < session.prayers.count
                ? session.prayers[index + 1].timestamp
                : session.endedAt
            let duration = DurationFormatter.string(from: next.timeIntervalSince(prayer.timestamp))
            let time = TimeFormatter.wallClockString(from: prayer.timestamp)
            lines.append("\(index + 1)\t\(time)\t\(duration)")
        }
        lines.append("")

        let sessionLength = session.endedAt.timeIntervalSince(first.timestamp)
        lines.append("Prayers: \(session.prayers.count) — Session: \(DurationFormatter.string(from: sessionLength))")
        lines.append("Ended: \(TimeFormatter.wallClockString(from: session.endedAt))")

        // ── Intentions ───────────────────────────────────────────────
        let intentions = session.prayers.enumerated().compactMap { index, prayer -> String? in
            guard let note = prayer.note, !note.isEmpty else { return nil }
            return "#\(index + 1) — \(note)"
        }
        if !intentions.isEmpty {
            lines.append("")
            lines.append("Intentions:")
            lines.append(contentsOf: intentions)
        }

        // ── Change history ───────────────────────────────────────────
        if !session.changes.isEmpty {
            lines.append("")
            lines.append("Changes:")
            for change in session.changes {
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
