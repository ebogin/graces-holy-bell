import XCTest
@testable import Graces_Holy_Bell

/// Phase 2a — `day_of_week` label. Weekend (Thu–Sun) segmentation is derived
/// later in PostHog, not here.
final class DayOfWeekTests: XCTestCase {

    private var utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func test_knownDates_mapToWeekday() {
        // 1970-01-01 was a Thursday.
        XCTAssertEqual(DayOfWeek.label(for: Date(timeIntervalSince1970: 0), calendar: utc), "thursday")
        // 2026-06-26 is a Friday.
        XCTAssertEqual(DayOfWeek.label(for: day(2026, 6, 26), calendar: utc), "friday")
        // 2026-06-28 is a Sunday.
        XCTAssertEqual(DayOfWeek.label(for: day(2026, 6, 28), calendar: utc), "sunday")
        // 2026-06-29 is a Monday.
        XCTAssertEqual(DayOfWeek.label(for: day(2026, 6, 29), calendar: utc), "monday")
    }
}
