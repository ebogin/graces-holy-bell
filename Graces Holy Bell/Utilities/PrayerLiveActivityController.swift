import ActivityKit
import Foundation
import os

/// Owns the prayer-timer Live Activity on the phone.
///
/// `sync(with:enabled:)` is idempotent — call it after any state change
/// (prayer logged, session cleared, Watch merge, settings toggle, foreground)
/// and it starts, updates, or ends the activity to match the session state.
@MainActor
final class PrayerLiveActivityController {

    private var activity: Activity<PrayerActivityAttributes>?

    private let logger = Logger(subsystem: "Boginfactory.Graces-Holy-Bell", category: "liveActivity")

    init() {
        // Re-adopt an activity left over from a previous run (the system keeps
        // them alive across app restarts). The first sync() reconciles it.
        activity = Activity<PrayerActivityAttributes>.activities.first
    }

    /// Reconciles the Live Activity with the current session state.
    func sync(with viewModel: SessionViewModel, enabled: Bool) {
        guard enabled,
              viewModel.appState == .active,
              let lastPrayerAt = viewModel.lastPrayerTimestamp,
              let sessionStartedAt = viewModel.sessionStartedAt else {
            endActivity()
            return
        }

        let state = PrayerActivityAttributes.ContentState(
            lastPrayerAt: lastPrayerAt,
            sessionStartedAt: sessionStartedAt,
            prayerCount: viewModel.sortedEntries.count
        )
        let content = ActivityContent(state: state, staleDate: nil)

        if let activity {
            Task { await activity.update(content) }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            activity = try Activity.request(
                attributes: PrayerActivityAttributes(),
                content: content,
                pushType: nil
            )
        } catch {
            // Requesting from the background (e.g. a Watch merge waking us) is
            // rejected by the system — the next foreground sync() catches up.
            logger.info("Live Activity request failed: \(error, privacy: .public)")
        }
    }

    private func endActivity() {
        activity = nil
        // End every activity for our attributes, not just the tracked one, so
        // stragglers from a crashed run can't linger on the Lock Screen.
        for stale in Activity<PrayerActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
