import SwiftUI

/// Pixel-art slide-to-confirm control sized for Apple Watch.
///
/// Rectangular dark thumb on a green track. 85% drag threshold.
struct WatchPraySlider: View {

    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0

    private let thumbWidth: CGFloat   = 32
    private let trackHeight: CGFloat  = 20
    private let cornerRadius: CGFloat = 3
    private let activationThreshold: CGFloat = 0.85

    private var maxOffset: CGFloat { max(trackWidth - thumbWidth - 4, 0) }
    private var progress: CGFloat {
        guard maxOffset > 0 else { return 0 }
        return min(dragOffset / maxOffset, 1.0)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Outer dark border
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.lcdDark)
                .frame(height: trackHeight)

            // Green track fill
            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .fill(Color.lcdSlider)
                .padding(2)
                .frame(height: trackHeight)

            // Center label
            Text("PRAY")
                .font(.pixelFont(6))
                .foregroundStyle(Color.lcdThumbText)
                .frame(maxWidth: .infinity)
                .opacity(1.0 - min(progress * 1.5, 1.0))

            // Thumb
            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .fill(Color.lcdDark)
                .frame(width: thumbWidth, height: trackHeight - 4)
                .overlay(
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.lcdThumbText)
                )
                .offset(x: dragOffset + 2)
                .gesture(
                    DragGesture()
                        .onChanged { v in dragOffset = min(max(v.translation.width, 0), maxOffset) }
                        .onEnded { _ in
                            if progress >= activationThreshold { onComplete() }
                            withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                        }
                )
        }
        .frame(height: trackHeight)
        .overlay(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { trackWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, w in trackWidth = w }
            }
        )
    }
}
