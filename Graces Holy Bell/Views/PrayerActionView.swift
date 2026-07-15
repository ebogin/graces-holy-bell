import SwiftUI

/// SCAFFOLDING PLACEHOLDER for a per-prayer figure action (iPhone).
///
/// After each PRAY swipe the figure "performs an action" for a few seconds
/// before returning to praying (see ActiveSessionView). The real per-action
/// artwork is not built yet — this stands in for it so the plumbing (remote
/// config → index selection → timed display in the figure's slot) can be
/// verified end-to-end. It renders, in the praying figure's exact footprint:
///
///   • a large "#N" (the 1-based prayer index — #1 after the first swipe,
///     #2 after the second, …),
///   • a small animated icon (a slowly rotating dashed ring) that signals
///     "an animation belongs here",
///   • the action's stable `id` (e.g. "action-1"), so whoever builds the real
///     animation can see which action is playing.
///
/// Replace this whole view's body with the real animation, keyed off
/// `playback.actionID`. See HANDOFF-prayer-animations.md.
struct PrayerActionView: View {

    let playback: ResolvedPrayerAction

    /// Matches PrayingFigureView's iPhone footprint (base 50×63 × scale) so the
    /// figure slot doesn't resize when the placeholder swaps in.
    var scale: CGFloat = 2.6

    @State private var spin = false
    @State private var pulse = false

    private var width: CGFloat { 50 * scale }
    private var height: CGFloat { 63 * scale }

    var body: some View {
        ZStack {
            // Small animated icon: a rotating dashed ring. Deliberately generic
            // (not a human figure) so it reads as "placeholder", not as art.
            Circle()
                .strokeBorder(Color.lcdMid, style: StrokeStyle(lineWidth: 2, dash: [4, 7]))
                .frame(width: width * 0.9, height: width * 0.9)
                .opacity(0.7)
                .rotationEffect(.degrees(spin ? 360 : 0))

            VStack(spacing: 8) {
                Text(playback.label)                       // large "#N"
                    .font(.pixelFont(44, relativeTo: .largeTitle))
                    .foregroundStyle(Color.lcdDark)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(playback.actionID)                    // e.g. "action-1"
                    .font(.pixelFont(8, relativeTo: .caption2))
                    .foregroundStyle(Color.lcdMid)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .scaleEffect(pulse ? 1.05 : 1.0)
            .padding(.horizontal, 8)
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prayer action placeholder \(playback.label)")
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                spin = true
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview("Action placeholder") {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        PrayerActionView(
            playback: ResolvedPrayerAction(
                prayerIndex: 1, actionID: "action-1", durationSeconds: 5, label: "#1"
            )
        )
    }
}
