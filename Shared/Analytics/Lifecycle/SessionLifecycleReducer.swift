import Foundation

/// The most recent persisted session's state, sampled at app launch.
struct SessionLaunchSnapshot {
    /// Timestamp of the most recent prayer in the session.
    let lastPrayerAt: Date
    /// Raw count of PRAY taps logged so far (not rapid-tap-collapsed).
    let prayersSoFar: Int
    /// Whether analytics has already emitted a terminal event for this session
    /// (a normal `session_ended` or a prior `session_abandoned`). Enforces the
    /// no-double-close rule.
    let alreadyClosed: Bool
}

/// Decision produced by evaluating a persisted session at launch.
enum SessionLifecycleDecision: Equatable {
    case none
    /// Emit a backdated `session_abandoned` with `reason = forgotten_timer`.
    case synthesizeForgottenTimerAbandon(at: Date, prayersSoFar: Int)
}

/// Pure reducer for next-launch session-lifecycle synthesis.
///
/// The app cannot fire events while suspended or force-quit, so a "forgotten
/// timer" — a prayer timer left running past 12h — is detected on the next
/// launch and synthesized, backdated to its true crossing time (last prayer +
/// 12h), not stamped at re-open. No-double-close: a session already terminated
/// in analytics is never closed again, so a later prayer simply starts fresh.
enum SessionLifecycleReducer {

    /// A prayer timer left running this long is treated as forgotten (a user who
    /// walked away), not churn or a UX failure.
    static let forgottenTimerThreshold: TimeInterval = 12 * 3600

    static func evaluateAtLaunch(_ snapshot: SessionLaunchSnapshot, now: Date) -> SessionLifecycleDecision {
        guard !snapshot.alreadyClosed else { return .none }

        let elapsed = now.timeIntervalSince(snapshot.lastPrayerAt)
        guard elapsed >= forgottenTimerThreshold else { return .none }

        let backdate = snapshot.lastPrayerAt.addingTimeInterval(forgottenTimerThreshold)
        return .synthesizeForgottenTimerAbandon(at: backdate, prayersSoFar: snapshot.prayersSoFar)
    }
}
