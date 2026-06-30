import XCTest
@testable import Graces_Holy_Bell

/// Phase 2a — duration/interval bucketing (§3).
///
/// Raw seconds are never emitted; only these labels. Brackets are half-open
/// `[lo, hi)`, aligned to Amen Alarm interval boundaries.
final class DurationBucketTests: XCTestCase {

    func test_subThirtyMinutes_isCatchAll() {
        XCTAssertEqual(DurationBucket.label(for: 0), "<30m")
        XCTAssertEqual(DurationBucket.label(for: 5 * 60), "<30m")
        XCTAssertEqual(DurationBucket.label(for: 1799), "<30m")
    }

    func test_negativeClampsToSubThirty() {
        XCTAssertEqual(DurationBucket.label(for: -100), "<30m")
    }

    func test_lowerBoundsAreInclusive() {
        XCTAssertEqual(DurationBucket.label(for: 1800), "30–45m")
        XCTAssertEqual(DurationBucket.label(for: 2700), "45–60m")
        XCTAssertEqual(DurationBucket.label(for: 3600), "1h–1h15")
        XCTAssertEqual(DurationBucket.label(for: 5400), "1h30–1h45")
    }

    func test_upperEdgesStayInLowerBracket() {
        XCTAssertEqual(DurationBucket.label(for: 2699), "30–45m")
        XCTAssertEqual(DurationBucket.label(for: 14399), "3h45–4h")
    }

    func test_fourHoursAndBeyond_isCatchAll() {
        XCTAssertEqual(DurationBucket.label(for: 14400), "4h+")
        XCTAssertEqual(DurationBucket.label(for: 20000), "4h+")
    }
}
