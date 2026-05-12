import SwiftUI

/// Watch version of the countdown to the next suggested prayer.
///
/// Counts down from `intervalSeconds` after each prayer.
/// Turns red and holds at 00:00:00 when the interval has elapsed.
struct WatchCountdownView: View {

    let viewModel: WatchSessionViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = remainingSeconds(at: context.date)
            VStack(spacing: 1) {
                Text("NEXT PRAYER IN")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(DurationFormatter.timerString(from: remaining))
                    .font(.system(size: 18, weight: .light, design: .monospaced))
                    .foregroundStyle(remaining <= 0 ? .red : .primary)
            }
        }
    }

    private func remainingSeconds(at now: Date) -> TimeInterval {
        guard let last = viewModel.lastPrayerTimestamp else {
            return viewModel.intervalSeconds
        }
        return viewModel.intervalSeconds - now.timeIntervalSince(last)
    }
}
