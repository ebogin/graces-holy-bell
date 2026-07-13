import XCTest
@testable import Graces_Holy_Bell

/// The transport seam that lets the real PostHog transport be swapped in after
/// consent is granted, without rebuilding `AnalyticsService`.
final class SwappableAnalyticsTests: XCTestCase {

    private func event(_ name: String) -> AnalyticsEvent {
        AnalyticsEvent(name: name, deviceSource: .phone)
    }

    func test_capture_delegatesToInitialTransport() {
        let initial = SpyAnalytics()
        let swappable = SwappableAnalytics(initial: initial)

        swappable.capture(event("app_opened"))

        XCTAssertEqual(initial.captured.map(\.name), ["app_opened"])
    }

    func test_swap_delegatesSubsequentCapturesToTheNewTransport() {
        let initial = SpyAnalytics()
        let replacement = SpyAnalytics()
        let swappable = SwappableAnalytics(initial: initial)

        swappable.capture(event("before_swap"))
        swappable.swap(to: replacement)
        swappable.capture(event("after_swap"))

        XCTAssertEqual(initial.captured.map(\.name), ["before_swap"], "old transport must not see later events")
        XCTAssertEqual(replacement.captured.map(\.name), ["after_swap"])
    }
}
