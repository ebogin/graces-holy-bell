import SwiftUI
import WatchKit

/// Large pixel-font elapsed timer for the Watch active/log screens.
struct WatchLiveTimerView: View {

    let viewModel: WatchSessionViewModel

    // Press Start 2P advance ≈ 1pt per pt of font size.
    // "HH:MM:SS" = 8 chars. Safe max per char:
    //   41mm (176pt, 8pt h-pad each side) → 160pt ÷ 8 = 20pt → use 18pt
    //   49mm (205pt, 8pt h-pad each side) → 189pt ÷ 8 = 23pt → use 20pt
    private var timerFontSize: CGFloat {
        WKInterfaceDevice.current().screenBounds.width >= 200 ? 20 : 18
    }

    var body: some View {
        VStack(spacing: 3) {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let elapsed = viewModel.elapsedSinceLastPrayer(at: context.date)
                Text(DurationFormatter.timerString(from: elapsed))
                    .font(.pixelFont(timerFontSize))
                    .foregroundStyle(Color.lcdDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentTransition(.numericText())
            }
            Text("SINCE LAST PRAYER")
                .font(.pixelFont(7))
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
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdMid)
            }
        }
    }
}
