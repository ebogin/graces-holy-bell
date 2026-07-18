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

    /// Tail of the update chain. `Activity.update` is async and unstructured
    /// `Task`s complete in no particular order — with a rapid run of prayers
    /// (10+ slider fires) an older update could land *after* the newest one,
    /// leaving the Lock Screen timer anchored to a stale prayer until the next
    /// state change ("off-sync and won't re-sync"). Chaining each update behind
    /// the previous one guarantees the latest state always applies last.
    private var updateTask: Task<Void, Never>?

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

        // Drop a tracked activity the system or the user already tore down
        // (dismissed from the Lock Screen, 8-hour system limit) — updating it
        // is a silent no-op, so fall through and request a fresh one instead.
        if let tracked = activity,
           tracked.activityState == .ended || tracked.activityState == .dismissed {
            activity = nil
        }

        if let activity {
            let previous = updateTask
            updateTask = Task {
                await previous?.value
                await activity.update(content)
            }
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
        // stragglers from a crashed run can't linger on the Lock Screen. Ends
        // chain behind pending updates so a stale in-flight update can't lose
        // to the end (or vice versa).
        let previous = updateTask
        updateTask = Task {
            await previous?.value
            for stale in Activity<PrayerActivityAttributes>.activities {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
