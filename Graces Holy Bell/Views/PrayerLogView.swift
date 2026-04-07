import SwiftUI

/// Displays the chronological prayer log for the current (or most recent) session.
///
/// Shared between IdleView (read-only, frozen durations) and ActiveSessionView (live last duration).
/// Each row shows the prayer number, wall clock time, and elapsed duration.
struct PrayerLogView: View {

    let viewModel: SessionViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(Array(viewModel.sortedEntries.enumerated()), id: \.element.persistentModelID) { index, entry in
                    PrayerEntryRow(
                        viewModel: viewModel,
                        entry: entry,
                        index: index,
                        isLastEntry: index == viewModel.sortedEntries.count - 1
                    )
                }
            }
            .padding()
        }
    }
}

/// A single prayer entry in the log, showing the prayer time and its duration.
struct PrayerEntryRow: View {

    let viewModel: SessionViewModel
    let entry: PrayerEntry
    let index: Int
    let isLastEntry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Prayer #N    5:00 AM
            HStack {
                Text("Prayer #\(index + 1)")
                    .fontWeight(.semibold)
                Spacer()
                Text(TimeFormatter.wallClockString(from: entry.timestamp))
                    .foregroundStyle(.secondary)
            }

            // Duration #N    2h 14m 32s (or live timer)
            HStack {
                Text("Duration #\(index + 1)")
                Spacer()
                if isLastEntry && viewModel.appState == .active {
                    // Last entry during active session: show live-updating duration
                    LiveDurationText(viewModel: viewModel, entryIndex: index)
                } else {
                    // All other entries: show static duration
                    if let duration = viewModel.duration(for: index) {
                        Text(DurationFormatter.string(from: duration))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
