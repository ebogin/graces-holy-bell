import Foundation
import WatchConnectivity
import Combine
import UserNotifications

/// Watch-side WatchConnectivity manager.
///
/// Responsibilities:
/// - Sends prayer events, clear messages, and snapshots to the iPhone.
/// - Receives snapshot updates from the iPhone and publishes them for the ViewModel.
/// - Schedules/cancels the local Watch Amen Alarm notification.
///
/// NOT isolated to @MainActor — WCSession requires delegate callbacks on a background
/// serial queue. Published updates are dispatched to the main thread explicitly.
final class WatchConnectivityManager: NSObject, ObservableObject {

    /// The latest snapshot received from the iPhone. The ViewModel observes this.
    @Published var latestSnapshot: SyncSnapshot?

    @Published var isReachable = false
    @Published var isActivated = false

    private let session = WCSession.default
    private static let alarmNotificationID = "watchAmenAlarm"

    // Latest local snapshot, kept current by the ViewModel. Lets us reply to a
    // phone-initiated sendMessage without hopping back to the @MainActor
    // ViewModel from this background delegate queue. Guarded by a lock since the
    // ViewModel (main) writes it and the WC delegate (background) reads it.
    private let snapshotLock = NSLock()
    private var cachedLocalSnapshot: [String: Any]?

    override init() {
        super.init()
        session.delegate = self
        session.activate()
    }

    /// Called by the ViewModel whenever local state changes, so a reply to a
    /// phone-initiated reconcile always carries the Watch's current state.
    func cacheLocalSnapshot(_ snapshot: SyncSnapshot) {
        let dict = snapshot.toDictionary()
        snapshotLock.lock()
        cachedLocalSnapshot = dict
        snapshotLock.unlock()
    }

    private func cachedSnapshotDictionary() -> [String: Any] {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return cachedLocalSnapshot ?? [:]
    }

    // MARK: - Send: event

    /// Sends a single watch-origin prayer event to the phone (offline-safe).
    func sendEvent(_ event: PrayerEvent) {
        guard session.activationState == .activated else { return }
        session.transferUserInfo(EventMessage(event: event).toUserInfo())
    }

    // MARK: - Send: clear

    /// Sends a clear epoch to the phone (offline-safe).
    func sendClear(clearedAt: Date) {
        guard session.activationState == .activated else { return }
        session.transferUserInfo(ClearMessage(clearedAt: clearedAt).toUserInfo())
    }

    // MARK: - Send: snapshot

    /// Sends a full state snapshot to the phone.
    /// Always updates applicationContext; also tries sendMessage when reachable
    /// (the phone replies with its own snapshot which we merge).
    func sendSnapshot(_ snapshot: SyncSnapshot) {
        cacheLocalSnapshot(snapshot)
        guard session.activationState == .activated else { return }
        let dict = snapshot.toDictionary()
        try? session.updateApplicationContext(dict)
        reconcileIfReachable(dict)
    }

    /// When the phone is reachable, send our snapshot and merge its reply — an
    /// immediate two-way reconcile. Used on app open and reachability changes so
    /// the Watch shows fresh state instead of waiting for background delivery.
    private func reconcileIfReachable(_ dict: [String: Any]) {
        guard session.isReachable else { return }
        session.sendMessage(dict, replyHandler: { [weak self] reply in
            guard let phoneSnapshot = SyncSnapshot.fromDictionary(reply) else { return }
            DispatchQueue.main.async {
                self?.latestSnapshot = phoneSnapshot
            }
        }, errorHandler: nil)
    }

    // MARK: - Analytics proxy (unchanged)

    func sendPrayerLogViewed() {
        guard session.activationState == .activated else { return }
        session.transferUserInfo(WatchAnalyticsProxy.prayerLogViewedPayload(at: Date()))
    }

    // MARK: - Analytics proxy (share surface, additive)

    func sendShareScreenOpened(referralCode: String) {
        guard session.activationState == .activated else { return }
        session.transferUserInfo(WatchAnalyticsProxy.shareScreenOpenedPayload(referralCode: referralCode, at: Date()))
    }

    func sendQRDisplayed(referralCode: String) {
        guard session.activationState == .activated else { return }
        session.transferUserInfo(WatchAnalyticsProxy.qrDisplayedPayload(referralCode: referralCode, at: Date()))
    }

    // MARK: - Watch Amen Alarm

    func scheduleWatchAlarm(fireDate: Date) {
        guard fireDate > .now else { return }
        let center = UNUserNotificationCenter.current()
        Task {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                try? await center.requestAuthorization(options: [.alert, .sound])
            }
            center.removePendingNotificationRequests(withIdentifiers: [Self.alarmNotificationID])
            let content = UNMutableNotificationContent()
            content.title = "🔔 Amen"
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

    func cancelWatchAlarm() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.alarmNotificationID])
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

            // Apply any snapshot already cached from a previous phone push.
            if let snapshot = SyncSnapshot.fromDictionary(session.receivedApplicationContext) {
                self.latestSnapshot = snapshot
                if let fireDate = snapshot.amenAlarmFireAt {
                    self.scheduleWatchAlarm(fireDate: fireDate)
                }
            }
        }
    }

    /// Receives snapshots pushed by the iPhone via updateApplicationContext.
    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let snapshot = SyncSnapshot.fromDictionary(applicationContext) else { return }
        if let fireDate = snapshot.amenAlarmFireAt {
            scheduleWatchAlarm(fireDate: fireDate)
        } else {
            cancelWatchAlarm()
        }
        DispatchQueue.main.async {
            self.latestSnapshot = snapshot
        }
    }

    /// Receives a snapshot the phone sent via sendMessage (immediate path).
    /// Publishes it for the ViewModel to merge, and replies with our own cached
    /// snapshot so the phone reconciles too — one round trip, both converge.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if let snapshot = SyncSnapshot.fromDictionary(message) {
            DispatchQueue.main.async {
                self.latestSnapshot = snapshot
            }
        }
        replyHandler(cachedSnapshotDictionary())
    }

    /// Receives a phone snapshot via sendMessage with no reply expected.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let snapshot = SyncSnapshot.fromDictionary(message) else { return }
        DispatchQueue.main.async {
            self.latestSnapshot = snapshot
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        // The phone just became reachable — pull/reconcile immediately rather
        // than waiting for the next local mutation or background delivery.
        if session.isReachable {
            reconcileIfReachable(cachedSnapshotDictionary())
        }
    }
}
