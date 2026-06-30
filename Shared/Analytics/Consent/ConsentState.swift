import Foundation

/// The user's analytics-consent posture. Rides on events as `consent_state` and
/// gates transmission.
///
/// - `granted`: transmission allowed (non-EU default — opt-out, disclosed).
/// - `denied`: the user opted out.
/// - `pending`: EU/EEA/unknown default — awaiting opt-in; nothing is transmitted.
enum ConsentState: String {
    case granted
    case denied
    case pending
}
