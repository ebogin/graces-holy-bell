import Foundation

/// App-facing analytics coordinator.
///
/// Owns the derivation that turns app actions into §2 events (buckets, indices,
/// session value, lifecycle synthesis) and forwards them to the injected
/// transport. View/VM code calls the high-level `record…` methods; it never
/// builds events or touches the transport directly.
///
/// The transport is bound to the canonical `install_id` at construction (the
/// no-op default ignores it; the real PostHog transport identifies with it), so
/// events themselves carry no identity field. Context (device, alarm settings,
/// app/os version) is read fresh per event via `contextProvider`.
final class AnalyticsService {

    private let transport: Analytics
    private let contextProvider: () -> EventContext
    private let stateStore: AnalyticsStateStore

    init(
        transport: Analytics,
        stateStore: AnalyticsStateStore,
        contextProvider: @escaping () -> EventContext
    ) {
        self.transport = transport
        self.stateStore = stateStore
        self.contextProvider = contextProvider
    }

    private func factory() -> AnalyticsEventFactory {
        AnalyticsEventFactory(context: contextProvider())
    }

    // MARK: - Launch

    /// Records install/open and synthesizes a forgotten-timer abandon for a
    /// stale persisted session. `currentSessionStart`/`lastPrayerAt` describe the
    /// session restored from storage, if any.
    func recordLaunch(
        currentSessionStart: Date?,
        lastPrayerAt: Date?,
        prayersSoFar: Int,
        now: Date = Date()
    ) {
        if stateStore.installDate == nil {
            stateStore.installDate = now
            transport.capture(factory().appInstalled(installDate: now, at: now))
        }

        if let start = currentSessionStart, let last = lastPrayerAt {
            let snapshot = SessionLaunchSnapshot(
                lastPrayerAt: last,
                prayersSoFar: prayersSoFar,
                alreadyClosed: stateStore.closedSessionStart == start
            )
            if case let .synthesizeForgottenTimerAbandon(at, prayers) =
                SessionLifecycleReducer.evaluateAtLaunch(snapshot, now: now) {
                transport.capture(factory().sessionAbandoned(prayersSoFar: prayers, reason: .forgottenTimer, at: at))
                stateStore.closedSessionStart = start
            }
        }

        let days = stateStore.installDate.map { Self.daysBetween($0, now) } ?? 0
        transport.capture(factory().appOpened(entryPoint: .icon, daysSinceInstall: days, at: now))
    }

    // MARK: - Session lifecycle

    /// First PRAY of a session: emits `session_started` and the opening
    /// `prayer_logged` (index 1, no since-last gap).
    func recordSessionStarted(at start: Date) {
        let f = factory()
        transport.capture(f.sessionStarted(
            entryPoint: .icon,
            timeOfDay: TimeOfDayBucket.label(for: start),
            dayOfWeek: DayOfWeek.label(for: start),
            at: start
        ))
        transport.capture(f.prayerLogged(prayerIndexInSession: 1, sinceLastPrayerBucket: nil, at: start))
    }

    /// A subsequent PRAY (index >= 2). `sinceLast` is the gap from the previous prayer.
    func recordPrayerLogged(index: Int, sinceLast: TimeInterval, at timestamp: Date) {
        transport.capture(factory().prayerLogged(
            prayerIndexInSession: index,
            sinceLastPrayerBucket: DurationBucket.label(for: sinceLast),
            at: timestamp
        ))
    }

    /// Closes a session normally. No-ops if this session was already terminated
    /// in analytics (no-double-close). Duration is the span from start to the
    /// last prayer (the active praying window).
    func recordSessionEnded(sessionStart: Date, prayerTimestamps: [Date], at end: Date = Date()) {
        guard stateStore.closedSessionStart != sessionStart else { return }

        let sorted = prayerTimestamps.sorted()
        let duration = (sorted.last ?? sessionStart).timeIntervalSince(sessionStart)
        transport.capture(factory().sessionEnded(
            prayersInSession: prayerTimestamps.count,
            sessionValue: SessionValueClassifier.classify(prayerTimestamps: sorted),
            sessionDurationBucket: DurationBucket.label(for: duration),
            timeOfDay: TimeOfDayBucket.label(for: sessionStart),
            dayOfWeek: DayOfWeek.label(for: sessionStart),
            at: end
        ))
        stateStore.closedSessionStart = sessionStart
    }

    // MARK: - Helpers

    private static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}
