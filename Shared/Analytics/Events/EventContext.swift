import Foundation

/// The Amen Alarm's enabled state across devices (§2 `amen_alarm_status`).
enum AmenAlarmStatus: String {
    case phone, watch, both, off

    static func from(phoneEnabled: Bool, watchEnabled: Bool) -> AmenAlarmStatus {
        switch (phoneEnabled, watchEnabled) {
        case (true, true):   return .both
        case (true, false):  return .phone
        case (false, true):  return .watch
        case (false, false): return .off
        }
    }
}

/// Maps a chosen Amen Alarm interval (seconds) to its `amen_alarm_duration_setting`
/// label. Kept independent of the iPhone-only `AmenAlarmDuration` enum so it
/// compiles in `Shared/`. The 30-second dev/test interval is tagged so it never
/// pollutes real buckets.
enum AmenAlarmDurationLabel {
    static func label(forSeconds seconds: TimeInterval) -> String {
        switch Int(seconds) {
        case 30:   return "30s-test"
        case 1800: return "30m"
        case 2700: return "45m"
        case 3600: return "1h"
        case 4500: return "1h15"
        case 5400: return "1h30"
        case 6300: return "1h45"
        case 7200: return "2h"
        default:   return "custom"
        }
    }
}

/// Cross-device context attached to every event (§2). Anonymous only.
struct EventContext {
    /// Var (not let) so the service can stamp the originating device per emit —
    /// e.g. tagging `watch` for a prayer the phone processed on the Watch's behalf.
    var deviceSource: DeviceSource
    let alarmStatus: AmenAlarmStatus
    let alarmDurationSeconds: TimeInterval
    let environment: AppEnvironment

    init(
        deviceSource: DeviceSource,
        alarmStatus: AmenAlarmStatus,
        alarmDurationSeconds: TimeInterval,
        environment: AppEnvironment = LiveAppEnvironment()
    ) {
        self.deviceSource = deviceSource
        self.alarmStatus = alarmStatus
        self.alarmDurationSeconds = alarmDurationSeconds
        self.environment = environment
    }

    /// The context properties carried on every event.
    func baseProperties() -> [String: AnalyticsValue] {
        [
            "device_source": .string(deviceSource.rawValue),
            "amen_alarm_status": .string(alarmStatus.rawValue),
            "amen_alarm_duration_setting": .string(AmenAlarmDurationLabel.label(forSeconds: alarmDurationSeconds)),
            "app_version": .string(environment.appVersion),
            "os_version": .string(environment.osVersion)
        ]
    }
}
