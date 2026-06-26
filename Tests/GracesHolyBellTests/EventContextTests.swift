import XCTest
@testable import Graces_Holy_Bell

/// Phase 2b — cross-device context properties carried on every event (§2).
final class EventContextTests: XCTestCase {

    // MARK: - amen_alarm_status

    func test_alarmStatus_allToggleCombinations() {
        XCTAssertEqual(AmenAlarmStatus.from(phoneEnabled: false, watchEnabled: false), .off)
        XCTAssertEqual(AmenAlarmStatus.from(phoneEnabled: true, watchEnabled: false), .phone)
        XCTAssertEqual(AmenAlarmStatus.from(phoneEnabled: false, watchEnabled: true), .watch)
        XCTAssertEqual(AmenAlarmStatus.from(phoneEnabled: true, watchEnabled: true), .both)
    }

    // MARK: - amen_alarm_duration_setting

    func test_durationLabel_knownIntervals() {
        XCTAssertEqual(AmenAlarmDurationLabel.label(forSeconds: 1800), "30m")
        XCTAssertEqual(AmenAlarmDurationLabel.label(forSeconds: 2700), "45m")
        XCTAssertEqual(AmenAlarmDurationLabel.label(forSeconds: 3600), "1h")
        XCTAssertEqual(AmenAlarmDurationLabel.label(forSeconds: 4500), "1h15")
        XCTAssertEqual(AmenAlarmDurationLabel.label(forSeconds: 5400), "1h30")
        XCTAssertEqual(AmenAlarmDurationLabel.label(forSeconds: 6300), "1h45")
        XCTAssertEqual(AmenAlarmDurationLabel.label(forSeconds: 7200), "2h")
    }

    func test_durationLabel_devTestIntervalIsTagged() {
        XCTAssertEqual(AmenAlarmDurationLabel.label(forSeconds: 30), "30s-test")
    }

    // MARK: - baseProperties

    func test_baseProperties_carriesAllContextKeys() {
        let env = StubAppEnvironment(appVersion: "1.4.2", osVersion: "26.4.0")
        let context = EventContext(
            deviceSource: .watch,
            alarmStatus: .both,
            alarmDurationSeconds: 5400,
            environment: env
        )

        let props = context.baseProperties()

        XCTAssertEqual(props["device_source"], .string("watch"))
        XCTAssertEqual(props["amen_alarm_status"], .string("both"))
        XCTAssertEqual(props["amen_alarm_duration_setting"], .string("1h30"))
        XCTAssertEqual(props["app_version"], .string("1.4.2"))
        XCTAssertEqual(props["os_version"], .string("26.4.0"))
    }
}

/// Test double for the app/runtime environment.
struct StubAppEnvironment: AppEnvironment {
    let appVersion: String
    let osVersion: String
}
