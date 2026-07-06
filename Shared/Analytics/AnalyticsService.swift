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

    /// The device an event currently originates on. Defaults to `.phone`; the
    /// connectivity layer sets this to `.watch` while it processes a Watch action
    /// so those events are attributed to the Watch (the phone is only the host).
    var deviceSource: DeviceSource = .phone

    init(
        transport: Analytics,
        stateStore: AnalyticsStateStore,
        contextProvider: @escaping () -> EventContext
    ) {
        self.transport = transport
        self.stateStore = stateStore
        self.contextProvider = contextProvider
    }

    private func factory(deviceSource override: DeviceSource? = nil) -> AnalyticsEventFactory {
        var context = contextProvider()
        context.deviceSource = override ?? deviceSource
        return AnalyticsEventFactory(context: context)
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

        recordAppOpened(now: now)
    }

    /// Records a foreground open (`app_opened`). Called once at launch by
    /// `recordLaunch`, and again on each background→foreground return.
    func recordAppOpened(now: Date = Date()) {
        let days = stateStore.installDate.map { Self.daysBetween($0, now) } ?? 0
        transport.capture(factory().appOpened(entryPoint: .icon, daysSinceInstall: days, at: now))
    }

    // MARK: - Amen Alarm

    /// The alarm was enabled, disabled, or its duration changed.
    func recordAmenAlarmSet(at timestamp: Date = Date()) {
        transport.capture(factory().amenAlarmSet(at: timestamp))
    }

    /// The app was opened from an Amen Alarm notification.
    func recordAmenAlarmTapped(at timestamp: Date = Date()) {
        transport.capture(factory().amenAlarmTapped(timeOfDay: TimeOfDayBucket.label(for: timestamp), at: timestamp))
    }

    // MARK: - Watch proxy

    /// A Watch-only `prayer_log_viewed`, proxied to the phone over WCSession.
    /// Always tagged `device_source = watch` and stamped with the Watch's true
    /// capture time — the phone is only the transport host and must not overwrite
    /// either (regardless of the current `deviceSource`).
    func recordWatchPrayerLogViewed(at timestamp: Date) {
        transport.capture(factory(deviceSource: .watch).prayerLogViewed(at: timestamp))
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
            localDate: LocalSessionDate.label(for: start),
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
            sessionDurationBucket: SessionDurationBucket.label(for: duration),
            timeOfDay: TimeOfDayBucket.label(for: sessionStart),
            dayOfWeek: DayOfWeek.label(for: sessionStart),
            at: end
        ))
        stateStore.closedSessionStart = sessionStart
    }

    // MARK: - Log editing (phone-only features)

    /// A prayer was deleted. `loggedAt` is the prayer's original timestamp —
    /// only the bucketed age (delete time − logged time) is sent.
    func recordPrayerDeleted(index: Int, loggedAt: Date, at timestamp: Date = Date()) {
        transport.capture(factory().prayerDeleted(
            prayerIndexInSession: index,
            prayerAgeBucket: DurationBucket.label(for: timestamp.timeIntervalSince(loggedAt)),
            at: timestamp
        ))
    }

    /// A prayer's time was edited from `oldTime` to `newTime`.
    func recordPrayerTimeEdited(oldTime: Date, newTime: Date, at timestamp: Date = Date()) {
        let shift = newTime.timeIntervalSince(oldTime)
        transport.capture(factory().prayerTimeEdited(
            direction: shift < 0 ? "earlier" : "later",
            adjustmentBucket: DurationBucket.label(for: abs(shift)),
            at: timestamp
        ))
    }

    /// A prayer intention was added, edited, or removed. Content never leaves the device.
    enum IntentionAction: String { case added, edited, removed }
    func recordPrayerIntentionSet(action: IntentionAction, at timestamp: Date = Date()) {
        transport.capture(factory().prayerIntentionSet(action: action.rawValue, at: timestamp))
    }

    /// The in-app Prayer History sheet was opened.
    func recordPrayerHistoryViewed(daysWithSessions: Int, at timestamp: Date = Date()) {
        transport.capture(factory().prayerHistoryViewed(daysWithSessions: daysWithSessions, at: timestamp))
    }

    /// The ADVANCED "Prayer Log Editing" master toggle was flipped.
    func recordPrayerLogEditingSet(enabled: Bool, at timestamp: Date = Date()) {
        transport.capture(factory().prayerLogEditingSet(enabled: enabled, at: timestamp))
    }

    /// A day's logs were exported to text from Prayer History.
    /// `completed` = user finished the share vs cancelled.
    func recordHistoryDayExported(sessionsInDay: Int, completed: Bool, at timestamp: Date = Date()) {
        transport.capture(factory().historyDayExported(
            sessionsInDay: sessionsInDay,
            completed: completed,
            at: timestamp
        ))
    }

    // MARK: - Persistence health

    /// The prayer store failed at `stage` (migration recovery, load, or save).
    /// Coarse label only — no paths or error strings.
    func recordPersistenceError(stage: PersistenceErrorStage, at timestamp: Date = Date()) {
        transport.capture(factory().persistenceError(stage: stage, at: timestamp))
    }

    // MARK: - Helpers

    private static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}
