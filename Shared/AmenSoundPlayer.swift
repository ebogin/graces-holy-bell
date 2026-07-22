import AVFoundation

/// Plays the loud clanging-bell alarm audio while the AMEN takeover is up.
///
/// Uses the `.playback` audio-session category so the bell rings even with
/// the silent switch on — the user explicitly opted into "Bell Sound".
/// Compiled into both the iPhone and Watch targets; each bundles its own
/// copy of bell_alarm.caf (~29.5s of tolling, also the notification sound).
final class AmenSoundPlayer {

    private var player: AVAudioPlayer?

    /// Starts the bell, skipping `elapsed` seconds into the recording so a
    /// takeover opened late doesn't ring past the 30-second alarm window.
    func start(elapsed: TimeInterval = 0) {
        stop()
        guard let url = Bundle.main.url(forResource: "bell_alarm", withExtension: "caf"),
              let player = try? AVAudioPlayer(contentsOf: url),
              elapsed < player.duration else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
        #if os(iOS)
        // Force the built-in speaker even if AirPods/Bluetooth earphones are
        // connected — this is an alarm, it needs to be heard, not routed to
        // whatever headset happens to be paired. (Not available on watchOS.)
        try? session.overrideOutputAudioPort(.speaker)
        #endif
        player.currentTime = max(0, elapsed)
        player.play()
        self.player = player
    }

    func stop() {
        guard let player else { return }
        player.stop()
        self.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
