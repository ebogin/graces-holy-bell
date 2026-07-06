import Foundation
import Observation

enum WatchRoute: Hashable {
    case firstLaunch
    case active
    case log
    case share
}

/// Watch-side ViewModel backed by a local Codable event store.
///
/// Prayers logged on the Watch are persisted immediately to WatchEventStore —
/// the log and timer work fully offline. Sync with the phone happens via
/// WatchConnectivityManager and converges using the same SyncEngine merge.
@Observable
@MainActor
final class WatchSessionViewModel {

    // MARK: - Dependencies

    private let connectivityManager: WatchConnectivityManager

    // MARK: - Local State

    private var storeState: WatchEventStore.State

    /// Local-only flag — shows the "JOIN US IN PRAYER?" QR share screen.
    var showingShare = false

    // MARK: - Derived State

    /// Active prayers (after lastClearedAt), sorted ascending by timestamp.
    private(set) var sortedEntries: [PrayerEvent] = []

    /// When the Amen Alarm should fire on this Watch, or nil.
    private(set) var amenAlarmFireAt: Date?

    var appState: AppState {
        sortedEntries.isEmpty ? .idle : .active
    }

    var lastPrayerTimestamp: Date? {
        sortedEntries.last?.timestamp
    }

    var showingLog = false

    var route: WatchRoute {
        switch appState {
        case .idle:   return .firstLaunch
        case .active:
            if showingShare { return .share }
            return showingLog ? .log : .active
        }
    }

    // MARK: - Initialization

    init(connectivityManager: WatchConnectivityManager) {
        self.connectivityManager = connectivityManager
        self.storeState = WatchEventStore.load()
        refreshDerived()
    }

    // MARK: - Local Actions (instant, offline-safe)

    /// Logs a watch-origin prayer and immediately updates the local display.
    /// The event is enqueued for delivery to the phone via WatchConnectivity.
    func sendPray() {
        let event = PrayerEvent(id: UUID(), timestamp: Date(), origin: .watch)
        storeState.events.append(event)
        saveStore()
        refreshDerived()
        connectivityManager.sendEvent(event)
        connectivityManager.sendSnapshot(makeSnapshot())
    }

    func sendStart() {
        sendPray()
    }

    /// Clears the log locally and sends the clear epoch to the phone.
    func sendClearLog() {
        let clearedAt = Date()
        storeState.lastClearedAt = clearedAt
        pruneStore()
        saveStore()
        refreshDerived()
        showingLog = false
        connectivityManager.sendClear(clearedAt: clearedAt)
        connectivityManager.sendSnapshot(makeSnapshot())
    }

    /// Proactively reconcile with the phone (called on app open / foreground).
    /// Pushes our current state and merges the phone's reply when reachable.
    func syncNow() {
        connectivityManager.sendSnapshot(makeSnapshot())
    }

    // MARK: - Sync: Receive and merge incoming snapshot

    /// Merges an incoming phone snapshot with the local Watch state.
    /// Safe to call from merge; never emits analytics.
    func applySnapshot(_ incoming: SyncSnapshot) {
        let (merged, mergedClearedAt) = SyncEngine.merge(
            localEvents: storeState.events,
            localClearedAt: storeState.lastClearedAt,
            incomingEvents: incoming.events,
            incomingClearedAt: incoming.lastClearedAt
        )
        storeState.events = merged
        storeState.lastClearedAt = mergedClearedAt

        // Persist the alarm interval the phone encoded so we can refire offline later.
        // Tombstones excluded — the phone computed fireAt from its last *active* prayer.
        if let fireAt = incoming.amenAlarmFireAt,
           let lastTS = incoming.events.filter({ !$0.isDeleted }).map(\.timestamp).max() {
            let interval = fireAt.timeIntervalSince(lastTS)
            if interval > 0 {
                storeState.lastSyncedAlarmInterval = interval
            }
        }

        pruneStore()
        saveStore()
        refreshDerived()
    }

    // MARK: - Analytics proxy

    func recordLogViewed() {
        connectivityManager.sendPrayerLogViewed()
    }

    // MARK: - Elapsed Time

    func elapsedSinceLastPrayer(at now: Date = .now) -> TimeInterval {
        guard let lastTimestamp = lastPrayerTimestamp else { return 0 }
        return now.timeIntervalSince(lastTimestamp)
    }

    private static let amenFlashDuration: TimeInterval = 5.0

    func alarmProgress(at now: Date = .now) -> Double? {
        guard let fireAt = amenAlarmFireAt,
              let lastTimestamp = lastPrayerTimestamp else { return nil }
        let interval = fireAt.timeIntervalSince(lastTimestamp)
        guard interval > 0 else { return nil }
        let elapsed = now.timeIntervalSince(lastTimestamp)
        if elapsed - interval > Self.amenFlashDuration { return nil }
        return elapsed / interval
    }

    func duration(for entryIndex: Int, at now: Date = .now) -> TimeInterval? {
        guard entryIndex >= 0, entryIndex < sortedEntries.count else { return nil }
        let entry = sortedEntries[entryIndex]
        if entryIndex + 1 < sortedEntries.count {
            return sortedEntries[entryIndex + 1].timestamp.timeIntervalSince(entry.timestamp)
        }
        return now.timeIntervalSince(entry.timestamp)
    }

    // MARK: - Private

    private func refreshDerived() {
        sortedEntries = SyncEngine.activeLog(
            events: storeState.events,
            lastClearedAt: storeState.lastClearedAt
        )
        if appState == .idle {
            showingLog = false
            showingShare = false
        }
        recomputeAlarm()
        // Keep the manager's cached snapshot current so it can reply to a
        // phone-initiated reconcile with up-to-date Watch state.
        connectivityManager.cacheLocalSnapshot(makeSnapshot())
    }

    private func recomputeAlarm() {
        guard let lastTS = lastPrayerTimestamp,
              let interval = storeState.lastSyncedAlarmInterval,
              interval > 0 else {
            amenAlarmFireAt = nil
            connectivityManager.cancelWatchAlarm()
            return
        }
        let fireAt = lastTS.addingTimeInterval(interval)
        amenAlarmFireAt = fireAt > .now ? fireAt : nil
        if let fireAt = amenAlarmFireAt {
            connectivityManager.scheduleWatchAlarm(fireDate: fireAt)
        } else {
            connectivityManager.cancelWatchAlarm()
        }
    }

    private func pruneStore() {
        guard let cleared = storeState.lastClearedAt else { return }
        storeState.events.removeAll { $0.timestamp <= cleared }
    }

    private func saveStore() {
        WatchEventStore.save(storeState)
    }

    private func makeSnapshot() -> SyncSnapshot {
        SyncSnapshot(
            events: storeState.events,
            lastClearedAt: storeState.lastClearedAt,
            amenAlarmFireAt: amenAlarmFireAt
        )
    }
}
