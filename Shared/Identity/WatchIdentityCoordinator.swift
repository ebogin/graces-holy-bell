import Foundation

/// Transport port the Watch coordinator uses to actually transmit a resolved
/// event together with the canonical `install_id`.
///
/// In Phase 1 this is injected (a fake in tests). The real WCSession-backed
/// implementation that proxies through the phone's PostHog SDK is the deferred,
/// separately-approved wiring sub-step — keeping the coordinator's logic pure
/// and fully testable here.
protocol AnalyticsEventSender: AnyObject {
    func send(_ event: AnalyticsEvent, installID: String)
}

/// Watch-side identity gate + pending queue.
///
/// Core invariant: the Watch transmits **nothing** until it holds the canonical
/// `install_id`. Until then, captured events are buffered in FIFO order. On
/// adoption, the queue flushes in order, each event tagged with the canonical
/// id — its true `captureTimestamp` and originating `deviceSource` left
/// untouched, so late-delivered events land at the right time and `watch` is
/// never overwritten to `phone`.
final class WatchIdentityCoordinator {

    /// The canonical id once resolved; nil until then.
    private(set) var canonicalID: String?

    private var pending: [AnalyticsEvent] = []
    private let sender: AnalyticsEventSender

    init(sender: AnalyticsEventSender, canonicalID: String? = nil) {
        self.sender = sender
        self.canonicalID = canonicalID
    }

    /// Number of events buffered awaiting the canonical id.
    var pendingCount: Int { pending.count }

    /// Capture an event. Queued while no canonical id is held (nothing is
    /// transmitted); sent immediately once resolved.
    func capture(_ event: AnalyticsEvent) {
        guard let id = canonicalID else {
            pending.append(event)
            return
        }
        sender.send(event, installID: id)
    }

    /// Adopt the canonical `install_id` and flush the pending queue in FIFO
    /// order, each event tagged with that id. Safe to call once; subsequent
    /// captures go straight through.
    func adoptCanonicalID(_ id: String) {
        canonicalID = id
        let queued = pending
        pending.removeAll()
        for event in queued {
            sender.send(event, installID: id)
        }
    }
}
