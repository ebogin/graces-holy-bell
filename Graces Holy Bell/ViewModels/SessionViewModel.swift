import Foundation
import SwiftData
import Observation

/// Central business logic for Grace's Holy Bell.
///
/// Owns all state transitions, persistence, and elapsed-time computations.
/// Views read from it but never perform logic themselves.
///
/// State model: a CRDT-style event set + clear epoch.
/// Active log = events with timestamp > lastClearedAt, sorted ascending.
/// The merge engine (SyncEngine) provides derivations; cross-device merge is wired in Stage 3.
@Observable
@MainActor
final class SessionViewModel {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    /// Called after every state mutation so the connectivity manager can push updates to the Watch.
    var onStateChanged: (() -> Void)?

    /// Injected settings — used to decide whether / when to fire the phone alarm.
    var amenAlarmSettings: AmenAlarmSettings?

    /// Optional analytics sink. When nil the app behaves exactly as before.
    var analytics: AnalyticsService?

    /// Manages phone-side UNUserNotification scheduling for the Amen Alarm.
    let amenAlarmManager = AmenAlarmManager()

    // MARK: - Persisted State

    /// All known prayer events (unfiltered by epoch).
    private var allEvents: [PrayerEntry] = []

    /// The clear epoch — all events at or before this date are inactive.
    private(set) var lastClearedAt: Date?

    // MARK: - Derived State

    /// Active prayers (timestamp > lastClearedAt), sorted ascending by timestamp.
    private(set) var sortedEntries: [PrayerEntry] = []

    /// Active when there is at least one prayer after the clear epoch.
    var appState: AppState {
        sortedEntries.isEmpty ? .idle : .active
    }

    /// The timestamp of the most recent active prayer, or nil.
    var lastPrayerTimestamp: Date? {
        sortedEntries.last?.timestamp
    }

