import SwiftUI

/// Large elapsed timer for the Watch active session screen.
///
/// Same TimelineView pattern as iPhone — ticks every second, computes elapsed time
/// from stored timestamps. Works locally without an active iPhone connection.
struct WatchLiveTimerView: View {

    let viewModel: WatchSessionViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let elapsed = viewModel.elapsedSinceLastPrayer(at: context.date)
            Text(DurationFormatter.timerString(from: elapsed))
                .font(.system(size: 32, weight: .light, design: .monospaced))
                .contentTransition(.numericText())
        }
    }
}

/// Live-updating duration for the last entry in the Watch prayer log.
struct WatchLiveDurationText: View {

    let viewModel: WatchSessionViewModel
    let entryIndex: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            if let duration = viewModel.duration(for: entryIndex, at: context.date) {
                Text(DurationFormatter.string(from: duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
