import SwiftUI

/// Displays a live countdown to the next suggested prayer time.
///
/// Counts down from `settings.intervalSeconds` after each prayer.
/// Turns red and holds at 00:00:00 when the interval has elapsed.
/// Reacts to settings changes immediately (interval or destination change).
struct CountdownTimerView: View {

    let viewModel: SessionViewModel
    let settings: AppSettings

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = remainingSeconds(at: context.date)
            VStack(spacing: 2) {
                Text("NEXT PRAYER IN")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text(DurationFormatter.timerString(from: remaining))
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundStyle(remaining <= 0 ? .red : .primary)
            }
        }
    }

    private func remainingSeconds(at now: Date) -> TimeInterval {
        guard let last = viewModel.lastPrayerTimestamp else {
            return settings.intervalSeconds
        }
        return settings.intervalSeconds - now.timeIntervalSince(last)
    }
}
