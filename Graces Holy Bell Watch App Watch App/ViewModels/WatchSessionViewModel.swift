import Foundation
import Observation
import UserNotifications

/// Watch-side ViewModel that mirrors the iPhone's session state.
///
/// Unlike the iPhone's SessionViewModel, this does NOT use SwiftData.
/// It holds plain structs received from the iPhone via WatchConnectivity,
/// and performs the same timestamp math for the live timer display.
///
/// Actions (PRAY, STOP, START) are sent to the iPhone for processing.
/// The iPhone processes them, updates SwiftData, and sends the new state back.
///
/// When "Notify on Watch" is selected in Settings, this ViewModel schedules
/// a local watchOS notification for the suggested prayer interval.
@Observable
@MainActor
final class WatchSessionViewModel {

    // MARK: - Dependencies

    private let connectivityManager: WatchConnectivityManager

    // MARK: - State (mirrors iPhone)

    /// Sorted prayer entries from the synced state.
    private(set) var sortedEntries: [SyncedEntry] = []

    /// When the session was stopped, or nil if active.
    private(set) var sessionStoppedAt: Date?

    /// Whether there is an existing log.
    private(set) var hasExistingLog = false

    /// The current app state.
    private(set) var appState: AppState = .idle

    /// Suggested prayer interval in seconds (synced from iPhone settings).
    private(set) var intervalSeconds: Double = 3600

    /// Whether this Watch should schedule its own notification.
    private(set) var notifyOnWatch: Bool = false

    // MARK: - Derived State

    /// The timestamp of the most recent prayer entry, if any.
    var lastPrayerTimestamp: Date? {
        sortedEntries.last?.timestamp
    }

    // MARK: - Initialization

    init(connectivityManager: WatchConnectivityManager) {
        self.connectivityManager = connectivityManager
        requestNotificationPermission()
        // Apply any state already received before this ViewModel was created
        if let state = connectivityManager.latestState {
            apply(state)
        }
    }

    // MARK: - State Updates

    /// Applies a synced state snapshot received from the iPhone.
    func apply(_ state: SyncedSessionState) {
        appState = state.appState == "active" ? .active : .idle
        sortedEntries = state.entries.sorted { $0.sequenceIndex < $1.sequenceIndex }
        sessionStoppedAt = state.sessionStoppedAt
        hasExistingLog = state.hasExistingLog
        intervalSeconds = state.intervalSeconds
        notifyOnWatch = state.notifyOnWatch
        scheduleWatchNotificationIfNeeded()
    }

    // MARK: - Actions (sent to iPhone)

    /// Sends a START action to the iPhone.
    func sendStart() {
        connectivityManager.sendAction("START")
    }

    /// Sends a PRAY action to the iPhone.
    func sendPray() {
        connectivityManager.sendAction("PRAY")
    }

    /// Sends a STOP action to the iPhone.
    func sendStop() {
        connectivityManager.sendAction("STOP")
    }

    // MARK: - Elapsed Time Computation (same timestamp math as iPhone)

    /// Computes the elapsed time since the most recent prayer entry.
    ///
    /// Works locally from synced timestamps — does NOT need an active connection.
    func elapsedSinceLastPrayer(at now: Date = .now) -> TimeInterval {
        guard let lastTimestamp = lastPrayerTimestamp else { return 0 }

        // If session is stopped, freeze at stop time
        if let stoppedAt = sessionStoppedAt {
            return stoppedAt.timeIntervalSince(lastTimestamp)
        }

        // Active session: live elapsed
        return now.timeIntervalSince(lastTimestamp)
    }

    /// Computes the duration for a specific prayer entry.
    func duration(for entryIndex: Int, at now: Date = .now) -> TimeInterval? {
        guard entryIndex >= 0, entryIndex < sortedEntries.count else { return nil }

        let entry = sortedEntries[entryIndex]

        // Not the last entry: gap to next entry
        if entryIndex + 1 < sortedEntries.count {
            return sortedEntries[entryIndex + 1].timestamp.timeIntervalSince(entry.timestamp)
        }

        // Last entry in a stopped session: freeze at stop time
        if let stoppedAt = sessionStoppedAt {
            return stoppedAt.timeIntervalSince(entry.timestamp)
        }

        // Last entry in an active session: live elapsed
        return now.timeIntervalSince(entry.timestamp)
    }

    // MARK: - Watch Notifications

    private let watchNotificationID = "prayReminderWatch"

    /// Schedules a local Watch notification when notifyOnWatch is true and session is active.
    /// Cancels the pending notification in all other cases.
    private func scheduleWatchNotificationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [watchNotificationID])

        guard notifyOnWatch,
              appState == .active,
              let last = lastPrayerTimestamp else { return }

        let fireInterval = last.addingTimeInterval(intervalSeconds).timeIntervalSinceNow
        guard fireInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Pray"
        content.categoryIdentifier = "PRAY_REMINDER"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireInterval,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: watchNotificationID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Requests local notification authorization on the Watch.
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
