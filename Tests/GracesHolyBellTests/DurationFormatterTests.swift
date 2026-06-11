import XCTest
@testable import Graces_Holy_Bell

final class DurationFormatterTests: XCTestCase {

    // MARK: - string(from:)

    func test_string_zeroSeconds() {
        XCTAssertEqual(DurationFormatter.string(from: 0), "0m 00s")
    }

    func test_string_negativeClampedToZero() {
        XCTAssertEqual(DurationFormatter.string(from: -30), "0m 00s")
    }

    func test_string_secondsOnly() {
        XCTAssertEqual(DurationFormatter.string(from: 5), "0m 05s")
        XCTAssertEqual(DurationFormatter.string(from: 59), "0m 59s")
    }

    func test_string_minutesAndSeconds() {
        XCTAssertEqual(DurationFormatter.string(from: 60), "1m 00s")
        XCTAssertEqual(DurationFormatter.string(from: 90), "1m 30s")
        XCTAssertEqual(DurationFormatter.string(from: 754), "12m 34s")
    }

    func test_string_hoursOmittedWhenZero() {
        XCTAssertFalse(DurationFormatter.string(from: 3599).hasPrefix("0h"))
    }

    func test_string_exactlyOneHour() {
        XCTAssertEqual(DurationFormatter.string(from: 3600), "1h 00m 00s")
    }

    func test_string_hoursMinutesSeconds() {
        XCTAssertEqual(DurationFormatter.string(from: 7352), "2h 02m 32s")
    }

    // MARK: - timerString(from:)

    func test_timerString_zeroSeconds() {
        XCTAssertEqual(DurationFormatter.timerString(from: 0), "00:00:00")
    }

    func test_timerString_negativeClampedToZero() {
        XCTAssertEqual(DurationFormatter.timerString(from: -10), "00:00:00")
    }

    func test_timerString_secondsOnly() {
        XCTAssertEqual(DurationFormatter.timerString(from: 5), "00:00:05")
        XCTAssertEqual(DurationFormatter.timerString(from: 59), "00:00:59")
    }

    func test_timerString_minutesAndSeconds() {
        XCTAssertEqual(DurationFormatter.timerString(from: 90), "00:01:30")
        XCTAssertEqual(DurationFormatter.timerString(from: 3599), "00:59:59")
    }

    func test_timerString_alwaysShowsHours() {
        XCTAssertEqual(DurationFormatter.timerString(from: 3600), "01:00:00")
        XCTAssertEqual(DurationFormatter.timerString(from: 7384), "02:03:04")
    }
}
