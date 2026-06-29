import Foundation
import WatchConnectivity

/// iPhone-side WatchConnectivity manager.
///
/// Protocol (Stage 3):
/// - Receives event / clear / snapshot messages from the Watch and merges via SessionViewModel.
/// - Sends the current SyncSnapshot to the Watch after every state change and on activation.
///
/// The merge is idempotent and commutative — duplicate deliveries are safe.
/// Analytics are NEVER emitted here; each prayer is counted exactly once at its origin.
///
/// NOT isolated to @MainActor — WCSession requires delegate callbacks on a background serial
/// queue. ViewModel calls are dispatched to main explicitly.
final class PhoneConnectivityManager: NSObject {

    private var viewModel: SessionViewModel?
    var amenAlarmSettings: AmenAlarmSettings?

    // Messages can arrive from the Watch on a cold launch (queued transferUserInfo /
    // applicationContext) *before* ContentView's .task wires up the ViewModel via
    // configure(with:). Buffer them here and replay in FIFO order once configured,
    // so re-launching the phone never drops prayers the Watch logged while it was dead.
    // All accesses are on the MainActor.
    @MainActor private var pendingUserInfos: [[String: Any]] = []
    @MainActor private var pendingSnapshots: [SyncSnapshot] = []

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    @MainActor
    func configure(with viewModel: SessionViewModel) {
        self.viewModel = viewModel
        for info in pendingUserInfos { handleUserInfo(info) }
        pendingUserInfos.removeAll()
        for snapshot in pendingSnapshots { handleSnapshot(snapshot) }
        pendingSnapshots.removeAll()
        sendSnapshotToWatch()
    }

    // MARK: - Send snapshot to Watch

    @MainActor
    func sendSnapshotToWatch() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              let viewModel else { return }
        let snapshot = viewModel.makeSnapshot(amenAlarmSettings: amenAlarmSettings)
        let dict = snapshot.toDictionary()
        try? WCSession.default.updateApplicationContext(dict)
    }

    @MainActor
    private func snapshotDictionary() -> [String: Any] {
        viewModel?.makeSnapshot(amenAlarmSettings: amenAlarmSettings).toDictionary() ?? [:]
    }

    // MARK: - Handle incoming Watch messages

    @MainActor
    private func handleUserInfo(_ userInfo: [String: Any]) {
        guard let viewModel else {
            pendingUserInfos.append(userInfo)
            return
        }

        // Analytics proxy (prayer_log_viewed from Watch)
        if let timestamp = WatchAnalyticsProxy.isPrayerLogViewed(userInfo) {
            viewModel.analytics?.recordWatchPrayerLogViewed(at: timestamp)
            return
        }

        // Single event from Watch
        if let msg = EventMessage.fromUserInfo(userInfo) {
            let snapshot = SyncSnapshot(events: [msg.event], lastClearedAt: nil, amenAlarmFireAt: nil)
            viewModel.mergeIncoming(snapshot: snapshot)
            return
        }

        // Clear from Watch
        if let msg = ClearMessage.fromUserInfo(userInfo) {
            let snapshot = SyncSnapshot(events: [], lastClearedAt: msg.clearedAt, amenAlarmFireAt: nil)
            viewModel.mergeIncoming(snapshot: snapshot)
            return
        }
    }

    @MainActor
    private func handleSnapshot(_ snapshot: SyncSnapshot) {
        guard let viewModel else {
            pendingSnapshots.append(snapshot)
            return
        }
        viewModel.mergeIncoming(snapshot: snapshot)
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.sendSnapshotToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    /// Receives a snapshot sent by the Watch via sendMessage (reachable path).
    /// Merges the snapshot and replies with the phone's own updated snapshot.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            if let snapshot = SyncSnapshot.fromDictionary(message) {
                self.handleSnapshot(snapshot)
            }
            replyHandler(self.snapshotDictionary())
        }
    }

    /// Receives a snapshot sent by the Watch via sendMessage (no reply needed).
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            if let snapshot = SyncSnapshot.fromDictionary(message) {
                self.handleSnapshot(snapshot)
            }
        }
    }

    /// Receives event/clear/analytics payloads sent via transferUserInfo (offline-safe queue).
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            self.handleUserInfo(userInfo)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            Task { @MainActor in
                self.sendSnapshotToWatch()
            }
        }
    }
}
