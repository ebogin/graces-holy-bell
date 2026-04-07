import SwiftUI

/// Compact prayer log for the Apple Watch.
///
/// Scrollable via Digital Crown. Shows prayer number, time, and duration.
/// The last entry's duration is live-updating during an active session.
struct WatchPrayerLogView: View {

    let viewModel: WatchSessionViewModel

    var body: some View {
        ForEach(Array(viewModel.sortedEntries.enumerated()), id: \.element.sequenceIndex) { index, entry in
            WatchPrayerEntryRow(
                viewModel: viewModel,
                entry: entry,
                index: index,
                isLastEntry: index == viewModel.sortedEntries.count - 1
            )
        }
    }
}

/// A single prayer entry row for the Watch log.
struct WatchPrayerEntryRow: View {

    let viewModel: WatchSessionViewModel
    let entry: SyncedEntry
    let index: Int
    let isLastEntry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Prayer #N    5:00 AM
            HStack {
                Text("Prayer #\(index + 1)")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text(TimeFormatter.wallClockString(from: entry.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Duration
            HStack {
                Text("Duration")
                    .font(.caption2)
                Spacer()
                if isLastEntry && viewModel.appState == .active {
                    WatchLiveDurationText(viewModel: viewModel, entryIndex: index)
                } else {
                    if let duration = viewModel.duration(for: index) {
                        Text(DurationFormatter.string(from: duration))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
