import Foundation

/// How the app came to the foreground / a session began (§2 `entry_point`).
enum EntryPoint: String {
    case icon, notification, widget
}

/// Why a session was abandoned (§2 `session_abandoned` `reason`).
enum AbandonReason: String {
    case userExit = "user_exit"
    case forgottenTimer = "forgotten_timer"
}

/// Where persistence failed (`persistence_error` `stage`). Labels only — no
/// paths, no error strings.
enum PersistenceErrorStage: String {
    case migrationRecovery = "migration_recovery"
    case load
    case save
}

/// Pure factory for the §2 event taxonomy.
///
/// Each method assembles `name` + event-specific properties on top of the
/// shared context. No side effects, no transport — callers (Phase 2c/2d) derive
/// the inputs and hand the resulting `AnalyticsEvent` to an `Analytics`.
struct AnalyticsEventFactory {

    let context: EventContext

    private func event(
        _ name: String,
        _ extra: [String: AnalyticsValue] = [:],
        at timestamp: Date
    ) -> AnalyticsEvent {
        var properties = context.baseProperties()
        properties.merge(extra) { _, new in new }
        return AnalyticsEvent(
            name: name,
            properties: properties,
            deviceSource: context.deviceSource,
            captureTimestamp: timestamp
        )
    }

    // MARK: - Install / lifecycle

    func appInstalled(installDate: Date, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("app_installed", [
            "install_date": .string(ISO8601DateFormatter().string(from: installDate))
        ], at: timestamp)
    }

    func watchAppInstalled(at timestamp: Date = Date()) -> AnalyticsEvent {
        event("watch_app_installed", at: timestamp)
    }

    func appOpened(entryPoint: EntryPoint, daysSinceInstall: Int, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("app_opened", [
            "entry_point": .string(entryPoint.rawValue),
            "days_since_install": .int(daysSinceInstall)
        ], at: timestamp)
    }

    // MARK: - Session

    func sessionStarted(entryPoint: EntryPoint, timeOfDay: String, dayOfWeek: String, localDate: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("session_started", [
            "entry_point": .string(entryPoint.rawValue),
            "time_of_day_bucket": .string(timeOfDay),
            "day_of_week": .string(dayOfWeek),
            "session_local_date": .string(localDate)
        ], at: timestamp)
    }

    /// `sinceLastPrayerBucket` is nil for the opening prayer of a session (no
    /// predecessor) — the property is then omitted rather than faked.
    func prayerLogged(prayerIndexInSession: Int, sinceLastPrayerBucket: String?, at timestamp: Date = Date()) -> AnalyticsEvent {
        var extra: [String: AnalyticsValue] = ["prayer_index_in_session": .int(prayerIndexInSession)]
        if let bucket = sinceLastPrayerBucket {
            extra["since_last_prayer_bucket"] = .string(bucket)
        }
        return event("prayer_logged", extra, at: timestamp)
    }

    func sessionEnded(
        prayersInSession: Int,
        sessionValue: SessionValue,
        sessionDurationBucket: String,
        timeOfDay: String,
        dayOfWeek: String,
        at timestamp: Date = Date()
    ) -> AnalyticsEvent {
        event("session_ended", [
            "prayers_in_session": .int(prayersInSession),
            "session_value": .string(sessionValue.rawValue),
            "session_duration_bucket": .string(sessionDurationBucket),
            "time_of_day_bucket": .string(timeOfDay),
            "day_of_week": .string(dayOfWeek)
        ], at: timestamp)
    }

    func sessionAbandoned(prayersSoFar: Int, reason: AbandonReason, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("session_abandoned", [
            "prayers_so_far": .int(prayersSoFar),
            "reason": .string(reason.rawValue)
        ], at: timestamp)
    }

    // MARK: - Log editing (phone-only features)

    /// A prayer was deleted from the active log. `prayerAgeBucket` is how long
    /// after being logged the prayer was deleted (bucketed — no raw durations).
    func prayerDeleted(prayerIndexInSession: Int, prayerAgeBucket: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("prayer_deleted", [
            "prayer_index_in_session": .int(prayerIndexInSession),
            "prayer_age_bucket": .string(prayerAgeBucket)
        ], at: timestamp)
    }

    /// A prayer's time was edited. `direction` is "earlier"/"later";
    /// `adjustmentBucket` is the bucketed size of the shift.
    func prayerTimeEdited(direction: String, adjustmentBucket: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("prayer_time_edited", [
            "direction": .string(direction),
            "adjustment_bucket": .string(adjustmentBucket)
        ], at: timestamp)
    }

    /// A prayer intention was added/edited/removed. Content is never sent.
    func prayerIntentionSet(action: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("prayer_intention_set", ["action": .string(action)], at: timestamp)
    }

    /// The in-app Prayer History was opened. `daysWithSessions` is how many
    /// calendar days currently hold archived sessions (a rough depth signal).
    func prayerHistoryViewed(daysWithSessions: Int, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("prayer_history_viewed", ["days_with_sessions": .int(daysWithSessions)], at: timestamp)
    }

    /// The ADVANCED "Prayer Log Editing" master toggle was flipped.
    func prayerLogEditingSet(enabled: Bool, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("prayer_log_editing_set", ["enabled": .bool(enabled)], at: timestamp)
    }

    /// A day's logs were exported to text from Prayer History.
    /// `completed` is whether the user finished the share (vs cancelled).
    func historyDayExported(sessionsInDay: Int, completed: Bool, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("history_day_exported", [
            "sessions_in_day": .int(sessionsInDay),
            "completed": .bool(completed)
        ], at: timestamp)
    }

    // MARK: - Amen Alarm / notifications

    func amenAlarmSet(at timestamp: Date = Date()) -> AnalyticsEvent {
        event("amen_alarm_set", at: timestamp)
    }

    /// Fired when the app is opened from an Amen Alarm notification. (Renamed
    /// from `notification_tapped` for clarity; `amen_alarm_fired` is intentionally
    /// not emitted — backgrounded delivery has no observable callback on iOS.)
    func amenAlarmTapped(timeOfDay: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("amen_alarm_tapped", ["time_of_day_bucket": .string(timeOfDay)], at: timestamp)
    }

    // MARK: - Watch-only

    func prayerLogViewed(at timestamp: Date = Date()) -> AnalyticsEvent {
        event("prayer_log_viewed", at: timestamp)
    }

    // MARK: - Persistence health

    func persistenceError(stage: PersistenceErrorStage, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("persistence_error", ["stage": .string(stage.rawValue)], at: timestamp)
    }
}
