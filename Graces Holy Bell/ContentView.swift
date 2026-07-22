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
    @State private var advancedSettings = AdvancedSettings()
    @State private var liveActivitySettings = LiveActivitySettings()
    @State private var liveActivityController = PrayerLiveActivityController()
    @State private var remoteConfig = RemoteConfig()
    // Analytics consent — applies the geo-gated default on first launch. Single
    // source of truth behind the Settings toggle and the EU opt-in banner.
    @State private var consent = AnalyticsConsent()
    // Transport seam AnalyticsService is built against; starts wrapping
    // NoOpAnalytics and is swapped to the real PostHog transport in place,
    // once consent allows it (see ConsentActivation below). Never rebuilt.
    @State private var analyticsTransport = SwappableAnalytics(initial: NoOpAnalytics())
    // One-shot latch: builds and activates the real transport the first time
    // consent is seen as `.granted` — either synchronously at launch (non-EU
    // users, who start `.granted` and never fire `onChange`) or later via
    // `.onChange(of: consent.state)` (EU users tapping Allow).
    @State private var analyticsActivation = ConsentActivation()
    var connectivityManager: PhoneConnectivityManager?
    /// Notification-tap router, created by the App during launch (so cold-start
    /// taps are caught). ContentView only wires its callback. Defaulted so
    /// previews don't need to construct one.
    var notificationForwarder: NotificationEventForwarder? = nil
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
                        advancedSettings: advancedSettings,
                        liveActivitySettings: liveActivitySettings,
                        consent: consent,
                        remoteConfig: remoteConfig,
                        isWatchAvailable: viewModel.isWatchAvailable,
                        onForceSync: { connectivityManager?.forceSync() }
                    )
                case .active:
                    ActiveSessionView(
                        viewModel: viewModel,
                        amenAlarmSettings: amenAlarmSettings,
                        advancedSettings: advancedSettings,
                        liveActivitySettings: liveActivitySettings,
                        consent: consent,
                        remoteConfig: remoteConfig,
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
        // Remote welcome-message content: fetched in the background, throttled
        // internally by RemoteConfig — never blocks the idle screen's render.
        // Skipped entirely while FeatureFlags.welcomeMessageEnabled is off (no
        // network call), so IdleView falls back to the bundled default text.
        .task {
            if FeatureFlags.welcomeMessageEnabled || FeatureFlags.prayerActionsEnabled {
                await remoteConfig.refresh()
            }
        }
        .task {
            if viewModel == nil {
                #if DEBUG
                seedPrayerLogIfRequested(into: modelContext)
                #endif
                let vm = SessionViewModel(modelContext: modelContext)
                vm.amenAlarmSettings = amenAlarmSettings
                // Wire up Watch connectivity and the Live Activity: the ViewModel
                // notifies after each mutation (prayer, clear, Watch merge).
                if let connectivityManager {
                    connectivityManager.amenAlarmSettings = amenAlarmSettings
                    connectivityManager.configure(with: vm)
                }
                vm.onStateChanged = { [weak connectivityManager, weak vm, liveActivityController, liveActivitySettings] in
                    connectivityManager?.sendSnapshotToWatch()
                    if let vm {
                        liveActivityController.sync(with: vm, enabled: liveActivitySettings.enabled)
                    }
                }
                // Reconcile any activity left over from a previous run.
                liveActivityController.sync(with: vm, enabled: liveActivitySettings.enabled)
                // Toggling the setting starts/ends the activity immediately.
                liveActivitySettings.onChange = { [weak vm, liveActivityController, liveActivitySettings] in
                    guard let vm else { return }
                    liveActivityController.sync(with: vm, enabled: liveActivitySettings.enabled)
                }
                // Analytics: resolve/persist the canonical install_id.
                let installID = InstallIDProvider(store: UserDefaultsInstallIDStore()).resolve()

                // Consent gate: transmission only flows when granted. `consent`
                // already applied the geo-gated default on first launch. Wraps
                // `analyticsTransport`, which starts as a no-op and is swapped
                // to the real PostHog transport below, in place, once consent
                // allows it — so `setup()`'s network call never happens before
                // consent is granted.
                let transport = ConsentGatingAnalytics(wrapping: analyticsTransport) { [consent] in
                    consent.isGranted
                }

                // Covers users who start `.granted` (non-EU default) — for them
                // `.onChange(of: consent.state)` below never fires, so this
                // synchronous check is the only activation they get. Must run
                // before `recordLaunch` so their launch event actually reaches
                // PostHog. EU users who grant later are covered by `onChange`.
                analyticsActivation.activateIfGranted(consent.state, swappable: analyticsTransport) {
                    PostHogTransport.make(installID: installID)
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

                advancedSettings.onChange = { [weak analytics] enabled in
                    analytics?.recordPrayerLogEditingSet(enabled: enabled)
                }

                // Amen Alarm notification taps: record analytics and open the
                // AMEN takeover (re-anchored so the bell rings a full window).
                // The forwarder was installed as the center's delegate during
                // app launch; a cold-start tap was buffered and flushes here.
                // With the takeover off there is nothing to open, so the tap
                // stays analytics-only — re-anchoring is what made the bell
                // tower vanish and immediately re-present on the first tap.
                notificationForwarder?.onAmenAlarmTapped = { [weak analytics, weak vm] in
                    analytics?.recordAmenAlarmTapped()
                    if FeatureFlags.amenTakeoverEnabled {
                        vm?.amenNotificationTappedAt = Date()
                    }
                }

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
        // Covers EU users who answer the opt-in banner after launch (non-EU
        // users are already covered by the synchronous check in the setup
        // block above, since `.granted` is their starting state and this
        // never fires for them). Also hardens revocation: `ConsentGatingAnalytics`
        // already drops events once denied, but opting the SDK itself out/in
        // additionally silences/restores its own internal traffic for users
        // who grant then later revoke.
        .onChange(of: consent.state) { _, newState in
            switch newState {
            case .granted:
                PostHogTransport.optIn()
                let installID = InstallIDProvider(store: UserDefaultsInstallIDStore()).resolve()
                analyticsActivation.activateIfGranted(newState, swappable: analyticsTransport) {
                    PostHogTransport.make(installID: installID)
                }
            case .denied:
                PostHogTransport.optOut()
            case .pending:
                break
            }
        }
        // On every foreground, proactively reconcile with the Watch so opening
        // the app shows fresh state instead of waiting for opportunistic delivery.
        // Analytics app_opened is still only the background→active reopen
        // (launch open is recorded by recordLaunch).
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                if FeatureFlags.welcomeMessageEnabled || FeatureFlags.prayerActionsEnabled {
                    Task { await remoteConfig.refresh() }
                }
                connectivityManager?.sendSnapshotToWatch()
                // Catch up the Live Activity — a start attempted while
                // backgrounded (e.g. a Watch merge) is rejected by the system.
                if let viewModel {
                    liveActivityController.sync(with: viewModel, enabled: liveActivitySettings.enabled)
                }
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
