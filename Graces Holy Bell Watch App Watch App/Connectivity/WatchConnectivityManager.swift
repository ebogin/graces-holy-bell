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

    /// Follow-up wrist-tap pulses after the initial fire (seconds).
    private static let repeatOffsets: [TimeInterval] = [8, 16, 24]

    /// Every identifier this manager may have scheduled.
    private static var allAlarmIDs: [String] {
        [alarmNotificationID] + repeatOffsets.indices.map { "\(alarmNotificationID).repeat\($0)" }
    }

    // Latest local snapshot, kept current by the ViewModel. Lets us reply to a
    // phone-initiated sendMessage without hopping back to the @MainActor
    // ViewModel from this background delegate queue. Guarded by a lock since the
    // ViewModel (main) writes it and the WC delegate (background) reads it.
    private let snapshotLock = NSLock()
    private var cachedLocalSnapshot: [String: Any]?

    // Alarm-scheduling state. `scheduledAlarmKey` dedupes the very frequent
    // schedule calls (every snapshot/refresh); `alarmTask` chains the async
    // notification-center work so the remove/add pairs of overlapping calls can
    // never interleave — an interleaved stale task used to re-add pulses for an
    // *earlier* fire date, producing random wrist taps before the real alarm
    // and clobbering the fire-moment burst. Both guarded by `alarmLock` (this
    // manager is called from the main thread and the WC delegate queue).
    private let alarmLock = NSLock()
    /// Starts as a sentinel (not nil): pending notifications survive app
    /// relaunches, so the first cancel of a run must always reach the center,
    /// and the first schedule must never dedupe against a stale match.
    private var scheduledAlarmKey: String? = "unknown-at-launch"
    private var alarmTask: Task<Void, Never>?

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

    /// Schedules the local Watch Amen Alarm notifications.
    ///
    /// Persistence (background delivery): a burst of four notifications spreads
    /// wrist taps across 30 seconds so the alarm repeats instead of tapping
    /// once and vanishing. watchOS doesn't allow custom notification sounds,
    /// so Bell Sound uses the default audible tone on each pulse — the real
    /// clanging bell plays in-app when the takeover is up.
    func scheduleWatchAlarm(fireDate: Date, soundEnabled: Bool = false) {
        guard fireDate > .now else { return }

        // Dedupe: this is called on every snapshot/refresh, almost always with
        // an unchanged fire date. Only touch the notification center when the
        // schedule actually changes.
        let key = "\(fireDate.timeIntervalSinceReferenceDate)|\(soundEnabled)"
        alarmLock.lock()
        if scheduledAlarmKey == key {
            alarmLock.unlock()
            return
        }
        scheduledAlarmKey = key
        let previousTask = alarmTask

        let center = UNUserNotificationCenter.current()
        let sound: UNNotificationSound? = soundEnabled ? .default : nil
        alarmTask = Task { [weak self] in
            // Serialize behind any in-flight schedule/cancel so remove/add
            // pairs never interleave across calls.
            await previousTask?.value
            // A newer call superseded this one while it waited — skip.
            guard let self, self.currentAlarmKey() == key else { return }

            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            center.removePendingNotificationRequests(withIdentifiers: Self.allAlarmIDs)

            await Self.add(id: Self.alarmNotificationID, fireDate: fireDate, sound: sound, to: center)
            for (index, offset) in Self.repeatOffsets.enumerated() {
                await Self.add(
                    id: "\(Self.alarmNotificationID).repeat\(index)",
                    fireDate: fireDate.addingTimeInterval(offset),
                    sound: sound,
                    to: center
                )
            }
        }
        alarmLock.unlock()
    }

    func cancelWatchAlarm() {
        alarmLock.lock()
        // No-op when nothing is scheduled (the common idle-path call).
        guard scheduledAlarmKey != nil else {
            alarmLock.unlock()
            return
        }
        scheduledAlarmKey = nil
        let previousTask = alarmTask
        alarmTask = Task {
            await previousTask?.value
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: Self.allAlarmIDs)
        }
        alarmLock.unlock()
    }

    private func currentAlarmKey() -> String? {
        alarmLock.lock()
        defer { alarmLock.unlock() }
        return scheduledAlarmKey
    }

    private static func add(
        id: String,
        fireDate: Date,
        sound: UNNotificationSound?,
        to center: UNUserNotificationCenter
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Amen"
        content.sound = sound
        // Break through Focus modes — the alarm is explicitly user-scheduled.
        // Requires the Time Sensitive Notifications entitlement; harmlessly
        // downgraded to .active without it.
        content.interruptionLevel = .timeSensitive
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
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
                    self.scheduleWatchAlarm(
                        fireDate: fireDate,
                        soundEnabled: snapshot.amenAlarmSoundEnabled ?? false
                    )
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
            scheduleWatchAlarm(
                fireDate: fireDate,
                soundEnabled: snapshot.amenAlarmSoundEnabled ?? false
            )
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
