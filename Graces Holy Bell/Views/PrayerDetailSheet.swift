import SwiftUI
import SwiftData

/// Detail sheet for one prayer log entry — opened by tapping a log row.
///
/// Guards the log against accidental damage: opening the sheet mutates
/// nothing; time/intention changes apply only on an explicit SAVE, and
/// deletion sits behind its own CANNOT-BE-UNDONE confirmation.
struct PrayerDetailSheet: View {

    let viewModel: SessionViewModel
    let entry: PrayerEntry

    @Environment(\.dismiss) private var dismiss
    @State private var editedTime: Date
    @State private var intentionText: String
    @State private var showDeleteConfirmation = false
    @State private var showTimeWheel = false
    @State private var showCurrentPrayerConfirmation = false
    @State private var detent: PresentationDetent = .medium
    /// Measured height of the TIME pill, applied to the date arrows so both
    /// controls in the row are the same height.
    @State private var controlHeight: CGFloat = 40
    @FocusState private var intentionFocused: Bool

    private let calendar = Calendar.current

    /// Valid instant window for a prayer's time: after the clear epoch (earlier
    /// would prune the event) and never in the future.
    private let timeRange: ClosedRange<Date>

    init(viewModel: SessionViewModel, entry: PrayerEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _editedTime = State(initialValue: entry.timestamp)
        _intentionText = State(initialValue: entry.note ?? "")

        let lowerBound = viewModel.lastClearedAt.map { $0.addingTimeInterval(1) }
            ?? entry.timestamp.addingTimeInterval(-7 * 24 * 3600)
        let upperBound = max(Date(), entry.timestamp)
        self.timeRange = lowerBound...upperBound
    }

    /// 1-based position in the active log ("PRAYER #N").
    private var prayerNumber: Int {
        (viewModel.sortedEntries.firstIndex(where: { $0.id == entry.id }) ?? 0) + 1
    }

    private var timeChanged: Bool {
        editedTime != entry.timestamp
    }

