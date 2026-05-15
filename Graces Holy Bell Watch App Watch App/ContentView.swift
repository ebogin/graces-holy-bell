import SwiftUI
import Combine

struct WatchContentView: View {

    let viewModel: WatchSessionViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @Namespace private var prayerFigureNS

    var body: some View {
        ZStack {
            Color.lcdBackground

            switch viewModel.route {
            case .firstLaunch:
                WatchFirstLaunchView(viewModel: viewModel, namespace: prayerFigureNS)
            case .active:
                WatchActiveSessionView(viewModel: viewModel, namespace: prayerFigureNS)
            case .log:
                WatchLogView(viewModel: viewModel)
            case .idle:
                WatchIdleClearedView(viewModel: viewModel)
            }
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onReceive(connectivityManager.$latestState) { state in
            if let state {
                withAnimation(.spring(duration: 0.4)) {
                    viewModel.apply(state)
                }
            }
        }
    }
}
