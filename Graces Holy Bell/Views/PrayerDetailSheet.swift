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

            // ── Time ─────────────────────────────────────────────────
            Text("TIME")
                .font(.pixelFont(7, relativeTo: .caption2))
                .foregroundStyle(Color.lcdMid)

            // App-styled date + time buttons (Duration-dropdown pill style).
            // An invisible system DatePicker sits on top of each pill, so a
            // tap opens the standard calendar / time wheel popovers.
            HStack(spacing: 10) {
                pickerPill(
                    label: Self.editDateFormatter.string(from: editedTime).uppercased(),
                    components: .date,
                    identifier: "prayer-date-picker"
                )
                pickerPill(
                    label: TimeFormatter.wallClockString(from: editedTime),
                    components: .hourAndMinute,
                    identifier: "prayer-time-picker"
                )
            }

            // ── Intention ────────────────────────────────────────────
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

            Spacer(minLength: 0)

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

    /// A Duration-dropdown-styled pill showing the current value, with an
    /// invisible compact DatePicker scaled to exactly fill it, so a tap
    /// anywhere on the pill opens the system picker popover.
    @ViewBuilder
    private func pickerPill(
        label: String,
        components: DatePickerComponents,
        identifier: String
    ) -> some View {
        Text(label)
            .font(.pixelFont(9))
            .foregroundStyle(Color.lcdThumbText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.lcdSlider)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.lcdDark, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                FillingDatePicker(
                    selection: $editedTime,
                    range: timeRange,
                    components: components
                )
            )
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

/// An invisible compact DatePicker that hit-tests across its entire container.
///
/// The compact picker's tap target is only its intrinsic label size, so laid
/// over a wider pill it leaves dead zones. This measures both the container
/// and the picker's natural size and scales the picker to fill exactly —
/// scaleEffect scales hit-testing too, and an exact fit can't spill onto
/// neighboring controls.
private struct FillingDatePicker: View {

    @Binding var selection: Date
    let range: ClosedRange<Date>
    let components: DatePickerComponents

    @State private var naturalSize: CGSize = .zero

    var body: some View {
        GeometryReader { container in
            DatePicker("", selection: $selection, in: range, displayedComponents: components)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.lcdDark)
                .background(
                    GeometryReader { picker in
                        Color.clear
                            .onAppear { naturalSize = picker.size }
                            .onChange(of: picker.size) { _, newSize in naturalSize = newSize }
                    }
                )
                .scaleEffect(
                    x: naturalSize.width > 0 ? container.size.width / naturalSize.width : 1,
                    y: naturalSize.height > 0 ? container.size.height / naturalSize.height : 1
                )
                .position(x: container.size.width / 2, y: container.size.height / 2)
                // Nearly invisible but still hit-testable — the pill below is
                // the visible control, the system picker supplies the popover.
                .opacity(0.011)
        }
    }
}
