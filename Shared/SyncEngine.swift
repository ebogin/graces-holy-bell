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
    /// 2. Union events by `id` (incoming events not already present are added).
    /// 3. Prune any event with `timestamp <= lastClearedAt`.
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
        for event in incomingEvents where byID[event.id] == nil {
            byID[event.id] = event
        }

        let pruned = byID.values.filter { event in
            guard let cleared = mergedClearedAt else { return true }
            return event.timestamp > cleared
        }

        return (events: pruned, lastClearedAt: mergedClearedAt)
    }

    // MARK: - Derivations

    /// Returns events after `lastClearedAt`, sorted ascending by timestamp.
    static func activeLog(events: [PrayerEvent], lastClearedAt: Date?) -> [PrayerEvent] {
        events
            .filter { event in
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
