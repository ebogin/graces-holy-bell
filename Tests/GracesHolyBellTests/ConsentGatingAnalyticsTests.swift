import XCTest
@testable import Graces_Holy_Bell

/// Phase 3a — the transmission gate. Events flow only when consent is granted.
final class ConsentGatingAnalyticsTests: XCTestCase {

    private func event(_ name: String) -> AnalyticsEvent {
        AnalyticsEvent(name: name, deviceSource: .phone)
    }

    func test_granted_forwardsToWrappedTransport() {
        let spy = SpyAnalytics()
        let gate = ConsentGatingAnalytics(wrapping: spy) { true }
        gate.capture(event("app_opened"))
        XCTAssertEqual(spy.captured.map(\.name), ["app_opened"])
    }

    func test_denied_dropsEvents() {
        let spy = SpyAnalytics()
        let gate = ConsentGatingAnalytics(wrapping: spy) { false }
        gate.capture(event("app_opened"))
        XCTAssertTrue(spy.captured.isEmpty, "no transmission without consent")
    }

    func test_gateIsCheckedPerEvent() {
        let spy = SpyAnalytics()
        var allowed = false
        let gate = ConsentGatingAnalytics(wrapping: spy) { allowed }

        gate.capture(event("before")) // dropped
        allowed = true
        gate.capture(event("after"))  // forwarded

        XCTAssertEqual(spy.captured.map(\.name), ["after"], "pre-consent events are not buffered")
    }
}
