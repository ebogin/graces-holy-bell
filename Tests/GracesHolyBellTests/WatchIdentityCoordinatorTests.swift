import XCTest
@testable import Graces_Holy_Bell

/// Phase 1b — the Watch pending queue.
///
/// Guarantees the core invariant: the Watch transmits **nothing** until it holds
/// the canonical `install_id`. Until then events are queued; on adoption they
/// flush in order, re-tagged with the canonical id, with their true capture
/// time preserved. (The transport is an injected port — the real WCSession
/// wiring is the deferred, separately-approved sub-step.)
final class WatchIdentityCoordinatorTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_500)

    func test_capturesBeforeResolution_areQueuedAndNotSent() {
        let sender = FakeEventSender()
        let coordinator = WatchIdentityCoordinator(sender: sender)

        coordinator.capture(AnalyticsEvent(name: "prayer_logged", deviceSource: .watch))
        coordinator.capture(AnalyticsEvent(name: "session_ended", deviceSource: .watch))

        XCTAssertTrue(sender.sent.isEmpty, "nothing may transmit before the id resolves")
        XCTAssertEqual(coordinator.pendingCount, 2)
        XCTAssertNil(coordinator.canonicalID)
    }

    func test_adoptingID_flushesQueueInOrderWithCanonicalID() {
        let sender = FakeEventSender()
        let coordinator = WatchIdentityCoordinator(sender: sender)

        coordinator.capture(AnalyticsEvent(name: "first", deviceSource: .watch, captureTimestamp: t0))
        coordinator.capture(AnalyticsEvent(name: "second", deviceSource: .watch, captureTimestamp: t1))

        coordinator.adoptCanonicalID("canonical-id")

        XCTAssertEqual(sender.sent.map(\.event.name), ["first", "second"], "FIFO order")
        XCTAssertEqual(sender.sent.map(\.installID), ["canonical-id", "canonical-id"])
        XCTAssertEqual(coordinator.pendingCount, 0)
        XCTAssertEqual(coordinator.canonicalID, "canonical-id")
    }

    func test_flush_preservesTrueCaptureTimestamps() {
        let sender = FakeEventSender()
        let coordinator = WatchIdentityCoordinator(sender: sender)
        coordinator.capture(AnalyticsEvent(name: "e", deviceSource: .watch, captureTimestamp: t0))

        coordinator.adoptCanonicalID("id")

        XCTAssertEqual(sender.sent.first?.event.captureTimestamp, t0,
                       "events must keep their real capture time, not be restamped at flush")
    }

    func test_flush_preservesOriginatingDeviceSource() {
        let sender = FakeEventSender()
        let coordinator = WatchIdentityCoordinator(sender: sender)
        coordinator.capture(AnalyticsEvent(name: "e", deviceSource: .watch))

        coordinator.adoptCanonicalID("id")

        XCTAssertEqual(sender.sent.first?.event.deviceSource, .watch,
                       "origin device must never be overwritten to phone")
    }

    func test_capturesAfterResolution_sendImmediately() {
        let sender = FakeEventSender()
        let coordinator = WatchIdentityCoordinator(sender: sender)
        coordinator.adoptCanonicalID("id")

        coordinator.capture(AnalyticsEvent(name: "live", deviceSource: .watch))

        XCTAssertEqual(sender.sent.count, 1)
        XCTAssertEqual(sender.sent.first?.event.name, "live")
        XCTAssertEqual(sender.sent.first?.installID, "id")
        XCTAssertEqual(coordinator.pendingCount, 0)
    }
}

/// Records what the coordinator transmits, with the id it was tagged with.
final class FakeEventSender: AnalyticsEventSender {
    private(set) var sent: [(event: AnalyticsEvent, installID: String)] = []
    func send(_ event: AnalyticsEvent, installID: String) {
        sent.append((event, installID))
    }
}
