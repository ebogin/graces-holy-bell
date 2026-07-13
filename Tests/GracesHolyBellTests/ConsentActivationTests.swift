import XCTest
@testable import Graces_Holy_Bell

/// The one-shot latch that activates the real analytics transport the first
/// time consent is seen as `.granted` — SDK-free, so it's testable with a
/// stub factory rather than the real `PostHogTransport`.
final class ConsentActivationTests: XCTestCase {

    func test_pending_neverCallsFactory() {
        let activation = ConsentActivation()
        let swappable = SwappableAnalytics(initial: SpyAnalytics())
        var factoryCalls = 0

        activation.activateIfGranted(.pending, swappable: swappable) {
            factoryCalls += 1
            return SpyAnalytics()
        }

        XCTAssertEqual(factoryCalls, 0)
    }

    func test_denied_neverCallsFactory() {
        let activation = ConsentActivation()
        let swappable = SwappableAnalytics(initial: SpyAnalytics())
        var factoryCalls = 0

        activation.activateIfGranted(.denied, swappable: swappable) {
            factoryCalls += 1
            return SpyAnalytics()
        }

        XCTAssertEqual(factoryCalls, 0)
    }

    func test_grantedOnFirstCall_callsFactoryOnceAndSwaps() {
        let activation = ConsentActivation()
        let initial = SpyAnalytics()
        let real = SpyAnalytics()
        let swappable = SwappableAnalytics(initial: initial)
        var factoryCalls = 0

        activation.activateIfGranted(.granted, swappable: swappable) {
            factoryCalls += 1
            return real
        }

        XCTAssertEqual(factoryCalls, 1)

        // Confirm the swap actually happened: captures now reach `real`, not `initial`.
        swappable.capture(AnalyticsEvent(name: "after_activation", deviceSource: .phone))
        XCTAssertTrue(initial.captured.isEmpty)
        XCTAssertEqual(real.captured.map(\.name), ["after_activation"])
    }

    func test_repeatedGrantedCalls_callFactoryExactlyOnce() {
        let activation = ConsentActivation()
        let swappable = SwappableAnalytics(initial: SpyAnalytics())
        var factoryCalls = 0

        activation.activateIfGranted(.granted, swappable: swappable) {
            factoryCalls += 1
            return SpyAnalytics()
        }
        activation.activateIfGranted(.granted, swappable: swappable) {
            factoryCalls += 1
            return SpyAnalytics()
        }
        activation.activateIfGranted(.granted, swappable: swappable) {
            factoryCalls += 1
            return SpyAnalytics()
        }

        XCTAssertEqual(factoryCalls, 1, "activation is a one-shot latch")
    }
}
