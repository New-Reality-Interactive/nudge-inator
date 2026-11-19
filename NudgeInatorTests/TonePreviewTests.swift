import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The alarm sound picker's preview (#229): which file a choice plays, and when it stops. The test
/// bundle is hosted in the app, so the tone files are in `Bundle.main`. The sound itself, and the
/// silent switch, are device checks.
@MainActor
struct TonePreviewTests {
    let player = FakeTonePlayer()

    @Test(arguments: AlarmToneFilesTests.tones)
    func choosingAToneStopsAnyPreviewAndPlaysItsFile(sound: AlarmSound, file: String) {
        TonePreview(player: player).play(sound)

        #expect(player.calls == [.stop, .play(file)])
    }

    @Test func choosingDefaultStopsAnyPreviewAndPlaysNothing() {
        let preview = TonePreview(player: player)
        preview.play(.chime)
        preview.play(.default)

        #expect(player.calls == [.stop, .play("chime.caf"), .stop])
    }

    @Test func aSecondChoiceStopsTheFirstBeforePlaying() {
        let preview = TonePreview(player: player)
        preview.play(.chime)
        preview.play(.siren)

        #expect(player.calls == [.stop, .play("chime.caf"), .stop, .play("siren.caf")])
    }

    @Test func choosingTheTonePlayingStopsIt() {
        let preview = TonePreview(player: player)
        preview.play(.beacon)
        preview.play(.beacon)

        #expect(player.calls == [.stop, .play("beacon.caf"), .stop])
    }

    @Test func choosingTheToneAgainOnceItHasEndedPlaysItAgain() {
        let preview = TonePreview(player: player)
        preview.play(.rise)
        player.finish()
        preview.play(.rise)

        #expect(player.calls == [.stop, .play("rise.caf"), .stop, .play("rise.caf")])
    }

    @Test func leavingThePageStopsThePreview() {
        let preview = TonePreview(player: player)
        preview.play(.bell)
        preview.stop()

        #expect(player.calls == [.stop, .play("bell.caf"), .stop])
    }
}

/// Records what the preview asked it to play and stop, in order, by file name.
@MainActor
final class FakeTonePlayer: TonePlaying {
    enum Call: Equatable {
        case play(String)
        case stop
    }

    private(set) var calls: [Call] = []
    private(set) var isPlaying = false

    func play(_ file: URL) {
        calls.append(.play(file.lastPathComponent))
        isPlaying = true
    }

    func stop() {
        calls.append(.stop)
        isPlaying = false
    }

    /// The tone played to its end, as a real file does after 25 seconds.
    func finish() {
        isPlaying = false
    }
}
