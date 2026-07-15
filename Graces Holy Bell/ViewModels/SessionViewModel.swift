import Foundation
import SwiftData
import Observation
import os

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
    /// A load failure that happened during init (before analytics existed) is
    /// reported as soon as the sink is attached.
    var analytics: AnalyticsService? {
        didSet {
            if pendingLoadFailureReport {
                pendingLoadFailureReport = false
                analytics?.recordPersistenceError(stage: .load)
            }
        }
    }

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

    /// True when a paired Watch with the app installed is present. Drives the
    /// enabled/grayed state of the "Sync Up" Settings row. Set by
    /// PhoneConnectivityManager on activation and watch-state changes.
    var isWatchAvailable = false

    // MARK: - Initialization

    init(modelContext: ModelContext, archiveStore: SessionArchiveStore = SessionArchiveStore()) {
        self.modelContext = modelContext
        self.archiveStore = archiveStore
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
            archiveCurrentSession(endedAt: Date())
            applyAndSaveClearedAt(Date())
            pruneAndRefresh()
            changeStore.clear()
        }
        logPrayer()
    }

    /// Minimum gap between two logged prayers — absorbs an accidental rapid
    /// double-fire of the slider (which would create a 0-second log row).
    /// Tests zero this so they can log prayers back-to-back.
    var prayerDebounceInterval: TimeInterval = 1.0

    /// Appends a phone-origin prayer.
    ///
    /// Always succeeds — when called from idle it starts a new session;
    /// when called from active it adds to the current session. The only
    /// exception is a second fire within `prayerDebounceInterval` of the
    /// last prayer, which is dropped as an accidental double-slide.
    func logPrayer() {
        let wasIdle = appState == .idle
        let timestamp = Date()
        if let last = lastPrayerTimestamp,
           timestamp.timeIntervalSince(last) < prayerDebounceInterval {
            return
        }

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
        archiveCurrentSession(endedAt: Date())
        applyAndSaveClearedAt(Date())
        pruneAndRefresh()
        amenAlarmManager.cancelAlarm()
        changeStore.clear()
        onStateChanged?()
    }

    // MARK: - Log editing (phone-only)

    /// Deletes a prayer from the active log (accidental slider fire).
    ///
    /// The entry becomes a tombstone rather than being removed: it stays in the
    /// store (excluded from the log) so the deletion syncs to the Watch instead
    /// of the Watch resurrecting it on the next merge. Timer and durations
    /// recalculate automatically from the remaining entries.
    func deletePrayer(_ entry: PrayerEntry) {
        let index = sortedEntries.firstIndex(where: { $0.id == entry.id }).map { $0 + 1 }
        let now = Date()
        entry.isRemoved = true
        entry.updatedAt = now
        changeStore.append(PrayerLogChange(
            kind: .deleted, occurredAt: now, originalTimestamp: entry.timestamp, newTimestamp: nil
        ))
        save()
        refreshEntries()
        refreshAmenAlarm()
        onStateChanged?()
        // No event when the entry wasn't in the active log (already-removed
        // edge) — a fabricated index-0 would pollute the 1-based buckets.
        if let index {
            analytics?.recordPrayerDeleted(index: index, loggedAt: entry.timestamp, at: now)
        }
    }

    /// Changes a prayer's time (forgot to fire the slider until later).
    /// The log re-sorts and all durations + the live timer recalculate.
    func editPrayerTime(_ entry: PrayerEntry, to newTime: Date) {
        let oldTime = entry.timestamp
        guard newTime != oldTime else { return }
        let now = Date()
        entry.timestamp = newTime
        entry.updatedAt = now
        changeStore.append(PrayerLogChange(
            kind: .timeEdited, occurredAt: now, originalTimestamp: oldTime, newTimestamp: newTime
        ))
        save()
        refreshEntries()
        refreshAmenAlarm()
        onStateChanged?()
        analytics?.recordPrayerTimeEdited(oldTime: oldTime, newTime: newTime, at: now)
    }

    /// Sets (or clears, when empty/whitespace) a prayer's intention note.
    func setIntention(_ entry: PrayerEntry, note: String?) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newNote = (trimmed?.isEmpty ?? true) ? nil : trimmed
        let oldNote = entry.note
        guard newNote != oldNote else { return }
        entry.note = newNote
        entry.updatedAt = Date()
        save()
        refreshEntries()
        onStateChanged?()

        let action: AnalyticsService.IntentionAction =
            oldNote == nil ? .added : (newNote == nil ? .removed : .edited)
        analytics?.recordPrayerIntentionSet(action: action)
    }


    /// Re-applies the Amen Alarm schedule after a settings change.
    func refreshAmenAlarm() {
        if appState == .active {
            scheduleAmenAlarmIfNeeded()
        } else {
            amenAlarmManager.cancelAlarm()
        }
    }

    // MARK: - Cross-device Merge (called by PhoneConnectivityManager)

    /// Merges an incoming Watch snapshot into the local SwiftData store.
    /// Inserts new watch-origin events, advances lastClearedAt if needed.
    ///
    /// Analytics: the Watch has no transport of its own, so a *new* watch-origin
    /// prayer is counted here, exactly once, when it first reaches the phone —
    /// tagged `device_source = watch` with its true timestamp (§8 of the sync
    /// vision: counted once, at origin, late arrival is fine). Echoes of events
    /// the phone already knows never re-emit, and a repeated delivery of the
    /// same clear can't double-close (`newCleared != lastClearedAt` plus the
    /// service's no-double-close guard).
    func mergeIncoming(snapshot: SyncSnapshot) {
        let wasActive = appState == .active
        let knownIDs = Set(allEvents.map(\.id))

        let localPrayerEvents = allEvents.map { $0.asPrayerEvent }
        let (merged, mergedClearedAt) = SyncEngine.merge(
            localEvents: localPrayerEvents,
            localClearedAt: lastClearedAt,
            incomingEvents: snapshot.events,
            incomingClearedAt: snapshot.lastClearedAt
        )

        // Track whether the merge actually altered local state. If nothing
        // changed we must NOT notify/re-send: onStateChanged → sendSnapshotToWatch
        // would bounce a message back to the Watch, which replies, which merges
        // again — an unbounded ping-pong even though state has converged.
        var changed = false

        // Analytics owed for this merge, accumulated as the state is applied.
        var owed = MergeAnalytics()

        // Advance the clear epoch if the incoming one is later. The session
        // ended remotely (Watch clear) — archive it first, folding in any
        // incoming pre-clear prayers the phone hadn't seen yet (Watch logged
        // offline, then cleared, then synced both at once).
        if let newCleared = mergedClearedAt, newCleared != lastClearedAt {
            let localIDs = Set(sortedEntries.map(\.id))
            let epoch = lastClearedAt ?? .distantPast
            let incomingActive = snapshot.events.filter {
                !$0.isDeleted && !localIDs.contains($0.id)
                    && $0.timestamp > epoch && $0.timestamp <= newCleared
            }

            // Every prayer of the ended session, flagging the ones that are
            // genuinely new watch prayers (never seen on this phone before).
            var endedSession: [(timestamp: Date, note: String?, newFromWatch: Bool)] =
                sortedEntries.map { ($0.timestamp, $0.note, false) }
            for event in incomingActive {
                endedSession.append((event.timestamp, event.note, event.origin == .watch && !knownIDs.contains(event.id)))
            }
            endedSession.sort { $0.timestamp < $1.timestamp }

            if !endedSession.isEmpty {
                archiveStore.append(ArchivedSession(
                    id: ArchivedSession.deterministicID(prayerTimestamps: endedSession.map(\.timestamp)),
                    endedAt: newCleared,
                    prayers: endedSession.map { ArchivedPrayer(timestamp: $0.timestamp, note: $0.note) },
                    changes: changeStore.load()
                ))
                for (i, prayer) in endedSession.enumerated() where prayer.newFromWatch {
                    let sinceLast = i > 0 ? prayer.timestamp.timeIntervalSince(endedSession[i - 1].timestamp) : 0
                    owed.endedSessionPrayers.append((prayer.timestamp, i + 1, sinceLast))
                }
                if !wasActive, let first = endedSession.first, first.newFromWatch {
                    owed.endedSessionStartedAt = first.timestamp
                }
                owed.remoteEnd = (endedSession[0].timestamp, endedSession.map(\.timestamp), newCleared)
            }
            applyAndSaveClearedAt(newCleared)
            changeStore.clear()
            changed = true
        }

        // Apply the merged result: insert events we didn't have, and update
        // entries where a newer version (LWW by updatedAt) won the merge.
        var insertedWatchIDs: Set<UUID> = []
        let entriesByID = Dictionary(uniqueKeysWithValues: allEvents.map { ($0.id, $0) })
        for event in merged {
            if let entry = entriesByID[event.id] {
                if event.updatedAt > entry.updatedAt {
                    entry.timestamp = event.timestamp
                    entry.updatedAt = event.updatedAt
                    entry.isRemoved = event.isDeleted
                    entry.note = event.note
                    changed = true
                }
            } else {
                let entry = PrayerEntry(
                    id: event.id,
                    timestamp: event.timestamp,
                    origin: event.origin.rawValue,
                    updatedAt: event.updatedAt,
                    isRemoved: event.isDeleted,
                    note: event.note
                )
                modelContext.insert(entry)
                allEvents.append(entry)
                if event.origin == .watch && !event.isDeleted {
                    insertedWatchIDs.insert(event.id)
                }
                changed = true
            }
        }

        guard changed else { return }

        pruneAndRefresh()

        // Count the new watch prayers now in the active log at their refreshed
        // positions (an insertion can re-sort earlier prayers in). These are
        // post-clear when a clear also arrived — the pruning inside
        // SyncEngine.merge guarantees no inserted event predates the epoch.
        if !insertedWatchIDs.isEmpty {
            for (i, entry) in sortedEntries.enumerated() where insertedWatchIDs.contains(entry.id) {
                let sinceLast = i > 0 ? entry.timestamp.timeIntervalSince(sortedEntries[i - 1].timestamp) : 0
                owed.livePrayers.append((entry.timestamp, i + 1, sinceLast))
            }
            // This merge opened the running session when the phone wasn't in
            // one (or a remote clear just ended the old one) and the log now
            // leads with a newly arrived watch prayer.
            if !wasActive || owed.remoteEnd != nil,
               appState == .active,
               let first = sortedEntries.first, insertedWatchIDs.contains(first.id) {
                owed.liveSessionStartedAt = first.timestamp
            }
        }

        emitMergeAnalytics(owed)

        scheduleAmenAlarmIfNeeded()
        onStateChanged?()
    }

    /// Analytics owed for one merge: the lifecycle of a remotely ended session
    /// (started/prayed/ended entirely away from the phone), and new watch
    /// prayers in the still-running session.
    private struct MergeAnalytics {
        /// Set when a watch prayer opened the (now ended) session.
        var endedSessionStartedAt: Date?
        /// Newly arrived watch prayers belonging to the ended session.
        var endedSessionPrayers: [(timestamp: Date, index: Int, sinceLast: TimeInterval)] = []
        /// Set when an incoming clear ended a session — session_ended is
        /// emitted on the phone because the Watch never emits.
        var remoteEnd: (sessionStart: Date, prayerTimestamps: [Date], endedAt: Date)?
        /// Set when a watch prayer opened the currently running session.
        var liveSessionStartedAt: Date?
        /// Newly arrived watch prayers in the currently running session.
        var livePrayers: [(timestamp: Date, index: Int, sinceLast: TimeInterval)] = []

        var isEmpty: Bool {
            endedSessionStartedAt == nil && endedSessionPrayers.isEmpty
                && remoteEnd == nil && liveSessionStartedAt == nil && livePrayers.isEmpty
        }
    }

    /// Emits the analytics owed for a merge, all tagged `device_source = watch`,
    /// in chronological order: the remotely ended session's lifecycle first,
    /// then the running session's arrivals.
    private func emitMergeAnalytics(_ owed: MergeAnalytics) {
        guard let analytics, !owed.isEmpty else { return }

        analytics.deviceSource = .watch
        defer { analytics.deviceSource = .phone }

        // recordSessionStarted emits session_started plus the opening
        // prayer_logged (index 1), so the index-1 arrival is skipped below.
        if let startedAt = owed.endedSessionStartedAt {
            analytics.recordSessionStarted(at: startedAt)
        }
        for prayer in owed.endedSessionPrayers
        where !(owed.endedSessionStartedAt != nil && prayer.index == 1) {
            analytics.recordPrayerLogged(index: prayer.index, sinceLast: prayer.sinceLast, at: prayer.timestamp)
        }
        if let remoteEnd = owed.remoteEnd {
            analytics.recordSessionEnded(
                sessionStart: remoteEnd.sessionStart,
                prayerTimestamps: remoteEnd.prayerTimestamps,
                at: remoteEnd.endedAt
            )
        }

        if let startedAt = owed.liveSessionStartedAt {
            analytics.recordSessionStarted(at: startedAt)
        }
        for prayer in owed.livePrayers
        where !(owed.liveSessionStartedAt != nil && prayer.index == 1) {
            analytics.recordPrayerLogged(index: prayer.index, sinceLast: prayer.sinceLast, at: prayer.timestamp)
        }
    }

    /// Builds a SyncSnapshot from the current active state for sending to the Watch.
    /// Includes tombstones (deleted prayers) — that's how a phone-side delete
    /// reaches the Watch instead of being resurrected by its next snapshot.
    func makeSnapshot(amenAlarmSettings: AmenAlarmSettings?) -> SyncSnapshot {
        let events = allEvents
            .filter { entry in
                guard let cleared = lastClearedAt else { return true }
                return entry.timestamp > cleared
            }
            .map { $0.asPrayerEvent }
        let amenAlarmFireAt: Date? = {
            guard let settings = amenAlarmSettings,
                  settings.watchEnabled,
                  appState == .active,
                  let last = lastPrayerTimestamp else { return nil }
            return last.addingTimeInterval(settings.duration.rawValue)
        }()
        // The setting itself (not just the next fire date) — nil means the
        // Watch alarm is OFF, which the Watch applies authoritatively.
        let watchAlarmInterval: TimeInterval? = {
            guard let settings = amenAlarmSettings, settings.watchEnabled else { return nil }
            return settings.duration.rawValue
        }()
        return SyncSnapshot(
            events: events,
            lastClearedAt: lastClearedAt,
            amenAlarmFireAt: amenAlarmFireAt,
            watchAlarmInterval: watchAlarmInterval,
            amenAlarmSoundEnabled: amenAlarmSettings?.soundEnabled
        )
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

    /// Session change history (deletes / time edits) for the saved Notes log.
    private let changeStore = PrayerLogChangeStore()

    /// Append-only archive of ended sessions, browsed in Prayer History.
    private let archiveStore: SessionArchiveStore

    /// Freezes the current active session into the history archive.
    /// Call BEFORE advancing the clear epoch — it reads the live log.
    /// (A remote Watch clear archives inline in `mergeIncoming`, where the
    /// incoming pre-clear prayers are folded in.)
    private func archiveCurrentSession(endedAt: Date) {
        guard !sortedEntries.isEmpty else { return }
        archiveStore.append(ArchivedSession(
            id: ArchivedSession.deterministicID(prayerTimestamps: sortedEntries.map(\.timestamp)),
            endedAt: endedAt,
            prayers: sortedEntries.map { ArchivedPrayer(timestamp: $0.timestamp, note: $0.note) },
            changes: changeStore.load()
        ))
    }

    private let logger = Logger(subsystem: "Boginfactory.Graces-Holy-Bell", category: "persistence")

    /// Set when load() failed before the analytics sink was attached.
    private var pendingLoadFailureReport = false

    /// Report a dead store to analytics at most once per run — save() fires on
    /// every mutation and would otherwise spam.
    private var hasReportedSaveFailure = false

    private func load() {
        lastClearedAt = UserDefaults.standard.object(forKey: Self.lastClearedAtKey) as? Date
        let descriptor = FetchDescriptor<PrayerEntry>(sortBy: [SortDescriptor(\.timestamp)])
        do {
            allEvents = try modelContext.fetch(descriptor)
        } catch {
            // Never silent: the 1.42 data-loss bug hid behind a swallowed error here.
            logger.fault("Prayer store fetch failed: \(error, privacy: .public)")
            allEvents = []
            pendingLoadFailureReport = true
        }
        refreshEntries()
    }

    private func refreshEntries() {
        sortedEntries = allEvents
            .filter { entry in
                guard !entry.isRemoved else { return false }
                guard let cleared = lastClearedAt else { return true }
                return entry.timestamp > cleared
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Removes events at or before the current lastClearedAt from both the store
    /// and in-memory list, then refreshes the derived log. Always refreshes —
    /// even with no clear epoch — because mergeIncoming relies on this to surface
    /// newly merged Watch events (otherwise a merged prayer wouldn't appear on a
    /// never-cleared phone until some other refresh fired).
    private func pruneAndRefresh() {
        if let cleared = lastClearedAt {
            let toDelete = allEvents.filter { $0.timestamp <= cleared }
            toDelete.forEach { modelContext.delete($0) }
            allEvents.removeAll { $0.timestamp <= cleared }
            save()
        }
        refreshEntries()
    }

    private func applyAndSaveClearedAt(_ date: Date) {
        lastClearedAt = date
        UserDefaults.standard.set(date, forKey: Self.lastClearedAtKey)
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            // Never silent: the 1.42 data-loss bug hid behind a swallowed error here.
            logger.fault("Prayer store save failed: \(error, privacy: .public)")
            if !hasReportedSaveFailure {
                hasReportedSaveFailure = true
                analytics?.recordPersistenceError(stage: .save)
            }
        }
    }

    private func scheduleAmenAlarmIfNeeded() {
        guard let settings = amenAlarmSettings,
              settings.phoneEnabled,
              let lastTimestamp = lastPrayerTimestamp else {
            amenAlarmManager.cancelAlarm()
            return
        }
        let fireDate = lastTimestamp.addingTimeInterval(settings.duration.rawValue)
        amenAlarmManager.scheduleAlarm(fireDate: fireDate, soundEnabled: settings.soundEnabled)
    }
}

// MARK: - PrayerEntry → PrayerEvent

private extension PrayerEntry {
    var asPrayerEvent: PrayerEvent {
        PrayerEvent(
            id: id,
            timestamp: timestamp,
            origin: PrayerEvent.Origin(rawValue: origin) ?? .phone,
            updatedAt: updatedAt,
            isDeleted: isRemoved,
            note: note
        )
    }
}
