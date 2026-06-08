import SwiftUI
import WatchKit

/// First-launch screen — shown when there are no prayer entries yet.
/// Translated from Figma node 239:96 (Watch Start - v1.41).
/// Native watchOS safe area provides the top system-time buffer — no .ignoresSafeArea needed.
struct WatchFirstLaunchView: View {

    let viewModel: WatchSessionViewModel
    var namespace: Namespace.ID

    @State private var blinkVisible = true

    private var figureHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.width >= 200 ? 96 : 86
    }

    var body: some View {

        // Root — Figma: VStack, justify-between, px-[30px] → .padding(.horizontal, 14)
        VStack(spacing: 0) {

            // Core Content Stack — Figma: VStack, gap-[4px] → spacing: 2
            VStack(spacing: 2) {

                // Title and Time — Figma: VStack, gap-[4px] → spacing: 2, h-[88px]
                // 3 rows: app title (opacity 0), main title (visible), "SINCE LAST PRAYER" (opacity 0)
                VStack(spacing: 2) {

                    // Row 1: single-line nav title placeholder — Figma: 18px, opacity 0, fill width
                    Text("GRACE'S HOLY BELL")
                        .font(.pixelFont(8))
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .opacity(0)

                    // Row 2: visible two-line title — Figma: 24px, #1b2b0b, fill width
                    Text("GRACE'S\nHOLY BELL")
                        .font(.pixelFont(11))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // Row 3: "SINCE LAST PRAYER" placeholder — Figma: 14px, opacity 0, fill width
                    Text("SINCE LAST PRAYER")
                        .font(.pixelFont(7))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .opacity(0)
                }

                // Transparent placeholder — Figma: h-[17px] → 8pt, holds vertical space
                Color.clear.frame(height: 8)

                // Animation figure — Figma: h-[192px] w-[142px]
                WatchPrayingFigureView(pose: .idle, height: figureHeight)
                    .matchedGeometryEffect(id: "prayFigure", in: namespace)
            }

            // Root justify-between spacer
            Spacer()

            // Bottom Container — Figma: VStack, justify-center, h-[116px] → 52pt
            VStack(spacing: 0) {

                // Slider row — Figma: py-[4px] → .padding(.vertical, 2)
                WatchPraySlider(label: "PRAY", labelPadLeft: false) {
                    viewModel.sendStart()
                }
                .padding(.vertical, 2)

                // Bottom label row — Figma: h-[61px] → 27pt, pb-[5px] → .padding(.bottom, 2)
                Text("SLIDE TO BEGIN")
                    .font(.pixelFont(7))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: 27)
                    .padding(.bottom, 2)
                    .opacity(blinkVisible ? 1 : 0)
                    .onAppear {
                        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                            blinkVisible.toggle()
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .padding(.top, 4) // Figma: pt-[8px] on Root → 4pt
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}
