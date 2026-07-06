import SwiftUI

/// Past prayer sessions, browsed by calendar day. Presented as a sheet from
/// Settings. Read-only: sessions are frozen when the log is cleared, including
/// intentions and the deleted/re-timed change history.
struct PrayerHistoryView: View {

    var analytics: AnalyticsService? = nil
    var archiveStore = SessionArchiveStore()

    @Environment(\.dismiss) private var dismiss
    @State private var days: [(day: Date, sessions: [ArchivedSession])] = []

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {

            // ── Header bar: title + DONE (matches PrivacyPolicyView) ─────
            HStack(alignment: .firstTextBaseline) {
                Text("PRAYER\nHISTORY")
                    .font(.pixelFont(16, relativeTo: .title))
                    .foregroundStyle(Color.lcdDark)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.pixelFont(9))
                        .foregroundStyle(Color.lcdThumbText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.lcdSlider)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.lcdDark, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("history-done-button")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // ── Day-grouped session list ─────────────────────────────────
            if days.isEmpty {
                Spacer()
                Text("NO PAST SESSIONS YET")
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdMid)
                Text("Ended sessions are saved here.")
                    .font(.pixelFont(7))
                    .foregroundStyle(Color.lcdMid.opacity(0.8))
                    .padding(.top, 8)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(days, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(Self.dayFormatter.string(from: group.day).uppercased())
                                    .font(.pixelFont(9))
                                    .foregroundStyle(Color.lcdTitle)

                                ForEach(group.sessions) { session in
                                    ArchivedSessionBox(session: session)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.lcdBackground.ignoresSafeArea())
        .onAppear {
            days = archiveStore.sessionsByDay()
            analytics?.recordPrayerHistoryViewed(daysWithSessions: days.count)
        }
    }
}

/// One archived session rendered in the log's double-border box style:
/// prayer rows (with intention text), session totals, and the change history.
private struct ArchivedSessionBox: View {

    let session: ArchivedSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            ForEach(Array(session.prayers.enumerated()), id: \.offset) { index, prayer in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("#\(index + 1)  \(TimeFormatter.wallClockString(from: prayer.timestamp))")
                            .font(.pixelFont(9))
                            .foregroundStyle(Color.lcdDark)

                        if prayer.note != nil {
                            NoteGlyphIcon(size: 9, color: .lcdMid)
                                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                        }

                        Spacer(minLength: 8)

                        Text(DurationFormatter.string(from: duration(at: index)))
                            .font(.pixelFont(9))
                            .foregroundStyle(Color.lcdMid)
                    }

                    if let note = prayer.note {
                        Text(note)
                            .font(.pixelFont(7))
                            .foregroundStyle(Color.lcdMid)
                            .lineSpacing(3)
                            .padding(.leading, 14)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider().overlay(Color.lcdMid.opacity(0.4))

            // Totals row, same shape as the Notes export summary.
            let length = session.endedAt.timeIntervalSince(session.startedAt)
            Text("\(session.prayers.count) PRAYERS — \(DurationFormatter.string(from: length))")
                .font(.pixelFont(7))
                .foregroundStyle(Color.lcdMid)

            // Post-hoc change history (deleted / re-timed prayers).
            if !session.changes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(session.changes.enumerated()), id: \.offset) { _, change in
                        Text(changeLine(change))
                            .font(.pixelFont(7))
                            .foregroundStyle(Color.lcdMid.opacity(0.8))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelBorder()
    }

    /// Gap to the next prayer; the last prayer runs to the session end.
    private func duration(at index: Int) -> TimeInterval {
        let end = index + 1 < session.prayers.count
            ? session.prayers[index + 1].timestamp
            : session.endedAt
        return end.timeIntervalSince(session.prayers[index].timestamp)
    }

    private func changeLine(_ change: PrayerLogChange) -> String {
        let at = TimeFormatter.wallClockString(from: change.occurredAt)
        let original = TimeFormatter.wallClockString(from: change.originalTimestamp)
        switch change.kind {
        case .deleted:
            return "\(at) — deleted the \(original) prayer"
        case .timeEdited:
            let new = change.newTimestamp.map(TimeFormatter.wallClockString(from:)) ?? "?"
            return "\(at) — moved the \(original) prayer to \(new)"
        }
    }
}

#Preview {
    PrayerHistoryView()
}
