import Foundation
import SwiftData
import Observation

/// Central business logic for Grace's Holy Bell.
///
/// This class owns all state transitions, persistence, and elapsed-time computations.
/// Views read from it but never perform logic themselves.
///
/// Designed to be the single point of contact for WatchConnectivity —
/// the Watch calls the same `startNewSession()`, `logPrayer()`, and `clearLog()` methods.
@Observable
@MainActor
final class SessionViewModel {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    /// Called after every state mutation so the connectivity manager can push updates to the Watch.
    var onStateChanged: (() -> Void)?

    /// Injected settings — used to decide whether / when to fire the phone alarm.
    var amenAlarmSettings: AmenAlarmSettings?

    /// Optional analytics sink. Additive, side-effect-free instrumentation — when
    /// nil (e.g. in tests) the app behaves exactly as before.
    var analytics: AnalyticsService?

    /// Manages phone-side UNUserNotification scheduling for the Amen Alarm.
    let amenAlarmManager = AmenAlarmManager()

    // MARK: - Published State

    /// The current (or most recent) prayer session, or nil if none exists.
    private(set) var currentSession: PrayerSession?

    /// Entries from the current session, sorted by sequence index.
    private(set) var sortedEntries: [PrayerEntry] = []

    // MARK: - Derived State

    /// The current app state — a session always runs until it is cleared,
    /// so existence of a session means ACTIVE.
    var appState: AppState {
        currentSession == nil ? .idle : .active
    }

    /// The timestamp of the most recent prayer entry, if any.
    var lastPrayerTimestamp: Date? {
        sortedEntries.last?.timestamp
    }

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCurrentSession()
    }

    // MARK: - Actions

    /// Starts a new prayer session.
    ///
    /// Deletes any existing session (cascade removes its entries),
    /// creates a new session, and records the first prayer entry.
    func startNewSession() {
        // Delete old session if one exists
        if let old = currentSession {
            // Analytics (additive): close the replaced session before it is deleted.
            analytics?.recordSessionEnded(
                sessionStart: old.startedAt,
                prayerTimestamps: old.entries.map(\.timestamp)
            )
            modelContext.delete(old)
        }

        let session = PrayerSession()
        let firstEntry = PrayerEntry(timestamp: .now, sequenceIndex: 0)
        firstEntry.session = session
        session.entries.append(firstEntry)

        modelContext.insert(session)
        save()

        currentSession = session
        refreshEntries()
        scheduleAmenAlarmIfNeeded()
        onStateChanged?()

        // Analytics (additive): session_started + opening prayer_logged.
        analytics?.recordSessionStarted(at: session.startedAt)
    }

    /// Logs a new prayer in the current active session.
    ///
    /// Records the current timestamp and restarts the elapsed timer.
    /// Does nothing if there is no active session.
    func logPrayer() {
        guard let session = currentSession else { return }

        let entry = PrayerEntry(
            timestamp: .now,
            sequenceIndex: sortedEntries.count
        )
        entry.session = session
        session.entries.append(entry)

        save()
        refreshEntries()
        scheduleAmenAlarmIfNeeded()
        onStateChanged?()

        // Analytics (additive): a subsequent prayer (index >= 2) with its gap.
        if sortedEntries.count >= 2 {
            let last = sortedEntries[sortedEntries.count - 1].timestamp
            let prev = sortedEntries[sortedEntries.count - 2].timestamp
            analytics?.recordPrayerLogged(
                index: sortedEntries.count,
                sinceLast: last.timeIntervalSince(prev),
                at: last
            )
        }
    }

    /// Deletes the current session and all its entries.
    /// This is the only way a session ends — both devices return to the welcome screen.
    func clearLog() {
        if let session = currentSession {
            // Analytics (additive): close the session before it is deleted.
            analytics?.recordSessionEnded(
                sessionStart: session.startedAt,
                prayerTimestamps: sortedEntries.map(\.timestamp)
            )
            modelContext.delete(session)
            save()
        }
        currentSession = nil
        sortedEntries = []
        amenAlarmManager.cancelAlarm()
        onStateChanged?()
    }

    /// Re-applies the Amen Alarm schedule after a settings change.
    ///
    /// Keeps the phone alarm in sync with the toggles/duration mid-session
    /// (otherwise changes would only take effect on the next PRAY slide).
    func refreshAmenAlarm() {
        if appState == .active {
            scheduleAmenAlarmIfNeeded()
        } else {
            amenAlarmManager.cancelAlarm()
        }
    }

    // MARK: - Elapsed Time Computation

    /// Computes the live elapsed time since the most recent prayer entry.
    ///
    /// The `now` parameter should come from `TimelineView`'s `context.date`,
    /// ensuring the source of truth is always a stored timestamp, never a counter.
    func elapsedSinceLastPrayer(at now: Date = .now) -> TimeInterval {
        guard let lastTimestamp = lastPrayerTimestamp else { return 0 }
        return now.timeIntervalSince(lastTimestamp)
    }

    /// Computes the duration for a specific prayer entry.
    ///
    /// - For entries that are NOT the last: duration = next entry's timestamp - this entry's timestamp.
    /// - For the last entry: live elapsed time.
    ///
    /// Returns nil if the index is out of bounds.
    func duration(for entryIndex: Int, at now: Date = .now) -> TimeInterval? {
        guard entryIndex >= 0, entryIndex < sortedEntries.count else { return nil }

        let entry = sortedEntries[entryIndex]

        // Not the last entry: duration is the gap to the next entry
        if entryIndex + 1 < sortedEntries.count {
            return sortedEntries[entryIndex + 1].timestamp.timeIntervalSince(entry.timestamp)
        }

        // Last entry: live elapsed
        return now.timeIntervalSince(entry.timestamp)
    }

    // MARK: - Private

    /// Loads the most recent session from the database on startup.
    private func loadCurrentSession() {
        var descriptor = FetchDescriptor<PrayerSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        currentSession = sessions.first
        refreshEntries()
    }

    /// Re-sorts the cached entries array from the current session.
    private func refreshEntries() {
        sortedEntries = (currentSession?.entries ?? [])
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
    }

    /// Saves the model context, ensuring data is persisted immediately.
    private func save() {
        try? modelContext.save()
    }

    /// Schedules (or reschedules) the phone Amen Alarm based on current settings.
    ///
    /// Called after every PRAY slide (startNewSession / logPrayer).
    /// Does nothing if phone alarm is disabled or there is no last prayer timestamp.
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
