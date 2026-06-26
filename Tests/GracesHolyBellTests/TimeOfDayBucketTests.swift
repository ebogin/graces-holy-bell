import XCTest
@testable import Graces_Holy_Bell

/// Phase 2a — eight equal 3-hour `time_of_day_bucket` labels.
final class TimeOfDayBucketTests: XCTestCase {

    private var utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(hour: Int, minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 6, day: 26, hour: hour, minute: minute))!
    }

    func test_eachBucket_atRepresentativeHour() {
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 1), calendar: utc), "late-night")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 4), calendar: utc), "early-morning")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 7), calendar: utc), "morning")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 10), calendar: utc), "late-morning")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 13), calendar: utc), "midday")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 16), calendar: utc), "afternoon")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 19), calendar: utc), "evening")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 22), calendar: utc), "night")
    }

    func test_boundaryHours_belongToTheBucketTheyStart() {
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 0), calendar: utc), "late-night")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 2, minute: 59), calendar: utc), "late-night")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 3), calendar: utc), "early-morning")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 21), calendar: utc), "night")
        XCTAssertEqual(TimeOfDayBucket.label(for: date(hour: 23, minute: 59), calendar: utc), "night")
    }
}
