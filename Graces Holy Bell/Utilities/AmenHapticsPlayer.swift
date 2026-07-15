import CoreHaptics

/// Plays the Amen Alarm's intense "dot-dot-dot, pause" haptic pattern on the
/// iPhone via CoreHaptics: three full-intensity pulses, a beat of silence,
/// repeating for up to 30 seconds while the AMEN takeover is on screen.
final class AmenHapticsPlayer {

    private var engine: CHHapticEngine?

    /// Dots within each cycle (seconds from cycle start), then silence to the
    /// end of the cycle: dot-dot-dot … pause … dot-dot-dot … pause …
    private static let dotOffsets: [TimeInterval] = [0, 0.25, 0.5]
    private static let dotDuration: TimeInterval = 0.12
    private static let cyclePeriod: TimeInterval = 1.5

    /// Starts the pattern, running for `duration` seconds (no-op if <= 0).
    func start(duration: TimeInterval) {
        stop()
        guard duration > 0,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = try? CHHapticEngine() else { return }
        self.engine = engine
        do {
            try engine.start()
            let player = try engine.makePlayer(with: Self.makePattern(duration: duration))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            engine.stop()
            self.engine = nil
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }

    private static func makePattern(duration: TimeInterval) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var cycleStart: TimeInterval = 0
        while cycleStart < duration {
            for dot in dotOffsets where cycleStart + dot < duration {
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: cycleStart + dot,
                    duration: dotDuration
                ))
            }
            cycleStart += cyclePeriod
        }
        return try CHHapticPattern(events: events, parameters: [])
    }
}
