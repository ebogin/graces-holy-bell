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
    @FocusState private var intentionFocused: Bool

    /// Which system picker is expanded below the pills (nil = collapsed).
    private enum ActivePicker { case date, time }
    @State private var activePicker: ActivePicker?

    /// Valid window for a prayer's time: after the clear epoch (earlier would
    /// prune the event) and never in the future.
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

            // Scrolls so the expanded pickers + SAVE stay reachable at
            // medium detent.
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // ── Time ─────────────────────────────────────────
                    Text("TIME")
                        .font(.pixelFont(7, relativeTo: .caption2))
                        .foregroundStyle(Color.lcdMid)

                    // App-styled date + time buttons. Tapping toggles the
                    // system picker (calendar / wheel) inline below.
                    HStack(spacing: 10) {
                        pickerPill(
                            label: Self.editDateFormatter.string(from: editedTime).uppercased(),
                            picker: .date,
                            identifier: "prayer-date-pill"
                        )
                        pickerPill(
                            label: TimeFormatter.wallClockString(from: editedTime),
                            picker: .time,
                            identifier: "prayer-time-pill"
                        )
                    }

                    // Expanded system picker for the active pill.
                    if activePicker == .date {
                        DatePicker(
                            "",
                            selection: $editedTime,
                            in: timeRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(Color.lcdDark)
                        .padding(6)
                        .pixelBorder()
                        .accessibilityIdentifier("prayer-date-picker")
                    } else if activePicker == .time {
                        DatePicker(
                            "",
                            selection: $editedTime,
                            in: timeRange,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .pixelBorder()
                        .accessibilityIdentifier("prayer-time-picker")
                    }

                    // ── Intention ────────────────────────────────────
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
                }
            }

            // ── Save ─────────────────────────────────────────────────
            Button {
                applyChanges()
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
        .presentationDetents([.medium, .large])
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
    }

    /// "JUL 5, 2026" for the date pill.
    private static let editDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// A Duration-dropdown-styled pill button. Tapping toggles the matching
    /// system picker (graphical calendar / time wheel) inline below the pills.
    @ViewBuilder
    private func pickerPill(
        label: String,
        picker: ActivePicker,
        identifier: String
    ) -> some View {
        let isActive = activePicker == picker
        Button {
            intentionFocused = false
            withAnimation(.easeInOut(duration: 0.2)) {
                activePicker = isActive ? nil : picker
            }
        } label: {
            Text(label)
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdThumbText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isActive ? Color.lcdProgress : Color.lcdSlider)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.lcdDark, lineWidth: isActive ? 2.5 : 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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

