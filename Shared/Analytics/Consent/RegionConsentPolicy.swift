import Foundation

/// Decides the default consent posture for the user's region — on-device, from
/// the device Region setting only (no IP, no location permission).
///
/// Opt-in jurisdictions (EU/EEA + UK, where ePrivacy/GDPR require opt-in even for
/// pseudonymous analytics) default to `pending`; everywhere else defaults to
/// `granted` (opt-out, default-on, disclosed). An unknown region is treated
/// strictly as opt-in.
enum RegionConsentPolicy {

    /// EU + EEA + UK ISO 3166-1 alpha-2 codes.
    static let optInRegionCodes: Set<String> = [
        // EU
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR",
        "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
        "SI", "ES", "SE",
        // EEA (non-EU)
        "IS", "LI", "NO",
        // UK (UK GDPR)
        "GB"
    ]

    /// The default posture for a region code (case-insensitive). `nil` → strict.
    static func defaultState(regionCode: String?) -> ConsentState {
        guard let code = regionCode?.uppercased() else { return .pending }
        return optInRegionCodes.contains(code) ? .pending : .granted
    }

    /// The default posture for the current device region.
    static func defaultStateForCurrentRegion(locale: Locale = .current) -> ConsentState {
        defaultState(regionCode: locale.region?.identifier)
    }

    /// Applies the region default on first launch only; never overwrites an
    /// explicit prior choice. Returns the effective state.
    @discardableResult
    static func ensureInitialState(in store: ConsentStore, locale: Locale = .current) -> ConsentState {
        if let existing = store.consentState { return existing }
        let initial = defaultStateForCurrentRegion(locale: locale)
        store.consentState = initial
        return initial
    }
}
