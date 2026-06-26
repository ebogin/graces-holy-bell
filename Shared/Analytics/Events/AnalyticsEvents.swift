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

    func sessionStarted(entryPoint: EntryPoint, timeOfDay: String, dayOfWeek: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("session_started", [
            "entry_point": .string(entryPoint.rawValue),
            "time_of_day_bucket": .string(timeOfDay),
            "day_of_week": .string(dayOfWeek)
        ], at: timestamp)
    }

    func prayerLogged(prayerIndexInSession: Int, sinceLastPrayerBucket: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("prayer_logged", [
            "prayer_index_in_session": .int(prayerIndexInSession),
            "since_last_prayer_bucket": .string(sinceLastPrayerBucket)
        ], at: timestamp)
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

    // MARK: - Amen Alarm / notifications

    func amenAlarmSet(at timestamp: Date = Date()) -> AnalyticsEvent {
        event("amen_alarm_set", at: timestamp)
    }

    func amenAlarmFired(timeOfDay: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("amen_alarm_fired", ["time_of_day_bucket": .string(timeOfDay)], at: timestamp)
    }

    func notificationTapped(timeOfDay: String, at timestamp: Date = Date()) -> AnalyticsEvent {
        event("notification_tapped", ["time_of_day_bucket": .string(timeOfDay)], at: timestamp)
    }

    // MARK: - Watch-only

    func prayerLogViewed(at timestamp: Date = Date()) -> AnalyticsEvent {
        event("prayer_log_viewed", at: timestamp)
    }
}
