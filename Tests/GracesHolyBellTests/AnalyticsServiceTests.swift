import XCTest
@testable import Graces_Holy_Bell

/// Phase 2d — the app-facing coordinator's derivation + emission.
final class AnalyticsServiceTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func service(_ spy: SpyAnalytics, store: AnalyticsStateStore) -> AnalyticsService {
        AnalyticsService(transport: spy, stateStore: store) {
            EventContext(
                deviceSource: .phone,
                alarmStatus: .off,
                alarmDurationSeconds: 5400,
                environment: StubAppEnvironment(appVersion: "1.0.0", osVersion: "26.4.0")
            )
        }
    }

    // MARK: - Launch

    func test_launch_firstRun_emitsInstalledThenOpened_andSetsInstallDate() {
        let spy = SpyAnalytics()
        let store = InMemoryAnalyticsStateStore()
        service(spy, store: store).recordLaunch(currentSessionStart: nil, lastPrayerAt: nil, prayersSoFar: 0, now: now)

        XCTAssertEqual(spy.captured.map(\.name), ["app_installed", "app_opened"])
        XCTAssertEqual(store.installDate, now)
        XCTAssertEqual(spy.captured.last?.properties["days_since_install"], .int(0))
    }

    func test_launch_repeatRun_emitsOnlyOpened_withDaysSinceInstall() {
        let spy = SpyAnalytics()
        let store = InMemoryAnalyticsStateStore()
        store.installDate = now.addingTimeInterval(-3 * 86_400)
        service(spy, store: store).recordLaunch(currentSessionStart: nil, lastPrayerAt: nil, prayersSoFar: 0, now: now)

        XCTAssertEqual(spy.captured.map(\.name), ["app_opened"])
        XCTAssertEqual(spy.captured.first?.properties["days_since_install"], .int(3))
    }

    func test_launch_staleSession_synthesizesBackdatedAbandon_andMarksClosed() throws {
        let spy = SpyAnalytics()
        let store = InMemoryAnalyticsStateStore()
        store.installDate = now.addingTimeInterval(-30 * 86_400)
        let start = now.addingTimeInterval(-20 * 3600)
        let lastPrayer = now.addingTimeInterval(-13 * 3600) // >12h ago

        service(spy, store: store).recordLaunch(
            currentSessionStart: start, lastPrayerAt: lastPrayer, prayersSoFar: 2, now: now
        )

        let abandon = try XCTUnwrap(spy.captured.first { $0.name == "session_abandoned" })
        XCTAssertEqual(abandon.properties["reason"], .string("forgotten_timer"))
        XCTAssertEqual(abandon.properties["prayers_so_far"], .int(2))
        XCTAssertEqual(abandon.captureTimestamp, lastPrayer.addingTimeInterval(12 * 3600))
        XCTAssertEqual(store.closedSessionStart, start)
    }

    // MARK: - Session lifecycle

    func test_sessionStarted_emitsStartedAndOpeningPrayer() {
        let spy = SpyAnalytics()
        service(spy, store: InMemoryAnalyticsStateStore()).recordSessionStarted(at: now)

        XCTAssertEqual(spy.captured.map(\.name), ["session_started", "prayer_logged"])
        let opening = spy.captured[1]
        XCTAssertEqual(opening.properties["prayer_index_in_session"], .int(1))
        XCTAssertNil(opening.properties["since_last_prayer_bucket"], "opening prayer has no predecessor")
    }

    func test_prayerLogged_bucketsTheGap() {
        let spy = SpyAnalytics()
        service(spy, store: InMemoryAnalyticsStateStore())
            .recordPrayerLogged(index: 2, sinceLast: 2000, at: now) // 2000s -> 30–45m

        XCTAssertEqual(spy.captured.first?.name, "prayer_logged")
        XCTAssertEqual(spy.captured.first?.properties["prayer_index_in_session"], .int(2))
        XCTAssertEqual(spy.captured.first?.properties["since_last_prayer_bucket"], .string("30–45m"))
    }

    // MARK: - device_source origin tagging (2e-i)

    func test_deviceSource_defaultsToPhone() {
        let spy = SpyAnalytics()
        service(spy, store: InMemoryAnalyticsStateStore()).recordSessionStarted(at: now)
        XCTAssertEqual(spy.captured.first?.properties["device_source"], .string("phone"))
        XCTAssertEqual(spy.captured.first?.deviceSource, .phone)
    }

    func test_settingDeviceSourceWatch_tagsSubsequentEvents() {
        let spy = SpyAnalytics()
        let svc = service(spy, store: InMemoryAnalyticsStateStore())

        svc.deviceSource = .watch
        svc.recordSessionStarted(at: now)
        XCTAssertEqual(spy.captured.first?.properties["device_source"], .string("watch"))
        XCTAssertEqual(spy.captured.first?.deviceSource, .watch)

        // Restoring to phone re-tags later events.
        svc.deviceSource = .phone
        svc.recordPrayerLogged(index: 2, sinceLast: 2000, at: now)
        XCTAssertEqual(spy.captured.last?.properties["device_source"], .string("phone"))
    }

    // MARK: - Foreground / alarm

    func test_recordAppOpened_emitsWithDaysSinceInstall() {
        let spy = SpyAnalytics()
        let store = InMemoryAnalyticsStateStore()
        store.installDate = now.addingTimeInterval(-5 * 86_400)
        service(spy, store: store).recordAppOpened(now: now)

        XCTAssertEqual(spy.captured.map(\.name), ["app_opened"])
        XCTAssertEqual(spy.captured.first?.properties["days_since_install"], .int(5))
    }

    func test_recordAmenAlarmSet() {
        let spy = SpyAnalytics()
        service(spy, store: InMemoryAnalyticsStateStore()).recordAmenAlarmSet(at: now)
        XCTAssertEqual(spy.captured.map(\.name), ["amen_alarm_set"])
    }

    func test_recordAmenAlarmTapped_carriesTimeOfDay() {
        let spy = SpyAnalytics()
        service(spy, store: InMemoryAnalyticsStateStore()).recordAmenAlarmTapped(at: now)
        XCTAssertEqual(spy.captured.first?.name, "amen_alarm_tapped")
        XCTAssertNotNil(spy.captured.first?.properties["time_of_day_bucket"])
    }

    // MARK: - Watch proxy (2e-ii)

    func test_recordWatchPrayerLogViewed_taggedWatch_withTrueTimestamp() {
        let spy = SpyAnalytics()
        let svc = service(spy, store: InMemoryAnalyticsStateStore())
        XCTAssertEqual(svc.deviceSource, .phone, "service default is phone")

        let tapped = Date(timeIntervalSince1970: 1_650_000_000)
        svc.recordWatchPrayerLogViewed(at: tapped)

        let event = spy.captured.first
        XCTAssertEqual(event?.name, "prayer_log_viewed")
        XCTAssertEqual(event?.deviceSource, .watch, "proxied event keeps watch origin")
        XCTAssertEqual(event?.properties["device_source"], .string("watch"))
        XCTAssertEqual(event?.captureTimestamp, tapped, "true capture time preserved")
        XCTAssertEqual(svc.deviceSource, .phone, "service device source unchanged after")
    }

    func test_sessionEnded_carriesValueAndDuration_andNoDoubleClose() {
        let spy = SpyAnalytics()
        let store = InMemoryAnalyticsStateStore()
        let svc = service(spy, store: store)
        let start = now
        let prayers = [start, start.addingTimeInterval(1860), start.addingTimeInterval(3720)] // each 31m

        svc.recordSessionEnded(sessionStart: start, prayerTimestamps: prayers)
        XCTAssertEqual(spy.captured.map(\.name), ["session_ended"])
        XCTAssertEqual(spy.captured.first?.properties["prayers_in_session"], .int(3))
        XCTAssertEqual(spy.captured.first?.properties["session_value"], .string("high"))
        XCTAssertEqual(spy.captured.first?.properties["session_duration_bucket"], .string("1h–1h15"))
        XCTAssertEqual(store.closedSessionStart, start)

        // Second close of the same session is suppressed.
        svc.recordSessionEnded(sessionStart: start, prayerTimestamps: prayers)
        XCTAssertEqual(spy.captured.count, 1, "no double-close")
    }
}
