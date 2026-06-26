import XCTest
@testable import Graces_Holy_Bell

/// Phase 1a — the thin `Analytics` seam.
///
/// These tests pin the contract that all app code (and, later, the PostHog
/// transport) depends on: a plain-value event that survives being queued and
/// re-tagged, a shipping no-op transport, and a recording spy for later phases.
final class AnalyticsAbstractionTests: XCTestCase {

    // MARK: - AnalyticsEvent value semantics

    func test_event_preservesNameAndProperties() {
        let event = AnalyticsEvent(
            name: "session_started",
            properties: [
                "time_of_day_bucket": .string("morning"),
                "prayer_index_in_session": .int(3),
                "session_value_high": .bool(true)
            ],
            deviceSource: .phone
        )

        XCTAssertEqual(event.name, "session_started")
        XCTAssertEqual(event.properties["time_of_day_bucket"], .string("morning"))
        XCTAssertEqual(event.properties["prayer_index_in_session"], .int(3))
        XCTAssertEqual(event.properties["session_value_high"], .bool(true))
        XCTAssertEqual(event.deviceSource, .phone)
    }

    func test_event_defaultsToEmptyPropertiesAndNowTimestamp() {
        let before = Date()
        let event = AnalyticsEvent(name: "app_opened", deviceSource: .watch)
        let after = Date()

        XCTAssertTrue(event.properties.isEmpty)
        XCTAssertEqual(event.deviceSource, .watch)
        XCTAssertGreaterThanOrEqual(event.captureTimestamp, before)
        XCTAssertLessThanOrEqual(event.captureTimestamp, after)
    }

    func test_event_isEquatable() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let a = AnalyticsEvent(name: "prayer_logged",
                               properties: ["k": .int(1)],
                               deviceSource: .watch,
                               captureTimestamp: t)
        let b = AnalyticsEvent(name: "prayer_logged",
                               properties: ["k": .int(1)],
                               deviceSource: .watch,
                               captureTimestamp: t)
        XCTAssertEqual(a, b)
    }

    func test_deviceSource_rawValuesMatchTaxonomy() {
        XCTAssertEqual(DeviceSource.phone.rawValue, "phone")
        XCTAssertEqual(DeviceSource.watch.rawValue, "watch")
    }

    // MARK: - NoOpAnalytics (shipping default)

    func test_noOpAnalytics_acceptsEventsWithoutEffect() {
        let analytics: Analytics = NoOpAnalytics()
        // Must not crash and must produce no observable effect.
        analytics.capture(AnalyticsEvent(name: "app_installed", deviceSource: .phone))
        analytics.capture(AnalyticsEvent(name: "app_opened", deviceSource: .phone))
    }

    // MARK: - SpyAnalytics (test double for later phases)

    func test_spyAnalytics_recordsEventsInOrder() {
        let spy = SpyAnalytics()
        spy.capture(AnalyticsEvent(name: "first", deviceSource: .phone))
        spy.capture(AnalyticsEvent(name: "second", deviceSource: .watch))

        XCTAssertEqual(spy.captured.map(\.name), ["first", "second"])
        XCTAssertEqual(spy.captured.map(\.deviceSource), [.phone, .watch])
    }
}

/// In-test recording transport. Lives in the test target only — never shipped.
final class SpyAnalytics: Analytics {
    private(set) var captured: [AnalyticsEvent] = []
    func capture(_ event: AnalyticsEvent) { captured.append(event) }
}
