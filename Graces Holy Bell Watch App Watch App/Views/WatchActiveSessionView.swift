import SwiftUI
import WatchKit

/// Watch ACTIVE SESSION screen — translated from Figma node 238:53 (Watch Active Prayer v1.41).
/// Layout mirrors WatchFirstLaunchView so Core Content and Bottom Container elements
/// render in identical positions across both screens.
/// Native watchOS safe area provides the top system-time buffer — no .ignoresSafeArea needed.
struct WatchActiveSessionView: View {

    let viewModel: WatchSessionViewModel
    var namespace: Namespace.ID
    @State private var showStopConfirmation = false

    private var figureHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.width >= 200 ? 96 : 86
    }

    var body: some View {

        // Root — Figma: VStack, justify-between, px-[30px] → .padding(.horizontal, 14)
        VStack(spacing: 0) {

            // Core Content Stack — Figma: VStack, gap-[4px] → spacing: 2, pt-[5px] → .padding(.top, 2)
            VStack(spacing: 2) {

                // Title and Time + "SINCE LAST PRAYER"
                // WatchLiveTimerView already renders the timer AND "SINCE LAST PRAYER" internally,
                // so it covers Figma rows 2 and 3. Row 1 (app title) sits above it.
                // Figma: gap-[4px] → spacing: 2
                VStack(spacing: 2) {

                    // Row 1: App title — Figma: 18px, #5f7c4d, visible, fill width
                    Text("GRACE'S HOLY BELL")
                        .font(.pixelFont(8))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // Row 2 + "SINCE LAST PRAYER" — handled internally by WatchLiveTimerView
                    WatchLiveTimerView(viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                }

                // Transparent placeholder — Figma: h-[17px] → 8pt, holds vertical space
                Color.clear.frame(height: 8)

                // Animation figure — Figma: h-[192px] w-[142px]
                WatchPrayingFigureView(pose: .praying, height: figureHeight)
                    .matchedGeometryEffect(id: "prayFigure", in: namespace)
            }
            .padding(.top, 2)

            // Root justify-between spacer
            Spacer()

            // Bottom Container — Figma: VStack, justify-center, h-[116px] → 52pt
            VStack(spacing: 0) {

                // Slider row — Figma: py-[4px] → .padding(.vertical, 2)
                WatchPraySlider(label: "PRAY") {
                    viewModel.sendPray()
                }
                .padding(.vertical, 2)

                // Bottom Buttons — Stop centered, Log badge trailing
                // ZStack avoids rigid frame constraints that conflict with watchOS touch target sizing
                ZStack {
                    // Stop button — Figma: Stop Icon, centered
                    Button {
                        showStopConfirmation = true
                    } label: {
                        ZStack {
                            Octagon()
                                .fill(Color.lcdDark)
                                .frame(width: 24, height: 24)
                            Rectangle()
                                .fill(Color.lcdThumbText)
                                .frame(width: 11, height: 11)
                        }
                    }
                    .buttonStyle(.plain)

                    // Log badge — Figma: Watch Log Badge, trailing edge
                    HStack {
                        Spacer()
                        LogBadgeButton(count: viewModel.sortedEntries.count) {
                            viewModel.showingLog = true
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
        .confirmationDialog(
            "End session?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) { viewModel.sendStop() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Clock stops. No final prayer recorded.")
        }
    }
}
