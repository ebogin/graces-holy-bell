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
    @State private var logExportSettings = LogExportSettings()
    /// Session log queued for the Notes share sheet. Presented from here (not
    /// ActiveSessionView) because ending the session flips the state to idle,
    /// which unmounts ActiveSessionView before its sheet could appear.
    @State private var notesExport: NotesExportPayload?
    // Analytics consent — applies the geo-gated default on first launch. Single
    // source of truth behind the Settings toggle and the EU opt-in banner.
    @State private var consent = AnalyticsConsent()
    // Retains the notification-tap delegate for the app's lifetime (analytics only).
    @State private var notificationForwarder: NotificationEventForwarder?
    var connectivityManager: PhoneConnectivityManager?
    /// Set by the App when the store failed to open/migrate and was recreated
    /// from scratch — reported to analytics once the service is built.
    var storeWasRecovered: Bool = false

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.appState {
                case .idle:
                    IdleView(
                        viewModel: viewModel,
                        amenAlarmSettings: amenAlarmSettings,
                        logExportSettings: logExportSettings,
                        consent: consent,
                        isWatchAvailable: viewModel.isWatchAvailable,
                        onForceSync: { connectivityManager?.forceSync() }
                    )
                case .active:
                    ActiveSessionView(
                        viewModel: viewModel,
                        amenAlarmSettings: amenAlarmSettings,
                        logExportSettings: logExportSettings,
                        consent: consent,
                        isWatchAvailable: viewModel.isWatchAvailable,
                        onForceSync: { connectivityManager?.forceSync() },
                        onExportLog: { text, prayerCount in
                            notesExport = NotesExportPayload(text: text, prayerCount: prayerCount)
                        }
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
        // Session-end "save to Notes" share sheet (setting-gated). The user
        // picks Notes and appends to their running prayer-log note.
        .sheet(item: $notesExport) { payload in
            ActivityShareSheet(text: payload.text) { completed in
                viewModel?.analytics?.recordSessionLogExported(
                    prayersInSession: payload.prayerCount,
                    completed: completed
                )
            }
        }
        .task {
            if viewModel == nil {
                #if DEBUG
                seedPrayerLogIfRequested(into: modelContext)
                #endif
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

                logExportSettings.onChange = { [weak analytics] enabled in
                    analytics?.recordNotesAutosaveSet(enabled: enabled)
                }

                // Forward Amen Alarm notification taps into analytics (additive;
                // only implements didReceive, so presentation behavior is unchanged).
                let forwarder = NotificationEventForwarder { [weak analytics] in
                    analytics?.recordAmenAlarmTapped()
                }
                UNUserNotificationCenter.current().delegate = forwarder
                notificationForwarder = forwarder

                if storeWasRecovered {
                    analytics.recordPersistenceError(stage: .migrationRecovery)
                }

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

    #if DEBUG
    /// App Store screenshot seeding. When the app is launched with the
    /// `--seed-prayer-log` argument, replace the store with three fixed prayers
    /// so the ACTIVE screen renders a realistic late-night log: the first prayer
    /// displays 11:15 PM, then 12:46 AM and 2:31 AM (gaps of 1h 31m / 1h 45m).
    /// The sequence is anchored to the *next* 11:15 PM, and the ACTIVE screen's
    /// clock is frozen at 5m 22s past the last prayer (via `ScreenshotClock`), so
    /// the "since last prayer" timer and last-row duration read a stable 00:05:22.
    /// Set the sim status bar to 2:36 AM to match. DEBUG-only — stripped from
    /// Release (App Store) builds.
    private func seedPrayerLogIfRequested(into context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("--seed-prayer-log") else { return }

        // Wipe any existing entries so reseeding is idempotent.
        if let existing = try? context.fetch(FetchDescriptor<PrayerEntry>()) {
            existing.forEach { context.delete($0) }
        }

        // First prayer at 11:15 PM local. Use the next occurrence of 23:15 so the
        // whole session sits just ahead of "now" and the live timer reads 00:00:00.
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 23
        components.minute = 15
        components.second = 0
        var firstPrayer = calendar.date(from: components) ?? now
        if firstPrayer <= now {
            firstPrayer = calendar.date(byAdding: .day, value: 1, to: firstPrayer) ?? firstPrayer
        }
        let timestamps: [Date] = [
            firstPrayer,                                        // #1  11:15 PM
            firstPrayer.addingTimeInterval(1 * 3600 + 31 * 60), // #2  12:46 AM (gap 1h 31m)
            firstPrayer.addingTimeInterval(3 * 3600 + 16 * 60)  // #3  2:31 AM  (gap 1h 45m)
        ]
        for timestamp in timestamps {
            context.insert(PrayerEntry(id: UUID(), timestamp: timestamp, origin: PrayerEvent.Origin.phone.rawValue))
        }
        try? context.save()

        // Ensure all three seeded prayers are active (matches
        // SessionViewModel.lastClearedAtKey — keep in sync if that changes).
        UserDefaults.standard.removeObject(forKey: "prayer.lastClearedAt")

        // Freeze the ACTIVE screen at 5m 22s past the last prayer so the timer
        // and last-row duration read an exact, stable 00:05:22 / 5m 22s.
        ScreenshotClock.fixedNow = timestamps[2].addingTimeInterval(5 * 60 + 22)
    }
    #endif
}

/// Composed session log waiting for the Notes share sheet.
private struct NotesExportPayload: Identifiable {
    let id = UUID()
    let text: String
    let prayerCount: Int
}

#if DEBUG
/// Screenshot-only clock override. When `fixedNow` is set (by the prayer-log
/// seed), the ACTIVE screen renders against it instead of the live clock so
/// timers show an exact, non-ticking value for a still capture.
enum ScreenshotClock {
    static var fixedNow: Date?
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: [PrayerSession.self, PrayerEntry.self], inMemory: true)
}
