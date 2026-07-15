import SwiftUI

/// Pixel-art bell tower for the AMEN alarm takeover — 4 hand-authored
/// transparent-background sprite frames (same pattern as PrayingFigureView),
/// drawn with `.interpolation(.none)` for crisp pixels over `Color.lcdBackground`.
///
/// Frame cycle (0.3s/frame, matching the praying figure's cadence):
/// strike-left → rest → strike-right → rest, one full cycle every 1.2s.
/// Strikes land on frames 0 and 2, i.e. every 0.6s starting at `epoch` —
/// the takeover views' "AMEN" blink (`frame % 2 == 0`) follows every
/// strike, toggling every 0.3s. `bell_alarm.caf`'s clangs are every 2.4s
/// (unrelated to the frame rate — not changed with animation speed),
/// landing on every other "strike-left" pose; the rest are silent hits.
///
/// Artwork: 64×128-cell pixel grid exported at 8× (512×1024 PNGs) using the
/// LCD palette (lcdDark #1a2a0a, lcdMid #4a6a3a, lcdSlider #8aaa6a).
/// Compiled into both the iPhone and Watch targets from Shared/.
struct AmenBellTowerView: View {

    /// Animates the bell when true; static rest pose when false.
    var isRinging: Bool = true
    /// Zero point of the frame clock — pass the alarm's fire date so the
    /// animation (and audio started from the same moment) stay in sync.
    var epoch: Date = Date(timeIntervalSinceReferenceDate: 0)

    /// Matches PrayingFigureView / WatchPrayingFigureView.
    static let frameDuration: TimeInterval = 0.3
    static let frameCount = 4

    /// Frame index (0..3) at `date` on the frame clock starting at `epoch`.
    static func frameIndex(at date: Date, epoch: Date) -> Int {
        let ticks = Int(floor(date.timeIntervalSince(epoch) / frameDuration))
        return ((ticks % frameCount) + frameCount) % frameCount
    }

    private static let frameNames = [
        "bell_frame_1", "bell_frame_2", "bell_frame_3", "bell_frame_4",
    ]
    /// bell_frame_2 (index 1) is the at-rest pose.
    private static let restIndex = 1

    var body: some View {
        TimelineView(.periodic(from: epoch, by: Self.frameDuration)) { context in
            let frame = isRinging
                ? Self.frameIndex(at: context.date, epoch: epoch)
                : Self.restIndex
            Image(Self.frameNames[frame])
                .interpolation(.none)       // keeps pixel art crisp
                .resizable()
                .aspectRatio(0.5, contentMode: .fit)   // art is 1:2 (64×128)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Ringing") {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        AmenBellTowerView(epoch: .now)
            .frame(maxWidth: 200, maxHeight: 400)
    }
}

#Preview("Rest") {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        AmenBellTowerView(isRinging: false)
            .frame(maxWidth: 200, maxHeight: 400)
    }
}
