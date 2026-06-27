//
//  ContentView.swift
//  Graces Holy Bell
//
//  Created by Eric Bogin on 3/2/26.
//

import SwiftUI
import SwiftData
import UserNotifications

/// Root view that routes between IDLE and ACTIVE screens based on the ViewModel's state.
///
/// This view is intentionally thin — it creates the ViewModel and delegates
/// all display and interaction to IdleView or ActiveSessionView.
struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: SessionViewModel?
    @State private var amenAlarmSettings = AmenAlarmSettings()
    // Analytics consent — applies the geo-gated default on first launch. Single
    // source of truth behind the Settings toggle and the EU opt-in banner.
    @State private var consent = AnalyticsConsent()
    // Retains the notification-tap delegate for the app's lifetime (analytics only).
    @State private var notificationForwarder: NotificationEventForwarder?
    var connectivityManager: PhoneConnectivityManager?

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.appState {
                case .idle:
                    IdleView(viewModel: viewModel, amenAlarmSettings: amenAlarmSettings, consent: consent)
                case .active:
                    ActiveSessionView(viewModel: viewModel, amenAlarmSettings: amenAlarmSettings, consent: consent)
                }
            } else {
                ProgressView()
            }
        }
        // First-launch EU/EEA/UK opt-in (only while consent is pending).
        .fullScreenCover(isPresented: Binding(
            get: { consent.needsConsentDecision },
            set: { _ in }
        )) {
            AnalyticsConsentBanner(consent: consent)
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
                // Analytics (additive, no-op transport): resolve/persist the
                // canonical install_id and wire the service.
                _ = InstallIDProvider(store: UserDefaultsInstallIDStore()).resolve()

                // Consent gate: transmission only flows when granted. Wraps the
                // no-op today and the real PostHog transport later. `consent`
                // already applied the geo-gated default on first launch.
                let transport = ConsentGatingAnalytics(wrapping: NoOpAnalytics()) { [consent] in
                    consent.isGranted
                }

                let analytics = AnalyticsService(
                    transport: transport,
                    stateStore: UserDefaultsAnalyticsStateStore(),
                    contextProvider: { [consent] in
                        EventContext(
                            deviceSource: .phone,
                            alarmStatus: .from(
                                phoneEnabled: amenAlarmSettings.phoneEnabled,
                                watchEnabled: amenAlarmSettings.watchEnabled
                            ),
                            alarmDurationSeconds: amenAlarmSettings.duration.rawValue,
                            consentState: consent.state
                        )
                    }
                )
                vm.analytics = analytics

                // Settings changes apply immediately: reschedule the phone alarm
                // and push the new fire date (or nil) to the Watch.
                amenAlarmSettings.onChange = { [weak vm, weak connectivityManager, weak analytics] in
                    vm?.refreshAmenAlarm()
                    connectivityManager?.sendStateToWatch()
                    analytics?.recordAmenAlarmSet() // additive
                }

                // Forward Amen Alarm notification taps into analytics (additive;
                // only implements didReceive, so presentation behavior is unchanged).
                let forwarder = NotificationEventForwarder { [weak analytics] in
                    analytics?.recordAmenAlarmTapped()
                }
                UNUserNotificationCenter.current().delegate = forwarder
                notificationForwarder = forwarder

                analytics.recordLaunch(
                    currentSessionStart: vm.currentSession?.startedAt,
                    lastPrayerAt: vm.lastPrayerTimestamp,
                    prayersSoFar: vm.sortedEntries.count
                )

                viewModel = vm
            }
        }
        // Analytics (additive): record app_opened on return to the foreground.
        // The launch open is recorded by recordLaunch; this catches reopens.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase == .active {
                viewModel?.analytics?.recordAppOpened()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PrayerSession.self, PrayerEntry.self], inMemory: true)
}
