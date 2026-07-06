import SwiftUI

/// Past prayer sessions, browsed via a month calendar. Days that hold
/// archived sessions are highlighted; tapping one shows that day's logs
/// below the grid. Presented as a sheet from Settings.
struct PrayerHistoryView: View {

    var analytics: AnalyticsService? = nil
    var archiveStore = SessionArchiveStore()

    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current
    /// First moment of the displayed month.
    @State private var displayedMonth: Date = .now
    @State private var selectedDay: Date?
    /// Archived sessions keyed by their start day.
    @State private var sessionsByDay: [Date: [ArchivedSession]] = [:]

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

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

            monthNavigator
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            calendarGrid
                .padding(.horizontal, 20)

            // ── Selected day's sessions ──────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let day = selectedDay, let sessions = sessionsByDay[day] {
                        Text(Self.dayFormatter.string(from: day).uppercased())
                            .font(.pixelFont(9))
                            .foregroundStyle(Color.lcdTitle)

                        ForEach(sessions) { session in
                            ArchivedSessionBox(session: session)
                        }
                    } else if sessionsByDay.isEmpty {
                        Text("NO PAST SESSIONS YET")
                            .font(.pixelFont(9))
                            .foregroundStyle(Color.lcdMid)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                        Text("Ended sessions are saved here.")
                            .font(.pixelFont(7))
                            .foregroundStyle(Color.lcdMid.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("SELECT A HIGHLIGHTED DAY")
                            .font(.pixelFont(7))
                            .foregroundStyle(Color.lcdMid.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.lcdBackground.ignoresSafeArea())
        .onAppear {
            let grouped = archiveStore.sessionsByDay(calendar: calendar)
            sessionsByDay = Dictionary(uniqueKeysWithValues: grouped.map { ($0.day, $0.sessions) })
            analytics?.recordPrayerHistoryViewed(daysWithSessions: grouped.count)

            // Open on the most recent day that has sessions.
            if let latest = grouped.first?.day {
                displayedMonth = startOfMonth(latest)
                selectedDay = latest
            } else {
                displayedMonth = startOfMonth(.now)
            }
        }
    }

    // MARK: - Month navigation

    private var monthNavigator: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Text("<")
                    .font(.pixelFont(12))
                    .foregroundStyle(Color.lcdDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("history-prev-month")

            Spacer()

            Text(Self.monthFormatter.string(from: displayedMonth).uppercased())
                .font(.pixelFont(11))
                .foregroundStyle(Color.lcdDark)

            Spacer()

            Button { shiftMonth(1) } label: {
                Text(">")
                    .font(.pixelFont(12))
                    .foregroundStyle(isAtCurrentMonth ? Color.lcdMid.opacity(0.4) : Color.lcdDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAtCurrentMonth)
            .accessibilityIdentifier("history-next-month")
        }
    }

    private var isAtCurrentMonth: Bool {
        startOfMonth(displayedMonth) >= startOfMonth(.now)
    }

    private func shiftMonth(_ delta: Int) {
        if let shifted = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = startOfMonth(shifted)
            // Keep the day detail in sync with the visible month.
            selectedDay = latestSessionDay(in: displayedMonth)
        }
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func latestSessionDay(in month: Date) -> Date? {
        sessionsByDay.keys
            .filter { calendar.isDate($0, equalTo: month, toGranularity: .month) }
            .max()
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let weekdaySymbols = veryShortWeekdaySymbols()

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.pixelFont(7))
                    .foregroundStyle(Color.lcdMid)
            }

            ForEach(Array(monthCells().enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 26)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let hasSessions = sessionsByDay[day] != nil
        let isSelected = selectedDay == day
        let dayNumber = calendar.component(.day, from: day)

        Button {
            selectedDay = day
        } label: {
            Text("\(dayNumber)")
                .font(.pixelFont(9))
                .foregroundStyle(
                    isSelected ? Color.lcdThumbText
                        : hasSessions ? Color.lcdThumbText
                        : Color.lcdMid.opacity(0.6)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    isSelected ? Color.lcdDark
                        : hasSessions ? Color.lcdSlider
                        : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? Color.lcdDark : hasSessions ? Color.lcdDark.opacity(0.6) : Color.clear,
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!hasSessions)
        .accessibilityIdentifier("history-day-\(dayNumber)")
    }

    /// Weekday header starting from the calendar's first weekday (e.g. S M T W T F S).
    private func veryShortWeekdaySymbols() -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The displayed month as grid cells: nil for leading blanks, then each day.
    private func monthCells() -> [Date?] {
        let month = startOfMonth(displayedMonth)
        guard let dayRange = calendar.range(of: .day, in: .month, for: month) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: month)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in dayRange {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        return cells
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
                    HStack(alignment: .center) {
                        Text("#\(index + 1)  \(TimeFormatter.wallClockString(from: prayer.timestamp))")
                            .font(.pixelFont(9))
                            .foregroundStyle(Color.lcdDark)

                        if prayer.note != nil {
                            NoteGlyphIcon(size: 12, color: .lcdMid)
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
