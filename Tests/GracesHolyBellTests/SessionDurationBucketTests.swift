import XCTest
@testable import Graces_Holy_Bell

/// Session-scale duration bucketing (start → last prayer).
///
/// Distinct from `DurationBucket` (which times a single prayer gap in 15-min
/// brackets capped at `4h+`): this ladder keeps 30-min resolution at the low
/// end, coarsens upward, and reaches a `24h+` catch-all. Raw seconds are never
/// emitted; brackets are half-open `[lo, hi)`.
final class SessionDurationBucketTests: XCTestCase {

    func test_subThirtyMinutes_isCatchAll() {
        XCTAssertEqual(SessionDurationBucket.label(for: 0), "<30m")
        XCTAssertEqual(SessionDurationBucket.label(for: 5 * 60), "<30m")
        XCTAssertEqual(SessionDurationBucket.label(for: 1799), "<30m")
    }

    func test_negativeClampsToSubThirty() {
        XCTAssertEqual(SessionDurationBucket.label(for: -100), "<30m")
    }

    func test_lowerBoundsAreInclusive() {
        XCTAssertEqual(SessionDurationBucket.label(for: 1800), "30m–1h")
        XCTAssertEqual(SessionDurationBucket.label(for: 3600), "1–1.5h")
        XCTAssertEqual(SessionDurationBucket.label(for: 5400), "1.5–2h")
        XCTAssertEqual(SessionDurationBucket.label(for: 7200), "2–3h")
        XCTAssertEqual(SessionDurationBucket.label(for: 18000), "5–7h")
        XCTAssertEqual(SessionDurationBucket.label(for: 43200), "12–16h")
    }

    func test_upperEdgesStayInLowerBracket() {
        XCTAssertEqual(SessionDurationBucket.label(for: 3599), "30m–1h")
        XCTAssertEqual(SessionDurationBucket.label(for: 7199), "1.5–2h")
        XCTAssertEqual(SessionDurationBucket.label(for: 86399), "20–24h")
    }

    /// A session can outlast 12h (each inter-prayer gap stays under the
    /// forgotten-timer threshold), so the upper brackets are reachable.
    func test_multiHourSessionsReachUpperBrackets() {
        XCTAssertEqual(SessionDurationBucket.label(for: 32400), "9–12h")
        XCTAssertEqual(SessionDurationBucket.label(for: 57600), "16–20h")
        XCTAssertEqual(SessionDurationBucket.label(for: 72000), "20–24h")
    }

    func test_twentyFourHoursAndBeyond_isCatchAll() {
        XCTAssertEqual(SessionDurationBucket.label(for: 86400), "24h+")
        XCTAssertEqual(SessionDurationBucket.label(for: 200000), "24h+")
    }

    /// The same raw interval buckets differently for a session vs a prayer gap —
    /// the two ladders are intentionally distinct. 1h2m (3720s) is a session in
    /// `1–1.5h`, but a prayer gap in `1h–1h15`.
    func test_divergesFromPrayerGapLadder() {
        XCTAssertEqual(SessionDurationBucket.label(for: 3720), "1–1.5h")
        XCTAssertEqual(DurationBucket.label(for: 3720), "1h–1h15")
    }
}
