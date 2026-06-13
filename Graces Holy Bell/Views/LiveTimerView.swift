import SwiftUI

/// Large pixel-font elapsed timer (HH:MM:SS) for the active session screen.
///
/// `now` comes from the screen's single TimelineView tick. Always computed
/// from stored timestamps so it stays accurate after backgrounding or screen sleep.
struct LiveTimerView: View {

    let viewModel: SessionViewModel
    let now: Date

    var body: some View {
        VStack(spacing: 6) {
            Text(DurationFormatter.timerString(from: viewModel.elapsedSinceLastPrayer(at: now)))
                .font(.pixelFont(28, relativeTo: .largeTitle))
                .foregroundStyle(Color.lcdDark)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text("SINCE LAST PRAYER")
                .font(.pixelFont(7, relativeTo: .caption2))
                .foregroundStyle(Color.lcdMid)
        }
    }
}

/// Live-updating duration label for the last prayer entry during an active session.
struct LiveDurationText: View {

    let viewModel: SessionViewModel
    let entryIndex: Int
    let now: Date

    var body: some View {
        if let duration = viewModel.duration(for: entryIndex, at: now) {
            Text(DurationFormatter.string(from: duration))
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdMid)
        }
    }
}
