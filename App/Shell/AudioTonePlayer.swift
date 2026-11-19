import AVFoundation

/// The picker preview's real player: the whole tone, through the app's own audio, as the Clock app
/// plays a tone it's choosing (#229).
@MainActor
final class AudioTonePlayer: NSObject, TonePlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func play(_ file: URL) {
        stop()
        let session = AVAudioSession.sharedInstance()
        do {
            // Playback, which Apple's docs say the Ring/Silent switch doesn't silence: the preview plays
            // on silent, as the Clock app's does (the developer's call, #229), since the person chose to
            // hear it. With no options it pauses another app's music for the tone rather than ducking
            // it: Apple's docs say not to duck for more than a few seconds, and a tone runs 25.
            try session.setCategory(.playback)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: file)
            player.delegate = self
            if player.play() {
                self.player = player
                return
            }
        } catch {}
        // No preview, nothing more: the choice is already saved, and the preview only helps choose.
        // The session was activated, though, so let other audio resume.
        deactivateSession()
    }

    func stop() {
        guard let player else { return }
        player.stop()
        self.player = nil
        deactivateSession()
    }

    /// Tells the app whose audio the preview paused that it may resume (Apple: notify others on
    /// deactivation). Called once the player is stopped, so no audio of the app's is still running.
    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The tone played to its end: let other apps' audio resume, unless another tone has started since.
    nonisolated func audioPlayerDidFinishPlaying(_ finished: AVAudioPlayer, successfully flag: Bool) {
        let finishedID = ObjectIdentifier(finished)
        Task { @MainActor in
            if player.map(ObjectIdentifier.init) == finishedID { stop() }
        }
    }
}
