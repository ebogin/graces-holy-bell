import Foundation
import Observation

enum WatchRoute: Hashable {
    case firstLaunch
    case active
    case log
}

/// Watch-side ViewModel that mirrors the iPhone's session state.
///
/// Unlike the iPhone's SessionViewModel, this does NOT use SwiftData.
/// It holds plain structs received from the iPhone via WatchConnectivity,
/// and performs the same timestamp math for the live timer display.
///
/// Actions (PRAY, START, CLEAR_LOG) are sent to the iPhone for processing.
/// The iPhone processes them, updates SwiftData, and sends the new state back.
@Observable
@MainActor
final class WatchSessionViewModel {

    // MARK: - Dependencies

    private let connectivityManager: WatchConnectivityManager

    // MARK: - State (mirrors iPhone)

    /// Sorted prayer entries from the synced state.
    private(set) var sortedEntries: [SyncedEntry] = []

    /// When the Amen Alarm fires on the Watch, or nil when the alarm is off.
    private(set) var amenAlarmFireAt: Date?

    /// The current app state.
    private(set) var appState: AppState = .idle

    /// Local-only flag — not synced to iPhone.
    var showingLog = false

    // MARK: - Derived State

    /// The timestamp of the most recent prayer entry, if any.
    var lastPrayerTimestamp: Date? {
        sortedEntries.last?.timestamp
    }

    var route: WatchRoute {
        switch appState {
        // Any idle state returns to the welcome screen — matches the iPhone,
        // which always shows IdleView when idle. There is no separate "ended" page.
        case .idle:   return .firstLaunch
        case .active: return showingLog ? .log : .active
        }
    }

    // MARK: - Initialization

    init(connectivityManager: WatchConnectivityManager) {
        self.connectivityManager = connectivityManager
        // Apply any state already received before this ViewModel was created
        if let state = connectivityManager.latestState {
            apply(state)
        }
    }

    // MARK: - State Updates

    /// Applies a synced state snapshot received from the iPhone.
    func apply(_ state: SyncedSessionState) {
        let newAppState = state.appState == "active" ? AppState.active : AppState.idle
        if newAppState == .idle { showingLog = false }
        appState = newAppState
        sortedEntries = state.entries.sorted { $0.sequenceIndex < $1.sequenceIndex }
        amenAlarmFireAt = state.amenAlarmFireAt
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

    /// Ends the session by clearing the log — the watch STOP action.
    ///
    /// Mirrors the iPhone's "End Praying?" → Clear Log flow: the session and its
    /// log are discarded and both devices return to the welcome screen. Updates
    /// local state optimistically so the transition is immediate, then tells the
    /// iPhone (the source of truth) to clear.
    func sendClearLog() {
        sortedEntries = []
        appState = .idle
        showingLog = false
        connectivityManager.sendClearLog()
    }

    /// Analytics (additive): the Watch log screen was opened. Proxied to the
    /// iPhone, which emits `prayer_log_viewed` (device_source = watch).
    func recordLogViewed() {
        connectivityManager.sendPrayerLogViewed()
    }

    // MARK: - Elapsed Time Computation (same timestamp math as iPhone)

    /// Computes the live elapsed time since the most recent prayer entry.
    ///
    /// Works locally from synced timestamps — does NOT need an active connection.
    func elapsedSinceLastPrayer(at now: Date = .now) -> TimeInterval {
        guard let lastTimestamp = lastPrayerTimestamp else { return 0 }
        return now.timeIntervalSince(lastTimestamp)
    }

    /// How long the AMEN! blink and its haptic pulses last.
    private static let amenFlashDuration: TimeInterval = 5.0

    /// Amen Alarm progress since the last prayer (0...1+), or nil when the alarm
    /// is off. Derived from the synced fire date:
    /// the interval is `fireAt - lastPrayerTimestamp`, so no settings sync is needed.
    /// After the AMEN! flash window passes, returns nil so the slider reverts to plain PRAY.
    func alarmProgress(at now: Date = .now) -> Double? {
        guard let fireAt = amenAlarmFireAt,
              let lastTimestamp = lastPrayerTimestamp else { return nil }
        let interval = fireAt.timeIntervalSince(lastTimestamp)
        guard interval > 0 else { return nil }
        let elapsed = now.timeIntervalSince(lastTimestamp)
        if elapsed - interval > Self.amenFlashDuration { return nil }
        return elapsed / interval
    }

    /// Computes the duration for a specific prayer entry.
    func duration(for entryIndex: Int, at now: Date = .now) -> TimeInterval? {
        guard entryIndex >= 0, entryIndex < sortedEntries.count else { return nil }

        let entry = sortedEntries[entryIndex]

        // Not the last entry: gap to next entry
        if entryIndex + 1 < sortedEntries.count {
            return sortedEntries[entryIndex + 1].timestamp.timeIntervalSince(entry.timestamp)
        }

        // Last entry: live elapsed
        return now.timeIntervalSince(entry.timestamp)
    }
}
