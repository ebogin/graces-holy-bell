import SwiftUI
import WatchKit

/// Log screen — shown during an active session when the user taps LOG.
/// Translated from Figma node 240:143 (Watch Log v1.41).
/// Shares the same Root / Core Content Stack / Bottom Container layout as WatchActiveSessionView
/// so Title, timer, and "SINCE LAST PRAYER" render in identical positions on both screens.
/// The animation figure is replaced by the Scrolling Container (prayer log table).
/// Timer keeps ticking; only the log scrolls (via digital crown).
struct WatchLogView: View {

    let viewModel: WatchSessionViewModel

    // Matches figureHeight on other screens so the scrolling container
    // occupies the exact same vertical slot as the animation.
    private var containerHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.width >= 200 ? 96 : 86
    }

    var body: some View {

        // Root — Figma: VStack, justify-between, px-[30px] → .padding(.horizontal, 14)
        VStack(spacing: 0) {

            // Core Content Stack — Figma: VStack, gap-[4px] → spacing: 2
            VStack(spacing: 2) {

                // Title and Time — Figma: VStack, gap-[4px] → spacing: 2, pt-[8px] → .padding(.top, 4)
                // 3 rows: app title, timer, "SINCE LAST PRAYER". WatchLiveTimerView covers rows 2+3.
                VStack(spacing: 2) {

                    // Row 1: App title — Figma: 18px, #5f7c4d, visible, fill width
                    Text("GRACE'S HOLY BELL")
                        .font(.pixelFont(8))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // Row 2 + Row 3 — timer + "SINCE LAST PRAYER" via WatchLiveTimerView
                    WatchLiveTimerView(viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4) // Figma: pt-[8px] on Title and Time → 4pt

                // Transparent placeholder — Figma: h-[17px] → 8pt, holds vertical space
                Color.clear.frame(height: 8)

                // Scrolling Container — Figma: h-[192px] → containerHeight, replaces animation figure
                // bg: #c0d0a8 ≈ surfaceInner, border-3 #5f7c4d → stroke textSecondary 1.5pt
                // radius-10 → 5pt, px-[16px] → 7pt, py-[9px] → 4pt (applied to scroll content)
                ScrollView {
                    WatchPrayerLogView(viewModel: viewModel)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                }
                .focusable()
                .frame(maxWidth: .infinity)
                .frame(height: containerHeight)
                .background(DesignSystem.Colors.surfaceInner)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(DesignSystem.Colors.textSecondary, lineWidth: 1.5)
                )
            }

            // Root justify-between spacer
            Spacer()

            // Bottom Container — Figma: VStack, justify-center, h-[116px] → 52pt
            VStack(spacing: 0) {

                // Slider row — hidden but holds space, Figma: py-[4px] → .padding(.vertical, 2)
                WatchPraySlider(label: "PRAY", labelPadLeft: false) {
                    // no-op
                }
                .padding(.vertical, 2)
                .opacity(0)
                .disabled(true)
                .allowsHitTesting(false)

                // Bottom buttons — Back button on left, right side empty
                ZStack {
                    HStack {
                        Spacer()
                        // Back/return button — right position
                        BackButton {
                            viewModel.showingLog = false
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}
