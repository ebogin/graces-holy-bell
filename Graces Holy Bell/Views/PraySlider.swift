import SwiftUI

/// Pixel-art "slide to confirm" control for logging prayers (iPhone).
///
/// Styled as a Game Boy–style rectangular slider with a dark thumb that slides
/// along a green track. Requires an 85% drag to activate — prevents accidental taps.
/// Snaps back to start with a spring after every release.
///
/// When the Amen Alarm is on, pass `alarmProgress` (elapsed / alarm interval):
/// the track doubles as a progress bar filling left-to-right in a deeper green.
/// At >= 1.0 the bar blinks inverted colors with "AMEN!" in place of the label,
/// until the next slide resets the interval.
///
/// Usage:
/// ```
/// PraySlider(label: "PRAY") { viewModel.logPrayer() }
/// PraySlider(label: "PRAY", alarmProgress: 0.4) { viewModel.logPrayer() }
/// ```
struct PraySlider: View {

    let label: String
    /// Amen Alarm progress since last prayer (0...1+), or nil when the alarm is off.
    var alarmProgress: Double? = nil
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0
    @State private var blinkInverted = false
    @State private var blinkTimer: Timer?

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

    /// The Amen Alarm interval has elapsed — blink AMEN! until the next slide.
    private var isAlarmFired: Bool {
        (alarmProgress ?? 0) >= 1.0
    }

    private var trackFillColor: Color {
        guard isAlarmFired else { return .lcdSlider }
        return blinkInverted ? .lcdThumbText : .lcdProgress
    }

    private var labelColor: Color {
        guard isAlarmFired else { return .lcdThumbText }
        return blinkInverted ? .lcdDark : .lcdThumbText
    }

    /// Thumb stays visible during the flash: alternates regular dark with the
    /// deep progress green (in sync with the track blink).
    private var thumbFillColor: Color {
        guard isAlarmFired else { return .lcdDark }
        return blinkInverted ? .lcdProgress : .lcdDark
    }

    var body: some View {
        ZStack(alignment: .leading) {

            // Outer dark border
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.lcdDark)
                .frame(height: trackHeight)

            // Inner green track fill + Amen Alarm progress overlay
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .fill(trackFillColor)
                .overlay(alignment: .leading) {
                    if let alarmProgress, !isAlarmFired {
                        Rectangle()
                            .fill(Color.lcdProgress)
                            .frame(width: max(trackWidth - 8, 0) * min(alarmProgress, 1.0))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 2))
                .padding(4)
                .frame(height: trackHeight)

            // Center label (fades as thumb advances)
            Text(isAlarmFired ? "AMEN!" : label)
                .font(.pixelFont(12))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity)
                .opacity(1.0 - min(progress * 1.5, 1.0))

            // Draggable pixel-art thumb (inverts in sync with the AMEN! blink)
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .fill(thumbFillColor)
                .frame(width: thumbWidth, height: trackHeight - 8)
                .overlay(
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
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
        .accessibilityIdentifier("pray-slider")
        .overlay(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { trackWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, w in trackWidth = w }
            }
        )
        .onAppear { if isAlarmFired { startBlinking() } }
        .onDisappear { stopBlinking() }
        .onChange(of: isAlarmFired) { _, fired in
            fired ? startBlinking() : stopBlinking()
        }
        // Haptic pulse at the fire moment, then on every blink toggle for the
        // duration of the flash (the notification only vibrates once, and only
        // when the app is backgrounded).
        .sensoryFeedback(trigger: isAlarmFired) { _, fired in
            fired ? .impact(weight: .heavy) : nil
        }
        .sensoryFeedback(trigger: blinkInverted) { _, _ in
            isAlarmFired ? .impact(weight: .heavy) : nil
        }
    }

    private func startBlinking() {
        guard blinkTimer == nil else { return }
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            blinkInverted.toggle()
        }
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        blinkInverted = false
    }
}

#Preview {
    ZStack {
        Color.lcdBackground.ignoresSafeArea()
        VStack(spacing: 24) {
            PraySlider(label: "START PRAYER") { }
            PraySlider(label: "PRAY") { }
            PraySlider(label: "PRAY", alarmProgress: 0.6) { }
            PraySlider(label: "PRAY", alarmProgress: 1.0) { }
        }
        .padding()
    }
}
