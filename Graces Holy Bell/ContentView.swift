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
                    IdleView(
                        viewModel: viewModel,
                        amenAlarmSettings: amenAlarmSettings,
                        consent: consent,
                        isWatchAvailable: viewModel.isWatchAvailable,
                        onForceSync: { connectivityManager?.forceSync() }
                    )
                case .active:
                    ActiveSessionView(
                        viewModel: viewModel,
                        amenAlarmSettings: amenAlarmSettings,
                        consent: consent,
                        isWatchAvailable: viewModel.isWatchAvailable,
                        onForceSync: { connectivityManager?.forceSync() }
                    )
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
                        connectivityManager?.sendSnapshotToWatch()
                    }
                    connectivityManager.configure(with: vm)
                }
                // Analytics: resolve/persist the canonical install_id.
                let installID = InstallIDProvider(store: UserDefaultsInstallIDStore()).resolve()

                // Real PostHog transport when a key is present (Secrets.plist),
                // otherwise the no-op transport (fresh checkout / no secrets).
                let backend: Analytics = PostHogTransport.make(installID: installID) ?? NoOpAnalytics()

                // Consent gate: transmission only flows when granted. `consent`
                // already applied the geo-gated default on first launch.
                let transport = ConsentGatingAnalytics(wrapping: backend) { [consent] in
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
                    connectivityManager?.sendSnapshotToWatch()
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
                    currentSessionStart: vm.sessionStartedAt,
                    lastPrayerAt: vm.lastPrayerTimestamp,
                    prayersSoFar: vm.sortedEntries.count
                )

                viewModel = vm
            }
        }
        // On every foreground, proactively reconcile with the Watch so opening
        // the app shows fresh state instead of waiting for opportunistic delivery.
        // Analytics app_opened is still only the background→active reopen
        // (launch open is recorded by recordLaunch).
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                connectivityManager?.sendSnapshotToWatch()
                if oldPhase == .background {
                    viewModel?.analytics?.recordAppOpened()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PrayerSession.self, PrayerEntry.self], inMemory: true)
}
