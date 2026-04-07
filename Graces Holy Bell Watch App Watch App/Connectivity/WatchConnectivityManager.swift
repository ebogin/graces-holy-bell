import Foundation
import WatchConnectivity
import Combine

/// Watch-side WatchConnectivity manager.
///
/// Responsibilities:
/// - Sends user actions (PRAY, STOP, START) to the iPhone for processing.
/// - Receives state updates from the iPhone and feeds them to the WatchSessionViewModel.
///
/// Uses `sendMessage` when the iPhone is reachable (instant delivery),
/// falls back to `transferUserInfo` when disconnected (queued, guaranteed delivery).
///
/// NOT isolated to @MainActor — WCSession requires its delegate callbacks
/// on a background serial queue. State updates are dispatched to the main thread explicitly.
final class WatchConnectivityManager: NSObject, ObservableObject {

    /// The latest state received from the iPhone.
    @Published var latestState: SyncedSessionState?

    /// Whether the iPhone is currently reachable for immediate communication.
    @Published var isReachable = false

    /// Whether the session has successfully activated.
    @Published var isActivated = false

    private let session: WCSession

    override init() {
        self.session = WCSession.default
        super.init()
        session.delegate = self
        session.activate()
    }

    /// Sends an action to the iPhone.
    ///
    /// Tries `sendMessage` first (instant). If iPhone is not reachable,
    /// falls back to `transferUserInfo` (queued, guaranteed delivery on reconnect).
    func sendAction(_ action: String) {
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = ["action": action]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: { [weak self] reply in
                // iPhone sent back updated state as the reply — apply it immediately
                if let state = SyncedSessionState.fromDictionary(reply) {
                    DispatchQueue.main.async {
                        self?.latestState = state
                    }
                }
            }) { error in
                // sendMessage failed — fall back to transferUserInfo
                WCSession.default.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isActivated = activationState == .activated
            self.isReachable = session.isReachable

            // Check for any existing application context from iPhone
            if !session.receivedApplicationContext.isEmpty {
                if let state = SyncedSessionState.fromDictionary(session.receivedApplicationContext) {
                    self.latestState = state
                }
            }
        }
    }

    /// Receives state updates pushed by the iPhone via `updateApplicationContext`.
    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        if let state = SyncedSessionState.fromDictionary(applicationContext) {
            DispatchQueue.main.async {
                self.latestState = state
            }
        }
    }

    /// Tracks whether iPhone is reachable for choosing send strategy.
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
}
