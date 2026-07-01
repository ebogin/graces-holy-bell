import SwiftUI
import WatchKit

/// Large pixel-font elapsed timer for the Watch active/log screens.
/// `now` comes from the screen's single TimelineView tick.
struct WatchLiveTimerView: View {

    let viewModel: WatchSessionViewModel
    let now: Date

    // Press Start 2P advance ≈ 1pt per pt of font size.
    // "HH:MM:SS" = 8 chars. Safe max per char:
    //   41mm (176pt, 8pt h-pad each side) → 160pt ÷ 8 = 20pt → use 18pt
    //   49mm (205pt, 8pt h-pad each side) → 189pt ÷ 8 = 23pt → use 20pt
    // Static so WatchScreenLayout's sizing template can reserve matching space.
    static var timerFontSize: CGFloat {
        WKInterfaceDevice.current().screenBounds.width >= 200 ? 20 : 18
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(DurationFormatter.timerString(from: viewModel.elapsedSinceLastPrayer(at: now)))
                .font(.pixelFont(Self.timerFontSize, relativeTo: .title2))
                .foregroundStyle(Color.lcdDark)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text("SINCE LAST PRAYER")
                .font(.pixelFont(7, relativeTo: .caption2))
                .foregroundStyle(Color.lcdMid)
        }
    }
}

/// Live-updating duration for the last log entry on Watch.
struct WatchLiveDurationText: View {

    let viewModel: WatchSessionViewModel
    let entryIndex: Int
    let now: Date
    var fontSize: CGFloat = 9

    var body: some View {
        if let duration = viewModel.duration(for: entryIndex, at: now) {
            Text.pixelTableText(DurationFormatter.string(from: duration), fontSize: fontSize)
                .foregroundStyle(Color.lcdMid)
        }
    }
}
