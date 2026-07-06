import SwiftUI
import SwiftData

/// Pixel-art prayer log container (iPhone).
///
/// Displays entries in a double-bordered LCD-green box.
/// Each row: "#N HH:MMam" on the left, duration on the right.
/// The last entry shows a live-updating duration during an active session.
/// Tapping a row opens PrayerDetailSheet (edit time / intention / delete) —
/// the tap itself never mutates the log.
struct PrayerLogView: View {

    let viewModel: SessionViewModel
    let now: Date
    /// Row tapped — the parent presents the detail sheet.
    var onSelectEntry: ((PrayerEntry) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(
                    Array(viewModel.sortedEntries.enumerated()),
                    id: \.element.persistentModelID
                ) { index, entry in
                    PrayerEntryRow(
                        viewModel: viewModel,
                        entry: entry,
                        index: index,
                        isLastEntry: index == viewModel.sortedEntries.count - 1,
                        now: now,
                        onSelect: onSelectEntry
                    )

                    if index < viewModel.sortedEntries.count - 1 {
                        Divider()
                            .overlay(Color.lcdMid.opacity(0.4))
                    }
                }
            }
            .padding(12)
        }
        .pixelBorder()
    }
}

/// A single prayer row — compact format: "#N HH:MMam [icon]   duration"
struct PrayerEntryRow: View {

    let viewModel: SessionViewModel
    let entry: PrayerEntry
    let index: Int
    let isLastEntry: Bool
    let now: Date
    var onSelect: ((PrayerEntry) -> Void)? = nil

    var body: some View {
        Button {
            onSelect?(entry)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text("#\(index + 1)  \(TimeFormatter.wallClockString(from: entry.timestamp))")
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdDark)

                // Subtle marker: this prayer has an intention attached.
                if entry.note != nil {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.lcdMid)
                        .accessibilityLabel("Has intention")
                }

                Spacer(minLength: 8)

                if isLastEntry && viewModel.appState == .active {
                    LiveDurationText(viewModel: viewModel, entryIndex: index, now: now)
                } else {
                    if let duration = viewModel.duration(for: index) {
                        Text(DurationFormatter.string(from: duration))
                            .font(.pixelFont(9))
                            .foregroundStyle(Color.lcdMid)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
        .accessibilityIdentifier("prayer-row-\(index + 1)")
    }
}
