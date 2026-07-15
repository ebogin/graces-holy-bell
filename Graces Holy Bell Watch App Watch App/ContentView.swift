import SwiftUI
import Combine

struct WatchContentView: View {

    let viewModel: WatchSessionViewModel
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @Environment(\.scenePhase) private var scenePhase
    /// Remotely-configurable per-prayer action manifest (see ANIMATIONS.md).
    /// Fetched directly by the Watch so figure actions update without a build.
    @State private var animationConfig = WatchAnimationConfigStore()

    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.route {
                case .firstLaunch:
                    WatchFirstLaunchView(viewModel: viewModel)
                        .transition(.opacity)
                case .active:
                    WatchActiveSessionView(
                        viewModel: viewModel,
                        animations: animationConfig.currentPrayerActions
                    )
                    .transition(.opacity)
                case .log:
                    WatchLogView(viewModel: viewModel)
                        .transition(.opacity)
                case .share:
                    WatchShareView(viewModel: viewModel)
                        .transition(.opacity)
                }
            }
            .animation(.spring(duration: 0.4), value: viewModel.route)
            .containerBackground(Color.lcdBackground, for: .navigation)
            // The navigation bar is hidden so screens can use the full height.
            // The system clock still draws top-right; each screen reserves
            // DesignSystem.Metrics.clockClearance at the top to stay clear of it.
            .toolbar(.hidden, for: .navigationBar)
        }
        .persistentSystemOverlays(.hidden)
        .onReceive(connectivityManager.$latestSnapshot) { snapshot in
            if let snapshot {
                viewModel.applySnapshot(snapshot)
            }
        }
        // Fetch the remote action manifest on launch (throttled internally;
        // falls back to the bundled default until/if it lands). Gated with the
        // phone via the shared FeatureFlags.prayerActionsEnabled.
        .task {
            if FeatureFlags.prayerActionsEnabled {
                await animationConfig.refresh()
            }
        }
        // Reconcile with the phone on every foreground so opening the Watch app
        // shows fresh state instead of waiting for opportunistic delivery.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.syncNow()
                if FeatureFlags.prayerActionsEnabled {
                    Task { await animationConfig.refresh() }
                }
            }
        }
    }
}
