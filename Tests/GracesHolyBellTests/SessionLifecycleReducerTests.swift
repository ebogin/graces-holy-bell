import XCTest
@testable import Graces_Holy_Bell

/// Phase 2c — next-launch forgotten-timer synthesis + no-double-close.
final class SessionLifecycleReducerTests: XCTestCase {

    private let lastPrayer = Date(timeIntervalSince1970: 1_700_000_000)
    private let twelveHours: TimeInterval = 12 * 3600

    private func snapshot(prayers: Int = 1, closed: Bool = false) -> SessionLaunchSnapshot {
        SessionLaunchSnapshot(lastPrayerAt: lastPrayer, prayersSoFar: prayers, alreadyClosed: closed)
    }

    func test_underThreshold_isNone() {
        let now = lastPrayer.addingTimeInterval(11 * 3600)
        XCTAssertEqual(SessionLifecycleReducer.evaluateAtLaunch(snapshot(), now: now), .none)
    }

    func test_exactlyTwelveHours_synthesizesAtLastPrayerPlus12h() {
        let now = lastPrayer.addingTimeInterval(twelveHours)
        XCTAssertEqual(
            SessionLifecycleReducer.evaluateAtLaunch(snapshot(prayers: 3), now: now),
            .synthesizeForgottenTimerAbandon(at: lastPrayer.addingTimeInterval(twelveHours), prayersSoFar: 3)
        )
    }

    func test_wellPastThreshold_backdatesToCrossing_notNow() {
        let now = lastPrayer.addingTimeInterval(30 * 3600) // launched 30h later
        XCTAssertEqual(
            SessionLifecycleReducer.evaluateAtLaunch(snapshot(prayers: 2), now: now),
            .synthesizeForgottenTimerAbandon(at: lastPrayer.addingTimeInterval(twelveHours), prayersSoFar: 2)
        )
    }

    func test_alreadyClosed_neverDoubleCloses() {
        let now = lastPrayer.addingTimeInterval(30 * 3600)
        XCTAssertEqual(
            SessionLifecycleReducer.evaluateAtLaunch(snapshot(closed: true), now: now),
            .none
        )
    }
}
