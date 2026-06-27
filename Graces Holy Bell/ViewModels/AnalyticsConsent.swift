import Foundation
import Observation

/// Observable wrapper over the persisted analytics-consent choice, for SwiftUI.
///
/// One source of truth behind both the Settings toggle and the first-launch EU
/// opt-in banner. On creation it applies the geo-gated default once (non-EU
/// opt-out / EU opt-in) without overwriting an explicit prior choice.
@Observable
final class AnalyticsConsent {

    @ObservationIgnored private let store: ConsentStore

    /// Current posture (granted / denied / pending).
    private(set) var state: ConsentState

    init(store: ConsentStore = UserDefaultsConsentStore(), locale: Locale = .current) {
        self.store = store
        self.state = RegionConsentPolicy.ensureInitialState(in: store, locale: locale)
    }

    /// Whether transmission is currently allowed.
    var isGranted: Bool { state == .granted }

    /// Whether the first-launch EU opt-in banner should be presented.
    var needsConsentDecision: Bool { state == .pending }

    /// Settings-toggle binding: on = granted, off = denied.
    var enabled: Bool {
        get { state == .granted }
        set { update(newValue ? .granted : .denied) }
    }

    /// Banner action: allow analytics.
    func grant() { update(.granted) }

    /// Banner action: decline analytics.
    func deny() { update(.denied) }

    private func update(_ newState: ConsentState) {
        state = newState
        store.consentState = newState
    }
}