    private var intentionChanged: Bool {
        let trimmed = intentionText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? nil : trimmed) != entry.note
    }

    private var hasChanges: Bool {
        timeChanged || intentionChanged
    }

    /// True when this entry is the most recent active prayer — the one the
    /// live "since last prayer" timer is currently counting from. Changing
    /// its time immediately jumps that running timer, so SAVE confirms first.
    private var isCurrentPrayer: Bool {
        viewModel.sortedEntries.last?.id == entry.id
    }

    // MARK: - Date bounds (±1 calendar day from the original prayer day)

    private var originalDay: Date { calendar.startOfDay(for: entry.timestamp) }
    private var minAllowedDay: Date { calendar.date(byAdding: .day, value: -1, to: originalDay) ?? originalDay }
    private var maxAllowedDay: Date { calendar.date(byAdding: .day, value: 1, to: originalDay) ?? originalDay }

    /// The previous day is reachable only if it stays within one day of the
    /// original AND still holds at least one valid instant (>= the clear epoch).
    private var canGoBackDay: Bool {
        guard let prev = calendar.date(byAdding: .day, value: -1, to: editedTime) else { return false }
        let prevDay = calendar.startOfDay(for: prev)
        guard prevDay >= minAllowedDay else { return false }
        let prevDayEnd = (calendar.date(byAdding: .day, value: 1, to: prevDay) ?? prevDay)
            .addingTimeInterval(-1)
        return prevDayEnd >= timeRange.lowerBound
    }

    /// The next day is reachable only if it stays within one day of the original
    /// AND has already begun (its start isn't in the future).
    private var canGoForwardDay: Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: editedTime) else { return false }
        let nextDay = calendar.startOfDay(for: next)
        guard nextDay <= maxAllowedDay else { return false }
        return nextDay <= timeRange.upperBound
    }

    /// Shifts the whole date by ±1 day, keeping the time of day, then clamps
    /// into the valid window (so a boundary day can't land in the future/epoch).
    private func shiftDay(by days: Int) {
        guard let candidate = calendar.date(byAdding: .day, value: days, to: editedTime) else { return }
        editedTime = min(max(candidate, timeRange.lowerBound), timeRange.upperBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ───────────────────────────────────────────────
            Text("PRAYER #\(prayerNumber)")
                .font(.pixelFont(14, relativeTo: .title3))
                .foregroundStyle(Color.lcdDark)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 22)

            Text("LOGGED AT \(TimeFormatter.wallClockString(from: entry.timestamp).uppercased())")
                .font(.pixelFont(7, relativeTo: .caption2))
                .foregroundStyle(Color.lcdMid)
                .frame(maxWidth: .infinity, alignment: .center)

            // Scrolls so the expanded time wheel + focused intention field
            // stay reachable; the sheet also grows to .large on either.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        // ── Date + Time on one row ───────────────────
                        HStack(alignment: .top, spacing: 12) {

                            // DATE (±1 day arrows)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("DATE")
                                    .font(.pixelFont(7, relativeTo: .caption2))
                                    .foregroundStyle(Color.lcdMid)

                                HStack(spacing: 6) {
                                    dateArrow(">", reversed: true, enabled: canGoBackDay) { shiftDay(by: -1) }
                                        .accessibilityIdentifier("prayer-date-back")

                                    Text(Self.editDateFormatter.string(from: editedTime).uppercased())
                                        .font(.pixelFont(9))
                                        .foregroundStyle(Color.lcdDark)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: controlHeight)

                                    dateArrow(">", reversed: false, enabled: canGoForwardDay) { shiftDay(by: 1) }
                                        .accessibilityIdentifier("prayer-date-forward")
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // TIME (pill toggles the themed wheel)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TIME")
                                    .font(.pixelFont(7, relativeTo: .caption2))
                                    .foregroundStyle(Color.lcdMid)

                                Button {
                                    intentionFocused = false
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showTimeWheel.toggle()
                                        if showTimeWheel { detent = .large }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(TimeFormatter.wallClockString(from: editedTime))
                                            .font(.pixelFont(9))
                                            .foregroundStyle(Color.lcdThumbText)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Text(">")
                                            .font(.pixelFont(8))
                                            .foregroundStyle(Color.lcdThumbText)
                                            .rotationEffect(.degrees(showTimeWheel ? 90 : 0))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 11)
                                    .background(showTimeWheel ? Color.lcdProgress : Color.lcdSlider)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.lcdDark, lineWidth: showTimeWheel ? 2.5 : 1.5)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(key: ControlHeightKey.self, value: geo.size.height)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("prayer-time-pill")
                            }
                            .frame(width: 132)
                        }

                        // Themed time wheel (full width, below the row)
                        if showTimeWheel {
                            ThemedTimeWheel(date: $editedTime, bounds: timeRange)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .pixelBorder()
                                .accessibilityIdentifier("prayer-time-picker")
                        }

                        // ── Intention ────────────────────────────────
                        Text("INTENTION")
                            .font(.pixelFont(7, relativeTo: .caption2))
                            .foregroundStyle(Color.lcdMid)

                        TextField("Add an intention...", text: $intentionText, axis: .vertical)
                            .font(.pixelFont(9))
                            .foregroundStyle(Color.lcdDark)
                            .lineLimit(2...4)
                            .focused($intentionFocused)
                            .padding(10)
                            .pixelBorder()
                            .accessibilityIdentifier("prayer-intention-field")
                            .id("intention")

                        // Keeps the focused field clear of the keyboard as the
                        // ScrollView scrolls its bottom anchor into view.
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: intentionFocused) { _, focused in
                    guard focused else { return }
                    detent = .large
                    // Let the detent grow and the keyboard rise, then reveal
                    // the intention field above the keyboard.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }
            .onPreferenceChange(ControlHeightKey.self) { controlHeight = $0 }

            // ── Save ─────────────────────────────────────────────────
            Button {
                if timeChanged && isCurrentPrayer {
                    showCurrentPrayerConfirmation = true
                } else {
                    applyChanges()
                }
            } label: {
                Text("SAVE")
                    .font(.pixelFont(12))
                    .foregroundStyle(Color.lcdThumbText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasChanges ? Color.lcdDark : Color.lcdMid.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges)
            .accessibilityIdentifier("prayer-save-button")

            // ── Delete ───────────────────────────────────────────────
            Button {
                showDeleteConfirmation = true
            } label: {
                Text("DELETE PRAYER")
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.lcdDark, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("prayer-delete-button")
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationBackground(Color.lcdBackground)
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Delete Prayer #\(prayerNumber)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deletePrayer(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Remove the \(TimeFormatter.wallClockString(from: entry.timestamp)) prayer from the log. This CANNOT BE UNDONE")
        }
        .confirmationDialog(
            "Change Prayer Time?",
            isPresented: $showCurrentPrayerConfirmation,
            titleVisibility: .visible
        ) {
            Button("Change Time") {
                applyChanges()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure? This will change the current prayer timer.")
        }
    }

    /// "SAT, JUL 5" for the date row. Weekday + short month/day; the year is
    /// omitted since edits are constrained to ±1 day.
    private static let editDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// A themed pixel-font arrow button; the right chevron is mirrored for "back".
    @ViewBuilder
    private func dateArrow(
        _ glyph: String,
        reversed: Bool,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.pixelFont(12))
                .foregroundStyle(enabled ? Color.lcdThumbText : Color.lcdMid.opacity(0.35))
                .scaleEffect(x: reversed ? -1 : 1, y: 1)
                .frame(width: 46, height: controlHeight)
                .background(enabled ? Color.lcdSlider : Color.lcdSlider.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(enabled ? Color.lcdDark : Color.lcdMid.opacity(0.35), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func applyChanges() {
        if intentionChanged {
            viewModel.setIntention(entry, note: intentionText)
        }
        if timeChanged {
            viewModel.editPrayerTime(entry, to: editedTime)
        }
        dismiss()
    }
}

/// Measures the TIME pill's rendered height so the date arrow buttons can
/// match it exactly instead of guessing a fixed value.
private struct ControlHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 40
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Hour / minute / AM-PM wheel built from SwiftUI Pickers so the pixel font
/// applies — the system `UIDatePicker` wheel can't be font-themed. Selections
/// are clamped into `bounds` (keeps the time out of the future / pre-epoch).
private struct ThemedTimeWheel: View {

    @Binding var date: Date
    let bounds: ClosedRange<Date>

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 2) {
            wheel(values: Array(1...12), selection: hourBinding) { "\($0)" }
                .frame(width: 54)

            Text(":")
                .font(.pixelFont(14))
                .foregroundStyle(Color.lcdDark)

            wheel(values: Array(0...59), selection: minuteBinding) { String(format: "%02d", $0) }
                .frame(width: 62)

            wheel(values: [0, 1], selection: ampmBinding) { $0 == 0 ? "AM" : "PM" }
                .frame(width: 62)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    private func wheel(
        values: [Int],
        selection: Binding<Int>,
        label: @escaping (Int) -> String
    ) -> some View {
        Picker("", selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(label(value))
                    .font(.pixelFont(12))
                    .foregroundStyle(Color.lcdDark)
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    // MARK: - Component bindings (compose + clamp back into `date`)

    private var hourBinding: Binding<Int> {
        Binding(
            get: {
                let h = calendar.component(.hour, from: date) % 12
                return h == 0 ? 12 : h
            },
            set: { setTime(hour12: $0, minute: nil, pm: nil) }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.minute, from: date) },
            set: { setTime(hour12: nil, minute: $0, pm: nil) }
        )
    }

    private var ampmBinding: Binding<Int> {
        Binding(
            get: { calendar.component(.hour, from: date) >= 12 ? 1 : 0 },
            set: { setTime(hour12: nil, minute: nil, pm: $0 == 1) }
        )
    }

    private func setTime(hour12: Int?, minute: Int?, pm: Bool?) {
        var c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let curHour = c.hour ?? 0
        let curPM = curHour >= 12
        let curHour12: Int = { let h = curHour % 12; return h == 0 ? 12 : h }()

        let h12 = hour12 ?? curHour12
        let isPM = pm ?? curPM
        var hour24 = h12 % 12
        if isPM { hour24 += 12 }

        c.hour = hour24
        c.minute = minute ?? c.minute
        guard let composed = calendar.date(from: c) else { return }
        date = min(max(composed, bounds.lowerBound), bounds.upperBound)
    }
}
