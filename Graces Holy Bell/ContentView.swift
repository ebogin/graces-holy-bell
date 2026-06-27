//
//  ContentView.swift
//  Graces Holy Bell
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import SwiftData

/// Root view that routes between IDLE and ACTIVE screens based on the ViewModel's state.
///
/// This view is intentionally thin — it creates the ViewModel and delegates
/// all display and interaction to IdleView or ActiveSessionView.
struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SessionViewModel?
    @State private var amenAlarmSettings = AmenAlarmSettings()
    var connectivityManager: PhoneConnectivityManager?

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.appState {
                case .idle:
                    IdleView(viewModel: viewModel, amenAlarmSettings: amenAlarmSettings)
                case .active:
                    ActiveSessionView(viewModel: viewModel, amenAlarmSettings: amenAlarmSettings)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = SessionViewModel(modelContext: modelContext)
                vm.amenAlarmSettings = amenAlarmSettings
                // Wire up Watch connectivity: ViewModel notifies manager after each mutation
                if let connectivityManager {
                    connectivityManager.amenAlarmSettings = amenAlarmSettings
                    vm.onStateChanged = { [weak connectivityManager] in
                        connectivityManager?.sendStateToWatch()
                    }
                    connectivityManager.configure(with: vm)
                }
                // Settings changes apply immediately: reschedule the phone alarm
                // and push the new fire date (or nil) to the Watch.
                amenAlarmSettings.onChange = { [weak vm, weak connectivityManager] in
                    vm?.refreshAmenAlarm()
                    connectivityManager?.sendStateToWatch()
                }

                // Analytics (additive, no-op transport): resolve/persist the
                // canonical install_id, wire the service, and record launch.
                _ = InstallIDProvider(store: UserDefaultsInstallIDStore()).resolve()
                let analytics = AnalyticsService(
                    transport: NoOpAnalytics(),
                    stateStore: UserDefaultsAnalyticsStateStore(),
                    contextProvider: {
                        EventContext(
                            deviceSource: .phone,
                            alarmStatus: .from(
                                phoneEnabled: amenAlarmSettings.phoneEnabled,
                                watchEnabled: amenAlarmSettings.watchEnabled
                            ),
                            alarmDurationSeconds: amenAlarmSettings.duration.rawValue
                        )
                    }
                )
                vm.analytics = analytics
                analytics.recordLaunch(
                    currentSessionStart: vm.currentSession?.startedAt,
                    lastPrayerAt: vm.lastPrayerTimestamp,
                    prayersSoFar: vm.sortedEntries.count
                )

                viewModel = vm
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PrayerSession.self, PrayerEntry.self], inMemory: true)
}