    /// The timestamp of the first active prayer (session start), or nil.
    var sessionStartedAt: Date? {
        sortedEntries.first?.timestamp
    }

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        load()
    }

    // MARK: - Actions

    /// Starts a new prayer session with a first PRAY.
    ///
    /// When already active, closes the current session (analytics) before starting fresh.
    func startNewSession() {
        if appState == .active {
            analytics?.recordSessionEnded(
                sessionStart: sessionStartedAt ?? Date(),
                prayerTimestamps: sortedEntries.map(\.timestamp)
            )
            applyAndSaveClearedAt(Date())
            pruneAndRefresh()
        }
        logPrayer()
    }

    /// Appends a phone-origin prayer.
    ///
    /// Always succeeds — when called from idle it starts a new session;
    /// when called from active it adds to the current session.
    func logPrayer() {
        let wasIdle = appState == .idle
        let timestamp = Date()

        let entry = PrayerEntry(id: UUID(), timestamp: timestamp, origin: PrayerEvent.Origin.phone.rawValue)
        modelContext.insert(entry)
        allEvents.append(entry)
        save()
        refreshEntries()
        scheduleAmenAlarmIfNeeded()
        onStateChanged?()

        if wasIdle {
            analytics?.recordSessionStarted(at: timestamp)
        } else if sortedEntries.count >= 2 {
            let prev = sortedEntries[sortedEntries.count - 2].timestamp
            analytics?.recordPrayerLogged(
                index: sortedEntries.count,
                sinceLast: timestamp.timeIntervalSince(prev),
                at: timestamp
            )
        }
    }

    /// Clears the active log. Both devices return to the idle screen.
    func clearLog() {
        if appState == .active {
            analytics?.recordSessionEnded(
                sessionStart: sessionStartedAt ?? Date(),
                prayerTimestamps: sortedEntries.map(\.timestamp)
            )
        }
        applyAndSaveClearedAt(Date())
        pruneAndRefresh()
        amenAlarmManager.cancelAlarm()
        onStateChanged?()
    }

    /// Re-applies the Amen Alarm schedule after a settings change.
    func refreshAmenAlarm() {
        if appState == .active {
            scheduleAmenAlarmIfNeeded()
        } else {
            amenAlarmManager.cancelAlarm()
        }
    }

    // MARK: - Cross-device Merge (called by PhoneConnectivityManager; never emits analytics)

    /// Merges an incoming Watch snapshot into the local SwiftData store.
    /// Inserts new watch-origin events, advances lastClearedAt if needed.
    /// Never emits analytics — each prayer is counted exactly once at its origin.
    func mergeIncoming(snapshot: SyncSnapshot) {
        let localPrayerEvents = allEvents.map {
            PrayerEvent(id: $0.id, timestamp: $0.timestamp, origin: PrayerEvent.Origin(rawValue: $0.origin) ?? .phone)
        }
        let (merged, mergedClearedAt) = SyncEngine.merge(
            localEvents: localPrayerEvents,
            localClearedAt: lastClearedAt,
            incomingEvents: snapshot.events,
            incomingClearedAt: snapshot.lastClearedAt
        )

        // Advance the clear epoch if the incoming one is later.
        if let newCleared = mergedClearedAt, newCleared != lastClearedAt {
            applyAndSaveClearedAt(newCleared)
        }

        // Insert new events that came from the Watch.
        let existingIDs = Set(allEvents.map(\.id))
        for event in merged where !existingIDs.contains(event.id) {
            let entry = PrayerEntry(id: event.id, timestamp: event.timestamp, origin: event.origin.rawValue)
            modelContext.insert(entry)
            allEvents.append(entry)
        }

        pruneAndRefresh()
        scheduleAmenAlarmIfNeeded()
        onStateChanged?()
    }

    /// Builds a SyncSnapshot from the current active state for sending to the Watch.
    func makeSnapshot(amenAlarmSettings: AmenAlarmSettings?) -> SyncSnapshot {
        let events = sortedEntries.map {
            PrayerEvent(id: $0.id, timestamp: $0.timestamp, origin: PrayerEvent.Origin(rawValue: $0.origin) ?? .phone)
        }
        let amenAlarmFireAt: Date? = {
            guard let settings = amenAlarmSettings,
                  settings.watchEnabled,
                  appState == .active,
                  let last = lastPrayerTimestamp else { return nil }
            return last.addingTimeInterval(settings.duration.rawValue)
        }()
        return SyncSnapshot(events: events, lastClearedAt: lastClearedAt, amenAlarmFireAt: amenAlarmFireAt)
    }

    // MARK: - Elapsed Time Computation

    func elapsedSinceLastPrayer(at now: Date = .now) -> TimeInterval {
        guard let lastTimestamp = lastPrayerTimestamp else { return 0 }
        return now.timeIntervalSince(lastTimestamp)
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

    private static let lastClearedAtKey = "prayer.lastClearedAt"

    private func load() {
        lastClearedAt = UserDefaults.standard.object(forKey: Self.lastClearedAtKey) as? Date
        let descriptor = FetchDescriptor<PrayerEntry>(sortBy: [SortDescriptor(\.timestamp)])
        allEvents = (try? modelContext.fetch(descriptor)) ?? []
        refreshEntries()
    }

    private func refreshEntries() {
        guard let cleared = lastClearedAt else {
            sortedEntries = allEvents.sorted { $0.timestamp < $1.timestamp }
            return
        }
        sortedEntries = allEvents
            .filter { $0.timestamp > cleared }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Removes events at or before the current lastClearedAt from both the store and in-memory list.
    private func pruneAndRefresh() {
        guard let cleared = lastClearedAt else { return }
        let toDelete = allEvents.filter { $0.timestamp <= cleared }
        toDelete.forEach { modelContext.delete($0) }
        allEvents.removeAll { $0.timestamp <= cleared }
        save()
        refreshEntries()
    }

    private func applyAndSaveClearedAt(_ date: Date) {
        lastClearedAt = date
        UserDefaults.standard.set(date, forKey: Self.lastClearedAtKey)
    }

    private func save() {
        try? modelContext.save()
    }

    private func scheduleAmenAlarmIfNeeded() {
        guard let settings = amenAlarmSettings,
              settings.phoneEnabled,
              let lastTimestamp = lastPrayerTimestamp else {
            amenAlarmManager.cancelAlarm()
            return
        }
        let fireDate = lastTimestamp.addingTimeInterval(settings.duration.rawValue)
        amenAlarmManager.scheduleAlarm(fireDate: fireDate)
    }
}
