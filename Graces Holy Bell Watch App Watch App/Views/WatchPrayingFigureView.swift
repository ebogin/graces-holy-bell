import SwiftUI

/// Animated pixel-art praying figure for Apple Watch (smaller scale: 1.4×).
struct WatchPrayingFigureView: View {

    enum Pose { case idle, praying }

    let pose: Pose
    var scale: CGFloat = 1.4

    @State private var frameIndex = 0
    private let frameNames = ["pray_frame_1","pray_frame_2","pray_frame_3","pray_frame_4"]

    var body: some View {
        Image(pose == .praying ? frameNames[frameIndex] : "pray_frame_1")
            .interpolation(.none)
            .resizable()
            .frame(width: 50 * scale, height: 63 * scale)
            .blendMode(.multiply)
            .onChange(of: pose) { _, p in if p == .idle { frameIndex = 0 } }
            .task(id: pose) {
                guard pose == .praying else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(0.3))
                    frameIndex = (frameIndex + 1) % frameNames.count
                }
            }
    }
}
