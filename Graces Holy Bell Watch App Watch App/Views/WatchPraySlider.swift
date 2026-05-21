import SwiftUI
import WatchKit

/// Pixel-art slide-to-confirm control sized for Apple Watch.
///
/// Rectangular dark thumb on a green track. 85% drag threshold.
struct WatchPraySlider: View {

    var label: String = "PRAY"
    var labelPadLeft: Bool = false
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0
    // Debounce flag: blocks re-activation for the duration of the snap-back animation.
    // Guards against the watchOS edge case where the NavigationStack gesture recogniser
    // hands off to onEnded with stale state, triggering a spurious second fire.
    @State private var isCompleting = false

    private let thumbWidth: CGFloat   = 38
    private let trackHeight: CGFloat  = 26
    private let cornerRadius: CGFloat = 3
    private let activationThreshold: CGFloat = 0.85

    private var maxOffset: CGFloat { max(trackWidth - thumbWidth - 4, 0) }
    private var progress: CGFloat {
        guard maxOffset > 0 else { return 0 }
        return min(dragOffset / maxOffset, 1.0)
    }

    // MARK: - Body

    var body: some View {
        // Uncomment during debugging to print which state/binding triggered re-renders:
        // let _ = Self._printChanges()
        if ProcessInfo.processInfo.environment["UI_TESTING"] == "1" {
            // In XCUITest, SwiftUI DragGesture isn't reliably synthesisable on watchOS.
            // Replace with TapGesture so the stress test can drive the full state path
            // (optimistic update → sendPray → badge count) deterministically.
            sliderTrack
                .onTapGesture { fire() }
        } else {
            sliderTrack
                .gesture(
                    DragGesture()
                        .onChanged { v in dragOffset = min(max(v.translation.width, 0), maxOffset) }
                        .onEnded { _ in
                            if !isCompleting && progress >= activationThreshold {
                                fire()
                            }
                            withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                        }
                )
        }
    }

    // MARK: - Helpers

    private var sliderTrack: some View {
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

            // Label — either centered in full track or offset past thumb
            if labelPadLeft {
                Text(label)
                    .font(.pixelFont(8))
                    .foregroundStyle(Color.lcdThumbText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.leading, thumbWidth + 4)
                    .opacity(1.0 - min(progress * 1.5, 1.0))
            } else {
                Text(label)
                    .font(.pixelFont(10))
                    .foregroundStyle(Color.lcdThumbText)
                    .frame(maxWidth: .infinity)
                    .opacity(1.0 - min(progress * 1.5, 1.0))
            }

            // Thumb
            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .fill(Color.lcdDark)
                .frame(width: thumbWidth, height: trackHeight - 4)
                .overlay(
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.lcdThumbText)
                )
                .offset(x: dragOffset + 2)
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

    /// Fires the completion callback with the debounce guard and success haptic.
    private func fire() {
        guard !isCompleting else { return }
        isCompleting = true
        WKInterfaceDevice.current().play(.success)
        onComplete()
        // Reset guard after snap-back animation completes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isCompleting = false
        }
    }
}
