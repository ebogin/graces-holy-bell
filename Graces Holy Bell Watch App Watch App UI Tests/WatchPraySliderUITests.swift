import XCTest

/// XCUITest stress-test suite for WatchPraySlider + WatchSessionViewModel.
///
/// Launches the watch app with UI_TESTING=1. In that mode, WatchPraySlider swaps its
/// DragGesture for a TapGesture (SwiftUI DragGesture isn't reliably synthesisable by
/// XCUITest on watchOS). Tapping the slider exercises the same
/// sendPray() → optimistic-append → badge-count code path that the fix addresses.
///
/// The 10-iteration stress test is designed to force the "vibrating but doing nothing"
/// regression to reappear: every iteration must update the badge count, not just fire
/// the haptic. Any stale-state hang will cause a badge count mismatch and fail the test.
///
/// NOTE: This test MUST run before other tests in the suite. watchOS simulator enforces
/// a ~20 s session-scoped foreground timer; running it first ensures it gets a full
/// budget. The "A_" prefix keeps it alphabetically first within the class.
final class WatchPraySliderUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Stress test

    /// Taps the PRAY slider 10 times, each time verifying the badge count incremented.
    /// This is the key regression test: if the optimistic-update fix regresses, the badge
    /// count will stall even though the haptic fires, causing this test to fail.
    func testA_PraySlider10IterationStressTest() throws {
        let slider = praySlider()
        XCTAssertTrue(slider.waitForExistence(timeout: 10),
            "PRAY slider must be visible; check UI_TESTING env var injects active session state")

        var expectedCount = readPrayerCount()
        XCTAssertGreaterThan(expectedCount, 0, "Initial count must be > 0 (test state seeds one entry)")

        for iteration in 1...10 {
            slider.tap()
            waitForDebounce()

            expectedCount += 1
            let actual = readPrayerCount()
            XCTAssertEqual(actual, expectedCount,
                "Iteration \(iteration): expected \(expectedCount) prayers, got \(actual). " +
                "A stall here indicates the optimistic-update fix regressed.")
        }
    }

    // MARK: - Debounce guard

    /// Taps the slider twice in rapid succession (before the 400 ms debounce resets).
    /// Only the first tap should register; the second must be swallowed by the isCompleting guard.
    func testRapidDoubleTapOnlyRegistersOnce() throws {
        let slider = praySlider()
        XCTAssertTrue(slider.waitForExistence(timeout: 10))

        let countBefore = readPrayerCount()

        // Two taps with no debounce wait between them
        slider.tap()
        slider.tap()

        // Now wait for debounce to clear
        waitForDebounce()

        XCTAssertEqual(readPrayerCount(), countBefore + 1,
            "Rapid double-tap must register exactly once (isCompleting debounce)")
    }

    /// Taps three times with the full debounce cooldown between each.
    /// All three must register — ensures the guard resets properly after each activation.
    func testConsecutiveTapsWithCooldownEachRegister() throws {
        let slider = praySlider()
        XCTAssertTrue(slider.waitForExistence(timeout: 10))

        let countBefore = readPrayerCount()
        for _ in 1...3 {
            slider.tap()
            waitForDebounce()
        }

        XCTAssertEqual(readPrayerCount(), countBefore + 3,
            "Three separate taps (each after debounce cooldown) must all register")
    }

    // MARK: - Helpers

    private func praySlider() -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "pray-slider").firstMatch
    }

    /// Waits longer than the 400 ms isCompleting debounce plus UI update propagation time.
    private func waitForDebounce() {
        let e = expectation(description: "debounce reset")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { e.fulfill() }
        wait(for: [e], timeout: 2.0)
    }

    /// Reads the prayer count from the accessibility value of the log-count badge.
    private func readPrayerCount() -> Int {
        let badge = app.buttons["prayer-count-badge"]
        guard badge.exists, let value = badge.value as? String else { return 0 }
        return Int(value) ?? 0
    }
}
