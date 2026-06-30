import XCTest
@testable import Graces_Holy_Bell

/// Phase 2a — High-Value Session Density classifier (§4).
///
/// Rapid taps (<60s apart) collapse into one "real" prayer so accidental
/// double/triple taps cannot drag a session down; then a session is high iff it
/// has 2+ distinct prayers with every consecutive gap >= 30 min.
final class SessionValueTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private func t(_ minutes: Double) -> Date { base.addingTimeInterval(minutes * 60) }

    func test_emptyOrSingle_isLow() {
        XCTAssertEqual(SessionValueClassifier.classify(prayerTimestamps: []), .low)
        XCTAssertEqual(SessionValueClassifier.classify(prayerTimestamps: [t(0)]), .low)
    }

    func test_twoPrayers_thirtyOneMinutesApart_isHigh() {
        XCTAssertEqual(SessionValueClassifier.classify(prayerTimestamps: [t(0), t(31)]), .high)
    }

    func test_twoPrayers_tenMinutesApart_isLow() {
        XCTAssertEqual(SessionValueClassifier.classify(prayerTimestamps: [t(0), t(10)]), .low)
    }

    func test_rapidPair_collapsesToOne_isLow() {
        // 40 seconds apart — accidental double tap, treated as a single prayer.
        XCTAssertEqual(
            SessionValueClassifier.classify(prayerTimestamps: [t(0), t(40.0 / 60.0)]),
            .low
        )
    }

    func test_accidentalBurstThenRealPrayerAnHourLater_isHigh() {
        // The user's scenario: 3 taps within a few seconds, then a prayer ~1h later.
        let burst = [base, base.addingTimeInterval(2), base.addingTimeInterval(4)]
        let later = base.addingTimeInterval(3600)
        XCTAssertEqual(
            SessionValueClassifier.classify(prayerTimestamps: burst + [later]),
            .high
        )
    }

    func test_threePrayers_allAtLeastThirtyApart_isHigh() {
        XCTAssertEqual(SessionValueClassifier.classify(prayerTimestamps: [t(0), t(30), t(65)]), .high)
    }

    func test_threePrayers_oneShortGap_isLow() {
        // Middle gap is 20 min — not high.
        XCTAssertEqual(SessionValueClassifier.classify(prayerTimestamps: [t(0), t(30), t(50)]), .low)
    }

    func test_unsortedInput_isSortedFirst() {
        XCTAssertEqual(SessionValueClassifier.classify(prayerTimestamps: [t(31), t(0)]), .high)
    }
}
