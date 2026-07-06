import Foundation

/// Pure, stateless merge engine shared by both iPhone and Watch targets.
///
/// All functions are free of I/O, WatchConnectivity, and SwiftData.
/// The merge is commutative and idempotent — applying it in any order,
/// any number of times, converges to the same result.
enum SyncEngine {

    // MARK: - Merge

    /// Merges a local event set with an incoming one.
    ///
    /// Rules:
    /// 1. `lastClearedAt` = max of both (nil treated as distant past).
    /// 2. Union events by `id`; when both sides carry the same `id`, the
    ///    version with the later `updatedAt` wins (LWW). This is what lets a
    ///    phone-side edit/delete survive the Watch echoing back its stale copy.
    /// 3. Prune any event with `timestamp <= lastClearedAt` (tombstones included).
    ///
    /// Returns the merged (events, lastClearedAt) — ready to persist.
    static func merge(
        localEvents: [PrayerEvent],
        localClearedAt: Date?,
        incomingEvents: [PrayerEvent],
        incomingClearedAt: Date?
    ) -> (events: [PrayerEvent], lastClearedAt: Date?) {

        let mergedClearedAt = maxDate(localClearedAt, incomingClearedAt)

        var byID = Dictionary(uniqueKeysWithValues: localEvents.map { ($0.id, $0) })
        for event in incomingEvents {
            if let existing = byID[event.id] {
                if event.updatedAt > existing.updatedAt {
                    byID[event.id] = event
                }
            } else {
                byID[event.id] = event
            }
        }

        let pruned = byID.values.filter { event in
            guard let cleared = mergedClearedAt else { return true }
            return event.timestamp > cleared
        }

        return (events: pruned, lastClearedAt: mergedClearedAt)
    }

    // MARK: - Derivations

    /// Returns non-deleted events after `lastClearedAt`, sorted ascending by timestamp.
    static func activeLog(events: [PrayerEvent], lastClearedAt: Date?) -> [PrayerEvent] {
        events
            .filter { event in
                guard !event.isDeleted else { return false }
                guard let cleared = lastClearedAt else { return true }
                return event.timestamp > cleared
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// True when there is at least one prayer after `lastClearedAt`.
    static func isActive(events: [PrayerEvent], lastClearedAt: Date?) -> Bool {
        !activeLog(events: events, lastClearedAt: lastClearedAt).isEmpty
    }

    /// The timestamp of the most recent active prayer, or nil if none.
    static func lastTimestamp(events: [PrayerEvent], lastClearedAt: Date?) -> Date? {
        activeLog(events: events, lastClearedAt: lastClearedAt).last?.timestamp
    }

    // MARK: - Private

    private static func maxDate(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case (nil, nil): return nil
        case (let d?, nil): return d
        case (nil, let d?): return d
        case (let da?, let db?): return max(da, db)
        }
    }
}
