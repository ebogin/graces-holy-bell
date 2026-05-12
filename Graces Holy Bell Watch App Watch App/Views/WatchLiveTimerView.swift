import SwiftUI

/// Large pixel-font elapsed timer for the Watch active session screen.
struct WatchLiveTimerView: View {

    let viewModel: WatchSessionViewModel

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let elapsed = viewModel.elapsedSinceLastPrayer(at: context.date)
                Text(DurationFormatter.timerString(from: elapsed))
                    .font(.pixelFont(16))
                    .foregroundStyle(Color.lcdDark)
                    .contentTransition(.numericText())
            }
            Text("SINCE LAST PRAYER")
                .font(.pixelFont(4))
                .foregroundStyle(Color.lcdMid)
        }
    }
}

/// Live-updating duration for the last log entry on Watch.
struct WatchLiveDurationText: View {

    let viewModel: WatchSessionViewModel
    let entryIndex: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            if let duration = viewModel.duration(for: entryIndex, at: context.date) {
                Text(DurationFormatter.string(from: duration))
                    .font(.pixelFont(6))
                    .foregroundStyle(Color.lcdMid)
            }
        }
    }
}
