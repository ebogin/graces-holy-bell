import Foundation
import SwiftData
import Observation

/// Central business logic for Grace's Holy Bell.
///
/// This class owns all state transitions, persistence, and elapsed-time computations.
/// Views read from it but never perform logic themselves.
///
/// Designed to be the single point of contact for future WatchConnectivity integration —
/// the Watch will call the same `startNewSession()`, `logPrayer()`, and `stopSession()` methods.
@Observable
@MainActor
final class SessionViewModel {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    /// Called after every state mutation so the connectivity manager can push updates to the Watch.
    var onStateChanged: (() -> Void)?

    // MARK: - Published State

    /// The current (or most recent) prayer session, or nil if none exists.
    private(set) var currentSession: PrayerSession?

    /// Entries from the current session, sorted by sequence index.
    private(set) var sortedEntries: [PrayerEntry] = []

    // MARK: - Derived State

    /// The current app state, derived from whether a session exists and is active.
    var appState: AppState {
        guard let session = currentSession else { return .idle }
        return session.isActive ? .active : .idle
    }

    /// Whether there is an existing log from a previous (or current) session.
    /// Used to decide whether to show the "clear log?" confirmation when starting a new session.
    var hasExistingLog: Bool {
        currentSession != nil && !sortedEntries.isEmpty
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
        onStateChanged?()
    }

    /// Logs a new prayer in the current active session.
    ///
    /// Records the current timestamp and restarts the elapsed timer.
    /// Does nothing if there is no active session.
    func logPrayer() {
        guard let session = currentSession, session.isActive else { return }

        let entry = PrayerEntry(
            timestamp: .now,
            sequenceIndex: sortedEntries.count
        )
        entry.session = session
        session.entries.append(entry)

        save()
        refreshEntries()
        onStateChanged?()
    }

    /// Stops the current active session.
    ///
    /// Records the stop timestamp (used to freeze the final duration display).
    /// The session and its log remain visible in IDLE state.
    /// Does nothing if there is no active session.
    func stopSession() {
        guard let session = currentSession, session.isActive else { return }
        session.stoppedAt = .now
        save()
        onStateChanged?()
    }

    // MARK: - Elapsed Time Computation

    /// Computes the elapsed time since the most recent prayer entry.
    ///
    /// - In ACTIVE state: returns live elapsed time (`now - lastPrayerTimestamp`).
    /// - In IDLE state: returns frozen time (`stoppedAt - lastPrayerTimestamp`).
    ///
    /// The `now` parameter should come from `TimelineView`'s `context.date`,
    /// ensuring the source of truth is always a stored timestamp, never a counter.
    func elapsedSinceLastPrayer(at now: Date = .now) -> TimeInterval {
        guard let lastTimestamp = lastPrayerTimestamp else { return 0 }

        // If session is stopped, freeze at stop time
        if let session = currentSession, let stoppedAt = session.stoppedAt {
            return stoppedAt.timeIntervalSince(lastTimestamp)
        }

        // Active session: live elapsed
        return now.timeIntervalSince(lastTimestamp)
    }

    /// Computes the duration for a specific prayer entry.
    ///
    /// - For entries that are NOT the last: duration = next entry's timestamp - this entry's timestamp.
    /// - For the last entry in an ACTIVE session: live elapsed time.
    /// - For the last entry in an IDLE session: frozen at stop time.
    ///
    /// Returns nil if the index is out of bounds.
    func duration(for entryIndex: Int, at now: Date = .now) -> TimeInterval? {
        guard entryIndex >= 0, entryIndex < sortedEntries.count else { return nil }

        let entry = sortedEntries[entryIndex]

        // Not the last entry: duration is the gap to the next entry
        if entryIndex + 1 < sortedEntries.count {
            return sortedEntries[entryIndex + 1].timestamp.timeIntervalSince(entry.timestamp)
        }

        // Last entry in a stopped session: freeze at stop time
        if let session = currentSession, let stoppedAt = session.stoppedAt {
            return stoppedAt.timeIntervalSince(entry.timestamp)
        }

        // Last entry in an active session: live elapsed
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
}
