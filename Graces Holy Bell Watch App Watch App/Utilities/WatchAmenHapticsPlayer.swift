import Foundation
import WatchKit

/// Plays the Amen Alarm's "dot-dot-dot, pause" wrist-haptic pattern.
///
/// WKInterfaceDevice has no long-pattern API, so a repeating timer fires each
/// cycle and dispatches the three taps within it. Runs while the Watch AMEN
/// takeover is on screen, for up to 30 seconds.
final class WatchAmenHapticsPlayer {

    private var timer: Timer?
    private var isRunning = false
    private var endTime: Date = .distantPast

    private static let dotOffsets: [TimeInterval] = [0, 0.35, 0.7]
    private static let cyclePeriod: TimeInterval = 1.6

    /// Starts the pattern, running for `duration` seconds (no-op if <= 0).
    func start(duration: TimeInterval) {
        stop()
        guard duration > 0 else { return }
        isRunning = true
        endTime = Date().addingTimeInterval(duration)
        playCycle()
        timer = Timer.scheduledTimer(withTimeInterval: Self.cyclePeriod, repeats: true) { [weak self] _ in
            self?.playCycle()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func playCycle() {
        guard Date() < endTime else {
            stop()
            return
        }
        for offset in Self.dotOffsets {
            DispatchQueue.main.asyncAfter(deadline: .now() + offset) { [weak self] in
                guard let self, self.isRunning, Date() < self.endTime else { return }
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
}
