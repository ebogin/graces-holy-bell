import SwiftUI

/// Compact "slide to confirm" control for the Apple Watch.
///
/// Same concept as the iPhone PraySlider but sized for the smaller Watch screen.
/// Requires a deliberate drag (85% of track) to trigger — prevents accidental activation.
struct WatchPraySlider: View {

    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0

    private let thumbSize: CGFloat = 36
    private let trackHeight: CGFloat = 44
    private let activationThreshold: CGFloat = 0.85

    private var maxOffset: CGFloat {
        max(trackWidth - thumbSize - 6, 0)
    }

    private var progress: CGFloat {
        guard maxOffset > 0 else { return 0 }
        return min(dragOffset / maxOffset, 1.0)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            RoundedRectangle(cornerRadius: trackHeight / 2)
                .fill(.quaternary)
                .frame(height: trackHeight)

            // Progress fill
            RoundedRectangle(cornerRadius: trackHeight / 2)
                .fill(.blue.opacity(0.2))
                .frame(width: dragOffset + thumbSize + 6, height: trackHeight)

            // Center label
            Text("PRAY")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            // Draggable thumb
            Circle()
                .fill(.blue)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(
                    Image(systemName: "chevron.right.2")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                )
                .offset(x: dragOffset + 3)
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
                    .onChange(of: proxy.size.width) { _, newValue in
                        trackWidth = newValue
                    }
            }
        )
    }
}
