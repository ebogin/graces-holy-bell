import SwiftUI

/// Pixel-art prayer log container (iPhone).
///
/// Displays entries in a double-bordered LCD-green box.
/// Each row: "#N HH:MMam" on the left, duration on the right.
/// The last entry shows a live-updating duration during an active session.
struct PrayerLogView: View {

    let viewModel: SessionViewModel

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
                        isLastEntry: index == viewModel.sortedEntries.count - 1
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

/// A single prayer row — compact format: "#N HH:MMam   duration"
struct PrayerEntryRow: View {

    let viewModel: SessionViewModel
    let entry: PrayerEntry
    let index: Int
    let isLastEntry: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("#\(index + 1)  \(TimeFormatter.wallClockString(from: entry.timestamp))")
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdDark)

            Spacer(minLength: 8)

            if isLastEntry && viewModel.appState == .active {
                LiveDurationText(viewModel: viewModel, entryIndex: index)
            } else {
                if let duration = viewModel.duration(for: index) {
                    Text(DurationFormatter.string(from: duration))
                        .font(.pixelFont(9))
                        .foregroundStyle(Color.lcdMid)
                }
            }
        }
    }
}
