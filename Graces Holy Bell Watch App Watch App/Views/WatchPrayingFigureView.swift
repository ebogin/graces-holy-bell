import SwiftUI

/// Animated pixel-art praying figure for Apple Watch.
/// Aspect ratio of the cropped artwork: 563:711.
struct WatchPrayingFigureView: View {

    enum Pose { case idle, praying }

    let pose: Pose
    /// Height in points; width is derived from the 563:711 aspect ratio.
    var height: CGFloat = 60

    private var width: CGFloat { height * (563.0 / 711.0) }

    @State private var frameIndex = 0
    private let frameNames = ["pray_frame_1","pray_frame_2","pray_frame_3","pray_frame_4"]

    var body: some View {
        Image(pose == .praying ? frameNames[frameIndex] : "pray_frame_1")
            .interpolation(.none)
            .resizable()
            .aspectRatio(563.0 / 711.0, contentMode: .fit)
            .frame(width: width, height: height)
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
