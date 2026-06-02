import SwiftUI
import WatchKit

/// First-launch screen — shown when there are no prayer entries yet.
struct WatchFirstLaunchView: View {

    let viewModel: WatchSessionViewModel
    var namespace: Namespace.ID

    private var figureHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.width >= 200 ? 96 : 86
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("GRACE'S\nHOLY BELL")
                .font(.pixelFont(8))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Text("GRACE'S\nHOLY BELL")
                    .font(.pixelFont(11))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                WatchPrayingFigureView(pose: .idle, height: figureHeight)
                    .matchedGeometryEffect(id: "prayFigure", in: namespace)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            WatchPraySlider(label: "PRAY", labelPadLeft: false) {
                viewModel.sendStart()
            }

            Text("SLIDE TO BEGIN")
                .font(.pixelFont(7))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}
