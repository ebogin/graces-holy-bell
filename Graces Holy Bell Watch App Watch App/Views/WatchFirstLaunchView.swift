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
                .font(.pixelFont(11))
                .foregroundStyle(Color.lcdDark)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()

            WatchPrayingFigureView(pose: .idle, height: figureHeight)
                .matchedGeometryEffect(id: "prayFigure", in: namespace)

            Spacer()

            Text("SLIDE TO BEGIN")
                .font(.pixelFont(7))
                .foregroundStyle(Color.lcdMid)
                .padding(.bottom, 4)

            WatchPraySlider(label: "START PRAYING", labelPadLeft: true) {
                viewModel.sendStart()
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
