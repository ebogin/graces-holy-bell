import Foundation
import WatchConnectivity
import Combine
import UserNotifications

/// Watch-side WatchConnectivity manager.
///
/// Responsibilities:
/// - Sends user actions (PRAY, STOP, START) to the iPhone for processing.
/// - Receives state updates from the iPhone and feeds them to the WatchSessionViewModel.
///
/// Uses `sendMessage` when the iPhone is reachable (instant delivery),
/// falls back to `transferUserInfo` when disconnected (queued, guaranteed delivery).
///
/// NOT isolated to @MainActor — WCSession requires its delegate callbacks
/// on a background serial queue. State updates are dispatched to the main thread explicitly.
final class WatchConnectivityManager: NSObject, ObservableObject {

    /// The latest state received from the iPhone.
    @Published var latestState: SyncedSessionState?

    /// Whether the iPhone is currently reachable for immediate communication.
    @Published var isReachable = false

    /// Whether the session has successfully activated.
    @Published var isActivated = false

    private let session: WCSession

    private static let alarmNotificationID = "watchAmenAlarm"

    override init() {
        self.session = WCSession.default
        super.init()
        session.delegate = self
        session.activate()
    }

    // MARK: - Watch Amen Alarm Notifications

    /// Schedules (or replaces) a local haptic-only notification on the watch
    /// for the given fire date. Requests permission first if needed.
    private func scheduleWatchAlarm(fireDate: Date) {
        guard fireDate > .now else { return }

        let center = UNUserNotificationCenter.current()

        Task {
            // Request permission if not yet determined
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                try? await center.requestAuthorization(options: [.alert, .sound])
            }

            // Cancel any existing alarm then schedule fresh
            center.removePendingNotificationRequests(withIdentifiers: [Self.alarmNotificationID])

            let content = UNMutableNotificationContent()
            content.title = "🔔 Amen"
            // No sound — watch delivers a haptic via the system notification haptic
            content.sound = nil

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.alarmNotificationID,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Cancels any pending watch Amen Alarm notification.
    private func cancelWatchAlarm() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.alarmNotificationID])
    }

    /// Sends an action to the iPhone.
    ///
    /// Tries `sendMessage` first (instant). If iPhone is not reachable,
    /// falls back to `transferUserInfo` (queued, guaranteed delivery on reconnect).
    ///
    /// Each payload carries a unique id: `sendMessage` can fail on the *reply*
    /// after the iPhone already processed the action, so the fallback resend
    /// would otherwise log a duplicate PRAY. The iPhone de-dupes by id.
    func sendAction(_ action: String) {
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = ["action": action, "id": UUID().uuidString]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] reply in
                // iPhone sent back updated state as the reply — apply it immediately
                if let state = SyncedSessionState.fromDictionary(reply) {
                    DispatchQueue.main.async {
                        self?.latestState = state
                    }
                }
            }) { error in
                // sendMessage failed — fall back to transferUserInfo
                WCSession.default.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// Sends a clear-log request to the iPhone.
    func sendClearLog() {
        sendAction("CLEAR_LOG")
    }

    /// Analytics (additive): notifies the iPhone that the Watch log screen was
    /// opened, so the phone can emit `prayer_log_viewed` (device_source = watch)
    /// through its analytics transport. Uses `transferUserInfo` (queued,
    /// guaranteed delivery) and a distinct key so the phone routes it to
    /// analytics rather than the action handler. Carries the true capture time.
    func sendPrayerLogViewed() {
        guard session.activationState == .activated else { return }
        session.transferUserInfo([
            "analyticsEvent": "prayer_log_viewed",
            "timestamp": Date()
        ])
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isActivated = activationState == .activated
            self.isReachable = session.isReachable

            // Check for any existing application context from iPhone
            if !session.receivedApplicationContext.isEmpty {
                if let state = SyncedSessionState.fromDictionary(session.receivedApplicationContext) {
                    self.latestState = state
                    // Restore alarm schedule if one is still pending
                    if let fireDate = state.amenAlarmFireAt {
                        self.scheduleWatchAlarm(fireDate: fireDate)
                    }
                }
            }
        }
    }

    /// Receives state updates pushed by the iPhone via `updateApplicationContext`.
    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        if let state = SyncedSessionState.fromDictionary(applicationContext) {
            DispatchQueue.main.async {
                self.latestState = state
            }
            // Schedule or cancel the watch Amen Alarm based on the synced fire date
            if let fireDate = state.amenAlarmFireAt {
                scheduleWatchAlarm(fireDate: fireDate)
            } else {
                cancelWatchAlarm()
            }
        }
    }

    /// Tracks whether iPhone is reachable for choosing send strategy.
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
}
