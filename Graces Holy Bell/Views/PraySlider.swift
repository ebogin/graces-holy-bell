import SwiftUI

/// A "slide to confirm" control for logging prayers.
///
/// The user must drag the thumb at least 85% of the track width to trigger the action.
/// A simple tap does nothing — the DragGesture requires actual movement.
/// The thumb always snaps back to the start after release, making it immediately reusable.
///
/// Usage:
/// ```
/// PraySlider {
///     viewModel.logPrayer()
/// }
/// ```
struct PraySlider: View {

    /// Called when the user successfully completes the slide.
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0

    private let thumbSize: CGFloat = 56
    private let trackHeight: CGFloat = 64
    private let activationThreshold: CGFloat = 0.85

    private var maxOffset: CGFloat {
        max(trackWidth - thumbSize - 8, 0)
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

            // Progress fill (grows as thumb is dragged)
            RoundedRectangle(cornerRadius: trackHeight / 2)
                .fill(.blue.opacity(0.2))
                .frame(width: dragOffset + thumbSize + 8, height: trackHeight)

            // Center label
            Text("PRAY")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            // Draggable thumb
            Circle()
                .fill(.blue)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(
                    Image(systemName: "chevron.right.2")
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
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
                            // Always snap back to start
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

#Preview {
    PraySlider {
        print("Prayer logged!")
    }
    .padding()
}
