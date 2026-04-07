import SwiftUI

/// Displays the large elapsed timer (HH:MM:SS) during an active session.
///
/// Uses `TimelineView` to tick every second. The displayed value is always computed
/// from stored timestamps (`now - lastPrayerTimestamp`), never from a counter.
/// This means the timer is always accurate even after backgrounding or screen sleep.
struct LiveTimerView: View {

    let viewModel: SessionViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let elapsed = viewModel.elapsedSinceLastPrayer(at: context.date)
            Text(DurationFormatter.timerString(from: elapsed))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .contentTransition(.numericText())
        }
    }
}

/// Displays a live-updating duration for a specific prayer entry in the log.
///
/// Only used for the last entry in an active session (all other durations are static).
struct LiveDurationText: View {

    let viewModel: SessionViewModel
    let entryIndex: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            if let duration = viewModel.duration(for: entryIndex, at: context.date) {
                Text(DurationFormatter.string(from: duration))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
