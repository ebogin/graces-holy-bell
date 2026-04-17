import SwiftUI

/// Pixel-art "slide to confirm" control for logging prayers (iPhone).
///
/// Styled as a Game Boy–style rectangular slider with a dark thumb that slides
/// along a green track. Requires an 85% drag to activate — prevents accidental taps.
/// Snaps back to start with a spring after every release.
///
/// Usage:
/// ```
/// PraySlider(label: "PRAY") { viewModel.logPrayer() }
/// PraySlider(label: "START PRAYER") { viewModel.startNewSession() }
/// ```
struct PraySlider: View {

    let label: String
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0

    private let thumbWidth: CGFloat  = 64
    private let trackHeight: CGFloat = 48
    private let cornerRadius: CGFloat = 8
    private let activationThreshold: CGFloat = 0.85

    private var maxOffset: CGFloat {
        max(trackWidth - thumbWidth - 8, 0)
    }

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

            // Inner green track fill
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .fill(Color.lcdSlider)
                .padding(4)
                .frame(height: trackHeight)

            // Center label (fades as thumb advances)
            Text(label)
                .font(.pixelFont(8))
                .foregroundStyle(Color.lcdThumbText)
                .frame(maxWidth: .infinity)
                .opacity(1.0 - min(progress * 1.5, 1.0))

            // Draggable pixel-art thumb
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .fill(Color.lcdDark)
                .frame(width: thumbWidth, height: trackHeight - 8)
                .overlay(
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.lcdThumbText)
                )
                .offset(x: dragOffset + 4)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = min(max(value.translation.width, 0), maxOffset)
                        }
                        .onEnded { _ in
                            if progress >= activationThreshold {
                                onComplete()
                            }
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = 0
                            }
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

#Preview {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        VStack(spacing: 24) {
            PraySlider(label: "START PRAYER") { }
            PraySlider(label: "PRAY") { }
        }
        .padding()
    }
}
