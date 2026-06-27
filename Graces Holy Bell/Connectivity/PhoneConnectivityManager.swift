import Foundation
import WatchConnectivity

/// iPhone-side WatchConnectivity manager.
///
/// Responsibilities:
/// - Receives actions from the Watch (PRAY, STOP, START) and forwards them to the SessionViewModel.
/// - Sends the current app state to the Watch after every state change.
///
/// This class is the bridge between the Watch and the iPhone's business logic.
/// The ViewModel never knows about WatchConnectivity — it just gets called.
///
/// NOT isolated to @MainActor — WCSession requires its delegate callbacks
/// on a background serial queue. ViewModel calls are dispatched to main explicitly.
final class PhoneConnectivityManager: NSObject {

    private var viewModel: SessionViewModel?
    var amenAlarmSettings: AmenAlarmSettings?

    /// Recently handled action ids — the Watch may deliver the same action
    /// twice when a sendMessage reply fails and it falls back to
    /// transferUserInfo. Only touched on the main actor (see handleAction).
    private var handledActionIDs: [String] = []

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Connects this manager to the ViewModel.
    /// Called once during app setup after the ViewModel is created.
    @MainActor
    func configure(with viewModel: SessionViewModel) {
        self.viewModel = viewModel
        sendStateToWatch()
    }

    /// Sends the current ViewModel state to the Watch.
    /// Called after every ViewModel mutation.
    @MainActor
    func sendStateToWatch() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired else { return }
        guard let state = makeState() else { return }

        try? WCSession.default.updateApplicationContext(state.toDictionary())
    }

    /// Builds a SyncedSessionState snapshot from the current ViewModel.
    @MainActor
    private func makeState() -> SyncedSessionState? {
        guard let viewModel else { return nil }

        let entries = viewModel.sortedEntries.map { entry in
            SyncedEntry(
                timestamp: entry.timestamp,
                sequenceIndex: entry.sequenceIndex
            )
        }

        // Compute the Amen Alarm fire time for the watch, if applicable.
        // Fire time = lastPrayerTimestamp + alarmDuration, but only when:
        //   - The session is active
        //   - The watch alarm toggle is on
        // A past fire time is still sent so the watch slider keeps blinking AMEN!
        // after a resync — notification scheduling guards against past dates itself.
        let amenAlarmFireAt: Date? = {
            guard let settings = amenAlarmSettings,
                  settings.watchEnabled,
                  viewModel.appState == .active,
                  let lastTimestamp = viewModel.lastPrayerTimestamp else { return nil }
            return lastTimestamp.addingTimeInterval(settings.duration.rawValue)
        }()

        return SyncedSessionState(
            appState: viewModel.appState == .active ? "active" : "idle",
            entries: entries,
            amenAlarmFireAt: amenAlarmFireAt
        )
    }

    // MARK: - Handle Watch Actions

    /// Processes an action message received from the Watch, ignoring
    /// duplicate deliveries of the same action id.
    @MainActor
    private func handleAction(_ message: [String: Any]) {
        guard let viewModel,
              let action = message["action"] as? String else { return }

        if let id = message["id"] as? String {
            guard !handledActionIDs.contains(id) else { return }
            handledActionIDs.append(id)
            if handledActionIDs.count > 32 {
                handledActionIDs.removeFirst()
            }
        }

        // Analytics (additive): this action originated on the Watch, so tag the
        // events the ViewModel emits with device_source = watch, then restore.
        viewModel.analytics?.deviceSource = .watch
        defer { viewModel.analytics?.deviceSource = .phone }

        switch action {
        case "START":
            viewModel.startNewSession()
        case "PRAY":
            viewModel.logPrayer()
        case "CLEAR_LOG":
            viewModel.clearLog()
        default:
            break
        }
        // No explicit sendStateToWatch() here: each ViewModel mutation already
        // triggers one via onStateChanged, and message senders get the fresh
        // state back in their reply.
    }

    /// Builds the current state snapshot for sending back as a reply.
    @MainActor
    private func currentStateDictionary() -> [String: Any] {
        makeState()?.toDictionary() ?? [:]
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {

    /// Called when the WCSession activation completes.
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.sendStateToWatch()
        }
    }

    /// Required on iOS: called when the current Watch becomes inactive (e.g., switching watches).
    func sessionDidBecomeInactive(_ session: WCSession) {
        // No action needed
    }

    /// Required on iOS: called after Watch switch completes. Must reactivate.
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    /// Receives immediate messages from the Watch — with reply handler.
    /// Sends back the updated state so the Watch can apply it immediately.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            self.handleAction(message)
            replyHandler(self.currentStateDictionary())
        }
    }

    /// Receives immediate messages from the Watch — without reply handler.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.handleAction(message)
        }
    }

    /// Receives queued messages from the Watch (delivered even when iPhone app was not running).
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            // Analytics proxies (e.g. prayer_log_viewed) ride the same queue but
            // carry a distinct key, so route them to analytics, not the action path.
            if let event = userInfo["analyticsEvent"] as? String {
                self.handleProxiedAnalytics(event: event, userInfo: userInfo)
            } else {
                self.handleAction(userInfo)
            }
        }
    }

    /// Forwards a Watch-originated analytics event to the phone's transport,
    /// preserving its origin (`watch`) and true capture timestamp.
    @MainActor
    private func handleProxiedAnalytics(event: String, userInfo: [String: Any]) {
        let timestamp = (userInfo["timestamp"] as? Date) ?? Date()
        switch event {
        case "prayer_log_viewed":
            viewModel?.analytics?.recordWatchPrayerLogViewed(at: timestamp)
        default:
            break
        }
    }

    /// Sends fresh state when the Watch app becomes reachable.
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            Task { @MainActor in
                self.sendStateToWatch()
            }
        }
    }
}
