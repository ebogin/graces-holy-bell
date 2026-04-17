import SwiftUI

/// Large pixel-font elapsed timer (HH:MM:SS) for the active session screen.
///
/// Ticks every second via TimelineView. Always computed from stored timestamps
/// so it stays accurate after backgrounding or screen sleep.
struct LiveTimerView: View {

    let viewModel: SessionViewModel

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let elapsed = viewModel.elapsedSinceLastPrayer(at: context.date)
                Text(DurationFormatter.timerString(from: elapsed))
                    .font(.pixelFont(28))
                    .foregroundStyle(Color.lcdDark)
                    .contentTransition(.numericText())
            }
            Text("SINCE LAST PRAYER")
                .font(.pixelFont(7))
                .foregroundStyle(Color.lcdMid)
        }
    }
}

/// Live-updating duration label for the last prayer entry during an active session.
struct LiveDurationText: View {

    let viewModel: SessionViewModel
    let entryIndex: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            if let duration = viewModel.duration(for: entryIndex, at: context.date) {
                Text(DurationFormatter.string(from: duration))
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdMid)
            }
        }
    }
}
