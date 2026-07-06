import SwiftUI

/// Full-screen AMEN takeover — shown when the Amen Alarm fires while the app
/// is open. The icon's bell tower rings, "AMEN!" blinks, the intense
/// dot-dot-dot haptic pattern runs for 30 seconds, and (when Bell Sound is on)
/// the clanging bell plays. Tap anywhere to dismiss.
struct AmenTakeoverView: View {

    /// When the alarm fired — haptics/audio cover the remainder of the
    /// 30-second window, so opening the app late doesn't ring longer.
    let fireDate: Date
    let soundEnabled: Bool
    let onDismiss: () -> Void

    /// How long the haptic pattern and bell audio run after the fire moment.
    static let alarmWindow: TimeInterval = 30

    @State private var haptics = AmenHapticsPlayer()
    @State private var sound = AmenSoundPlayer()

    var body: some View {
        // One frame clock (0.3s, anchored at the fire date) drives the bell
        // animation, the AMEN! blink, and — because the audio clangs every two
        // frames — keeps the sound in time with the bell hitting the sides.
        TimelineView(.periodic(from: fireDate, by: AmenBellTowerView.frameDuration)) { context in
            let frame = AmenBellTowerView.frameIndex(at: context.date, epoch: fireDate)

            ZStack {
                Color.lcdBackground.ignoresSafeArea()

                VStack(spacing: 30) {
                    Text("AMEN!")
                        .font(.pixelFont(40, relativeTo: .largeTitle))
                        .foregroundStyle(Color.lcdDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .opacity(frame % 2 == 0 ? 1 : 0)

                    AmenBellTowerView(epoch: fireDate)
                        .frame(maxWidth: 210, maxHeight: 400)

                    VStack(spacing: 12) {
                        Text("TIME TO PRAY")
                            .font(.pixelFont(12, relativeTo: .body))
                            .foregroundStyle(Color.lcdDark)
                        Text("TAP TO DISMISS")
                            .font(.pixelFont(8, relativeTo: .caption2))
                            .foregroundStyle(Color.lcdMid)
                    }
                }
                .padding(24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .accessibilityIdentifier("amen-takeover")
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

#Preview {
    AmenTakeoverView(fireDate: .now, soundEnabled: false) { }
}
