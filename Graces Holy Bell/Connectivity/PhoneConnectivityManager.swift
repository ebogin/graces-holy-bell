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

    /// Builds a SyncedSessionState from the current ViewModel and sends it to the Watch.
    /// Called after every ViewModel mutation.
    @MainActor
    func sendStateToWatch() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired else { return }
        guard let viewModel else { return }

        let entries = viewModel.sortedEntries.map { entry in
            SyncedEntry(
                timestamp: entry.timestamp,
                sequenceIndex: entry.sequenceIndex
            )
        }

        let state = SyncedSessionState(
            appState: viewModel.appState == .active ? "active" : "idle",
            entries: entries,
            sessionStoppedAt: viewModel.currentSession?.stoppedAt,
            hasExistingLog: viewModel.hasExistingLog
        )

        try? WCSession.default.updateApplicationContext(state.toDictionary())
    }

    // MARK: - Handle Watch Actions

    /// Processes an action received from the Watch.
    @MainActor
    private func handleAction(_ action: String) {
        guard let viewModel else { return }

        switch action {
        case "START":
            viewModel.startNewSession()
        case "PRAY":
            viewModel.logPrayer()
        case "STOP":
            viewModel.stopSession()
        default:
            break
        }

        sendStateToWatch()
    }

    /// Builds the current state snapshot for sending back as a reply.
    @MainActor
    private func currentStateDictionary() -> [String: Any] {
        guard let viewModel else { return [:] }

        let entries = viewModel.sortedEntries.map { entry in
            SyncedEntry(timestamp: entry.timestamp, sequenceIndex: entry.sequenceIndex)
        }
        let state = SyncedSessionState(
            appState: viewModel.appState == .active ? "active" : "idle",
            entries: entries,
            sessionStoppedAt: viewModel.currentSession?.stoppedAt,
            hasExistingLog: viewModel.hasExistingLog
        )
        return state.toDictionary()
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
        if let action = message["action"] as? String {
            Task { @MainActor in
                self.handleAction(action)
                replyHandler(self.currentStateDictionary())
            }
        } else {
            replyHandler([:])
        }
    }

    /// Receives immediate messages from the Watch — without reply handler.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        if let action = message["action"] as? String {
            Task { @MainActor in
                self.handleAction(action)
            }
        }
    }

    /// Receives queued messages from the Watch (delivered even when iPhone app was not running).
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        if let action = userInfo["action"] as? String {
            Task { @MainActor in
                self.handleAction(action)
            }
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
