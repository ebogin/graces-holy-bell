import SwiftUI

/// SCAFFOLDING PLACEHOLDER for a per-prayer figure action (Apple Watch).
///
/// Watch counterpart of the phone's `PrayerActionView`. After each PRAY swipe
/// the figure "performs an action" for a few seconds before returning to
/// praying (see WatchActiveSessionView). The real per-action artwork is not
/// built yet — this stands in for it, rendered in the watch figure's slot:
///
///   • a large "#N" (1-based prayer index),
///   • a small animated icon (a slowly rotating dashed ring),
///   • the action's stable `id`, so the real animation can be keyed off it.
///
/// Replace this view's body with the real animation, keyed off
/// `playback.actionID`. See HANDOFF-prayer-animations.md.
struct WatchPrayerActionView: View {

    let playback: ResolvedPrayerAction

    /// Height of the figure slot — WatchScreenLayout passes the same value it
    /// gives WatchPrayingFigureView, so the placeholder occupies that footprint.
    var height: CGFloat = 60

    @State private var spin = false

    var body: some View {
        ZStack {
            // Small animated icon: a rotating dashed ring — generic on purpose
            // so it reads as "placeholder", not as art.
            Circle()
                .strokeBorder(Color.lcdMid, style: StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
                .frame(width: height * 0.92, height: height * 0.92)
                .opacity(0.7)
                .rotationEffect(.degrees(spin ? 360 : 0))

            VStack(spacing: 1) {
                Text(playback.label)                       // large "#N"
                    .font(.pixelFont(20, relativeTo: .title3))
                    .foregroundStyle(Color.lcdDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(playback.actionID)                    // e.g. "action-1"
                    .font(.pixelFont(6, relativeTo: .caption2))
                    .foregroundStyle(Color.lcdMid)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prayer action placeholder \(playback.label)")
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}
