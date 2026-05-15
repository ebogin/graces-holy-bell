import Foundation
import Observation

enum WatchRoute: Hashable {
    case firstLaunch
    case active
    case log
    case idle
}

/// Watch-side ViewModel that mirrors the iPhone's session state.
///
/// Unlike the iPhone's SessionViewModel, this does NOT use SwiftData.
/// It holds plain structs received from the iPhone via WatchConnectivity,
/// and performs the same timestamp math for the live timer display.
///
/// Actions (PRAY, STOP, START) are sent to the iPhone for processing.
/// The iPhone processes them, updates SwiftData, and sends the new state back.
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

    /// Local-only flag — not synced to iPhone.
    var showingLog = false

    // MARK: - Derived State

    /// The timestamp of the most recent prayer entry, if any.
    var lastPrayerTimestamp: Date? {
        sortedEntries.last?.timestamp
    }

    var route: WatchRoute {
        switch appState {
        case .idle:   return sortedEntries.isEmpty ? .firstLaunch : .idle
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
        sessionStoppedAt = state.sessionStoppedAt
        hasExistingLog = state.hasExistingLog
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
        showingLog = false
        connectivityManager.sendAction("STOP")
    }

    /// Clears the local log immediately and notifies the iPhone.
    func sendClearLog() {
        sortedEntries = []
        sessionStoppedAt = nil
        hasExistingLog = false
        connectivityManager.sendClearLog()
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
}
