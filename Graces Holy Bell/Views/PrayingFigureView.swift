import SwiftUI

/// Animated pixel-art praying figure.
///
/// Uses the 4 sprite frames exported from the Figma design.
/// - `idle` → static frame 1
/// - `praying` → cycles frames 1–4 every 300 ms (used during active session)
///
/// The sprite has a light background in the source PNG. We use `.blendMode(.multiply)`
/// so the pale pixels multiply with the LCD green background and disappear,
/// leaving only the dark pixel-art visible.
struct PrayingFigureView: View {

    enum Pose {
        case idle
        case praying
    }

    let pose: Pose
    /// Points = base 50pt × scale. iPhone idle/active: 2.6. Watch: 1.4.
    let scale: CGFloat

    @State private var frameIndex: Int = 0
    private let frameNames = ["pray_frame_1", "pray_frame_2", "pray_frame_3", "pray_frame_4"]
    private let animationInterval: TimeInterval = 0.3

    var currentFrameName: String {
        pose == .praying ? frameNames[frameIndex] : "pray_frame_1"
    }

    var body: some View {
        Image(currentFrameName)
            .interpolation(.none)           // keeps pixel art crisp
            .resizable()
            .frame(width: 50 * scale, height: 63 * scale)
            .blendMode(.multiply)           // erases light background against the LCD green
            .onAppear {
                frameIndex = 0
            }
            .onChange(of: pose) { _, newPose in
                if newPose == .idle { frameIndex = 0 }
            }
            .task(id: pose) {
                guard pose == .praying else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(animationInterval))
                    frameIndex = (frameIndex + 1) % frameNames.count
                }
            }
    }
}

#Preview("Idle") {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        PrayingFigureView(pose: .idle, scale: 2.6)
    }
}

#Preview("Praying") {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        PrayingFigureView(pose: .praying, scale: 2.6)
    }
}
