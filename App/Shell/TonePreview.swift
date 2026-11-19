import Foundation
import NudgeEngine

/// Plays one sound file at a time for the picker's preview. `AudioTonePlayer` is the real one; tests
/// pass a fake that records what it was asked.
@MainActor
protocol TonePlaying: AnyObject {
    /// Plays `file` through to its end, in place of anything this player is playing.
    func play(_ file: URL)
    func stop()
}

/// The alarm sound picker's preview (#229): choosing a sound stops what's playing and plays the
/// chosen tone's bundled file. Default plays nothing, because the standard alarm sound is no file the
/// app can play.
@MainActor
final class TonePreview {
    private let player: any TonePlaying

    init(player: any TonePlaying) {
        self.player = player
    }

    func play(_ sound: AlarmSound) {
        player.stop()
        if let file = sound.toneFileURL {
            player.play(file)
        }
    }

    /// Stops the preview, when the person leaves the picker.
    func stop() {
        player.stop()
    }
}
