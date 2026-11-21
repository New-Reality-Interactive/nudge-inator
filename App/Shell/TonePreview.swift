import Foundation
import NudgeEngine

/// Plays one sound file at a time for the picker's preview. `AudioTonePlayer` is the real one; tests
/// pass a fake that records what it was asked.
@MainActor
protocol TonePlaying: AnyObject {
    /// Whether a file is still playing: `false` once it has played to its end or been stopped.
    var isPlaying: Bool { get }
    /// Plays `file` through to its end, in place of anything this player is playing.
    func play(_ file: URL)
    func stop()
}

/// The alarm sound picker's preview (#229): choosing a sound stops what's playing and plays the
/// chosen tone's bundled file, except that choosing the tone playing stops it (the developer's call,
/// 2026-11-19). Default plays nothing, because the standard alarm sound is no file the app can play.
@MainActor
final class TonePreview {
    private let player: any TonePlaying
    /// The sound last played, which may since have ended.
    private var lastPlayed: AlarmSound?

    init(player: any TonePlaying) {
        self.player = player
    }

    func play(_ sound: AlarmSound) {
        let stopsIt = sound == lastPlayed && player.isPlaying
        stop()
        if !stopsIt, let file = sound.toneFileURL {
            player.play(file)
            lastPlayed = sound
        }
    }

    /// Stops the preview, when the person leaves the picker.
    func stop() {
        player.stop()
        lastPlayed = nil
    }
}
