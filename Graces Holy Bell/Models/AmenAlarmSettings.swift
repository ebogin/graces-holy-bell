import Foundation
import Observation

// MARK: - Amen Alarm Duration Options

enum AmenAlarmDuration: TimeInterval, CaseIterable, Identifiable {
    case testThirtySeconds = 30
    case thirtyMins    = 1800
    case fortyFiveMins = 2700
    case oneHour       = 3600
    case oneHr15       = 4500
    case oneHr30       = 5400
    case oneHr45       = 6300
    case twoHours      = 7200

    var id: TimeInterval { rawValue }

    var label: String {
        switch self {
        case .testThirtySeconds: return "30 sec"
        case .thirtyMins:    return "30 mins"
        case .fortyFiveMins: return "45 mins"
        case .oneHour:       return "1 hour"
        case .oneHr15:       return "1 hr 15 mins"
        case .oneHr30:       return "1 hr 30 mins"
        case .oneHr45:       return "1 hr 45 mins"
        case .twoHours:      return "2 hours"
        }
    }
}

// MARK: - Amen Alarm Settings

/// Persisted user preferences for the Amen Alarm feature.
///
/// Backed by UserDefaults — changes are durable across launches.
/// Defaults: duration 1 hr 30 min, phone OFF, watch OFF.
@Observable
final class AmenAlarmSettings {

    /// Invoked after any setting changes — used to reschedule the phone alarm
    /// and resync the Watch immediately instead of waiting for the next PRAY slide.
    @ObservationIgnored var onChange: (() -> Void)?

    /// The alarm duration (seconds since last prayer).
    var duration: AmenAlarmDuration {
        didSet {
            UserDefaults.standard.set(duration.rawValue, forKey: Keys.duration)
            onChange?()
        }
    }

    /// Whether to vibrate the phone when the alarm fires.
    var phoneEnabled: Bool {
        didSet {
            UserDefaults.standard.set(phoneEnabled, forKey: Keys.phoneEnabled)
            onChange?()
        }
    }

    /// Whether to vibrate the watch when the alarm fires.
    var watchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(watchEnabled, forKey: Keys.watchEnabled)
            onChange?()
        }
    }

    /// Whether the alarm also plays a loud clanging bell (notification sound
    /// in the background, looping in-app audio during the AMEN takeover).
    var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled)
            onChange?()
        }
    }

    init() {
        // Load persisted values, falling back to defaults
        let rawDuration = UserDefaults.standard.double(forKey: Keys.duration)
        self.duration = AmenAlarmDuration(rawValue: rawDuration) ?? .oneHr30

        if UserDefaults.standard.object(forKey: Keys.phoneEnabled) != nil {
            self.phoneEnabled = UserDefaults.standard.bool(forKey: Keys.phoneEnabled)
        } else {
            self.phoneEnabled = false
        }

        if UserDefaults.standard.object(forKey: Keys.watchEnabled) != nil {
            self.watchEnabled = UserDefaults.standard.bool(forKey: Keys.watchEnabled)
        } else {
            self.watchEnabled = false
        }

        self.soundEnabled = UserDefaults.standard.bool(forKey: Keys.soundEnabled)
    }

    private enum Keys {
        static let duration     = "amenAlarm.duration"
        static let phoneEnabled = "amenAlarm.phoneEnabled"
        static let watchEnabled = "amenAlarm.watchEnabled"
        static let soundEnabled = "amenAlarm.soundEnabled"
    }
}
