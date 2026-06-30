import XCTest
@testable import Graces_Holy_Bell

/// Phase 2b — pure event factories for the §2 taxonomy.
///
/// Each factory assembles `name` + event-specific properties on top of the
/// cross-device context. Derivation of the inputs (lifecycle, which timestamps)
/// is Phase 2c/2d; here we pin the name→property contract.
final class AnalyticsEventsTests: XCTestCase {

    private func factory(device: DeviceSource = .phone) -> AnalyticsEventFactory {
        let context = EventContext(
            deviceSource: device,
            alarmStatus: .phone,
            alarmDurationSeconds: 3600,
            environment: StubAppEnvironment(appVersion: "1.0.0", osVersion: "26.4.0")
        )
        return AnalyticsEventFactory(context: context)
    }

    func test_everyEvent_carriesContextProperties() {
        let event = factory().appOpened(entryPoint: .icon, daysSinceInstall: 3)
        XCTAssertEqual(event.deviceSource, .phone)
        XCTAssertEqual(event.properties["device_source"], .string("phone"))
        XCTAssertEqual(event.properties["app_version"], .string("1.0.0"))
        XCTAssertEqual(event.properties["amen_alarm_status"], .string("phone"))
    }

    func test_appOpened() {
        let event = factory().appOpened(entryPoint: .notification, daysSinceInstall: 7)
        XCTAssertEqual(event.name, "app_opened")
        XCTAssertEqual(event.properties["entry_point"], .string("notification"))
        XCTAssertEqual(event.properties["days_since_install"], .int(7))
    }

    func test_sessionStarted() {
        let event = factory().sessionStarted(entryPoint: .widget, timeOfDay: "morning", dayOfWeek: "friday")
        XCTAssertEqual(event.name, "session_started")
        XCTAssertEqual(event.properties["entry_point"], .string("widget"))
        XCTAssertEqual(event.properties["time_of_day_bucket"], .string("morning"))
        XCTAssertEqual(event.properties["day_of_week"], .string("friday"))
    }

    func test_prayerLogged() {
        let event = factory().prayerLogged(prayerIndexInSession: 2, sinceLastPrayerBucket: "30–45m")
        XCTAssertEqual(event.name, "prayer_logged")
        XCTAssertEqual(event.properties["prayer_index_in_session"], .int(2))
        XCTAssertEqual(event.properties["since_last_prayer_bucket"], .string("30–45m"))
    }

    func test_sessionEnded() {
        let event = factory().sessionEnded(
            prayersInSession: 4,
            sessionValue: .high,
            sessionDurationBucket: "1h30–1h45",
            timeOfDay: "evening",
            dayOfWeek: "sunday"
        )
        XCTAssertEqual(event.name, "session_ended")
        XCTAssertEqual(event.properties["prayers_in_session"], .int(4))
        XCTAssertEqual(event.properties["session_value"], .string("high"))
        XCTAssertEqual(event.properties["session_duration_bucket"], .string("1h30–1h45"))
        XCTAssertEqual(event.properties["time_of_day_bucket"], .string("evening"))
        XCTAssertEqual(event.properties["day_of_week"], .string("sunday"))
    }

    func test_sessionAbandoned() {
        let userExit = factory().sessionAbandoned(prayersSoFar: 1, reason: .userExit)
        XCTAssertEqual(userExit.name, "session_abandoned")
        XCTAssertEqual(userExit.properties["prayers_so_far"], .int(1))
        XCTAssertEqual(userExit.properties["reason"], .string("user_exit"))

        let forgotten = factory().sessionAbandoned(prayersSoFar: 2, reason: .forgottenTimer)
        XCTAssertEqual(forgotten.properties["reason"], .string("forgotten_timer"))
    }

    func test_appInstalled_setsInstallDate() {
        let installDate = Date(timeIntervalSince1970: 1_700_000_000)
        let event = factory().appInstalled(installDate: installDate)
        XCTAssertEqual(event.name, "app_installed")
        XCTAssertEqual(event.properties["install_date"], .string(ISO8601DateFormatter().string(from: installDate)))
    }

    func test_watchAppInstalled() {
        XCTAssertEqual(factory(device: .watch).watchAppInstalled().name, "watch_app_installed")
    }

    func test_amenAlarmSet() {
        XCTAssertEqual(factory().amenAlarmSet().name, "amen_alarm_set")
    }

    func test_amenAlarmTapped() {
        let event = factory().amenAlarmTapped(timeOfDay: "morning")
        XCTAssertEqual(event.name, "amen_alarm_tapped")
        XCTAssertEqual(event.properties["time_of_day_bucket"], .string("morning"))
    }

    func test_prayerLogViewed_isWatchOnly() {
        let event = factory(device: .watch).prayerLogViewed()
        XCTAssertEqual(event.name, "prayer_log_viewed")
        XCTAssertEqual(event.deviceSource, .watch)
        XCTAssertEqual(event.properties["device_source"], .string("watch"))
    }

    func test_captureTimestamp_isPreserved() {
        let t = Date(timeIntervalSince1970: 1_650_000_000)
        let event = factory().sessionStarted(entryPoint: .icon, timeOfDay: "morning", dayOfWeek: "monday", at: t)
        XCTAssertEqual(event.captureTimestamp, t)
    }
}
