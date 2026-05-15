import SwiftUI

/// Compact pixel-art prayer log for Apple Watch.
/// Shown in both idle (previous session, read-only) and active (live last entry).
struct WatchPrayerLogView: View {

    let viewModel: WatchSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(
                Array(viewModel.sortedEntries.enumerated()),
                id: \.element.sequenceIndex
            ) { index, entry in
                WatchPrayerEntryRow(
                    viewModel: viewModel,
                    entry: entry,
                    index: index,
                    isLastEntry: index == viewModel.sortedEntries.count - 1
                )
            }
        }
        .padding(8)
        .pixelBorder()
    }
}

struct WatchPrayerEntryRow: View {

    let viewModel: WatchSessionViewModel
    let entry: SyncedEntry
    let index: Int
    let isLastEntry: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("#\(index + 1) \(TimeFormatter.wallClockString(from: entry.timestamp))")
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            if isLastEntry && viewModel.appState == .active {
                WatchLiveDurationText(viewModel: viewModel, entryIndex: index)
            } else {
                if let duration = viewModel.duration(for: index) {
                    Text(DurationFormatter.string(from: duration))
                        .font(.pixelFont(9))
                        .foregroundStyle(Color.lcdMid)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}
