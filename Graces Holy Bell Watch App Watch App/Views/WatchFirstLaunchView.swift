import SwiftUI

/// First-launch screen — shown when there are no prayer entries yet.
/// All element positions come from WatchScreenLayout, shared with
/// WatchActiveSessionView, so the figure/slider/bottom row never move
/// between the two screens.
struct WatchFirstLaunchView: View {

    let viewModel: WatchSessionViewModel

    var body: some View {
        WatchScreenLayout(figurePose: .idle) {

            // Header: two-line app title, centered in the shared header area
            Text("GRACE'S\nHOLY BELL")
                .font(.pixelFont(11, relativeTo: .headline))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)

        } slider: {

            WatchPraySlider(label: "PRAY", labelPadLeft: false) {
                viewModel.sendStart()
            }

        } bottomRow: {

            // Square-wave blink driven by the timeline clock — unlike a
            // repeating Timer, this pauses automatically off-screen.
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Text("SLIDE TO BEGIN")
                    .font(.pixelFont(7, relativeTo: .caption2))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
            }
        }
    }
}
