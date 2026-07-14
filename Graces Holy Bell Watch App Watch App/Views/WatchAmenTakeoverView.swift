import SwiftUI

/// Full-screen AMEN takeover for the Watch — shown when the Amen Alarm fires
/// while the app is open. The icon's bell tower rings, "AMEN!" blinks, the
/// dot-dot-dot wrist-haptic pattern runs for 30 seconds, and (when Bell Sound
/// is on) the clanging bell plays. Tap anywhere to dismiss.
struct WatchAmenTakeoverView: View {

    /// When the alarm fired — haptics/audio cover the remainder of the
    /// 30-second window, so opening the app late doesn't ring longer.
    let fireDate: Date
    let soundEnabled: Bool
    let onDismiss: () -> Void

    /// How long the haptic pattern and bell audio run after the fire moment.
    static let alarmWindow: TimeInterval = 30

    @State private var haptics = WatchAmenHapticsPlayer()
    @State private var sound = AmenSoundPlayer()

    var body: some View {
        // One frame clock (0.3s, anchored at the fire date) drives the bell
        // animation and the AMEN! blink. The bundled bell_alarm.caf clangs
        // much slower than every strike (every 2.4s, on the "strike-left"
        // pose) — matching every strike, then every other, both still felt
        // too fast — but starting playback from this same fireDate keeps
        // those clangs landing on real strikes.
        TimelineView(.periodic(from: fireDate, by: AmenBellTowerView.frameDuration)) { context in
            let frame = AmenBellTowerView.frameIndex(at: context.date, epoch: fireDate)

            ZStack {
                Color.lcdBackground.ignoresSafeArea()

                VStack(spacing: 6) {
                    Text("AMEN!")
                        .font(.pixelFont(16, relativeTo: .title3))
                        .foregroundStyle(Color.lcdDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .opacity(frame % 2 == 0 ? 1 : 0)

                    AmenBellTowerView(epoch: fireDate)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Text("TAP TO DISMISS")
                        .font(.pixelFont(6, relativeTo: .caption2))
                        .foregroundStyle(Color.lcdMid)
                }
                .padding(.top, DesignSystem.Metrics.clockClearance)
                .padding(.bottom, 8)
                .padding(.horizontal, 14)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .accessibilityIdentifier("watch-amen-takeover")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            let elapsed = max(0, Date().timeIntervalSince(fireDate))
            haptics.start(duration: Self.alarmWindow - elapsed)
            if soundEnabled {
                sound.start(elapsed: elapsed)
            }
        }
        .onDisappear {
            haptics.stop()
            sound.stop()
        }
    }
}
