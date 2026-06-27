import Foundation

/// Persistence port for the user's consent choice.
///
/// `nil` means no explicit value has been resolved yet (first launch, before the
/// region default is applied).
protocol ConsentStore: AnyObject {
    var consentState: ConsentState? { get set }
}

/// UserDefaults-backed store on an injectable suite (tests never touch `.standard`).
final class UserDefaultsConsentStore: ConsentStore {
    private let defaults: UserDefaults
    private let key = "analytics.consent_state"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var consentState: ConsentState? {
        get { defaults.string(forKey: key).flatMap(ConsentState.init(rawValue:)) }
        set {
            if let value = newValue {
                defaults.set(value.rawValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
