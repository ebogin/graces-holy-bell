import XCTest
@testable import Graces_Holy_Bell

/// Session-start date is attributed to the user's LOCAL day, not UTC.
final class LocalSessionDateTests: XCTestCase {

    private func calendar(_ tz: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        return c
    }

    /// The heart of the requirement: one UTC instant, two users, two local days.
    /// Saturday 2026-07-04 00:00 UTC is 01:00 Saturday in the UK (BST, +1) and
    /// 17:00 Friday in California (PDT, −7).
    func test_sameUTCInstant_attributesToEachUsersLocalDay() {
        let utc = calendar("UTC")
        let instant = utc.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 0, minute: 0))!

        XCTAssertEqual(LocalSessionDate.label(for: instant, calendar: calendar("Europe/London")), "2026-07-04") // Saturday
        XCTAssertEqual(LocalSessionDate.label(for: instant, calendar: calendar("America/Los_Angeles")), "2026-07-03") // Friday
    }

    func test_formatIsZeroPaddedSortableISO() {
        let utc = calendar("UTC")
        let d = utc.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        XCTAssertEqual(LocalSessionDate.label(for: d, calendar: utc), "2026-01-05")
    }

    /// Just before local midnight stays on the current local day; the UTC date
    /// has already rolled over.
    func test_lateEveningLocal_staysOnLocalDay_notNextUTCDay() {
        // 2026-07-03 23:30 in Los Angeles (PDT) = 2026-07-04 06:30 UTC.
        let instant = calendar("America/Los_Angeles")
            .date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 23, minute: 30))!
        XCTAssertEqual(LocalSessionDate.label(for: instant, calendar: calendar("America/Los_Angeles")), "2026-07-03")
        XCTAssertEqual(LocalSessionDate.label(for: instant, calendar: calendar("UTC")), "2026-07-04")
    }
}
