import AVFoundation
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The six alarm tones the app ships (#225) are in the built app under the names the alarm adapter
/// and the preview pass. The test bundle is hosted in the app, so `Bundle.main` is the app's bundle.
struct AlarmToneFilesTests {
    /// Each tone and its file name, written out: renaming a tone's saved ID must fail here.
    static let tones: [(sound: AlarmSound, file: String)] = [
        (.chime, "chime.caf"), (.bell, "bell.caf"), (.pulse, "pulse.caf"),
        (.beacon, "beacon.caf"), (.rise, "rise.caf"), (.siren, "siren.caf"),
    ]

    @Test(arguments: tones)
    func aToneIsAFileInTheAppBundleNamedAfterItsID(sound: AlarmSound, file: String) {
        #expect(sound.toneFileName == file)
        #expect(Bundle.main.url(forResource: file, withExtension: nil) != nil, "\(file) is not in the app bundle")
    }

    @Test func defaultHasNoFile() {
        #expect(AlarmSound.default.toneFileName == nil)
    }

    @Test func everySoundButDefaultIsOneOfTheSixTones() {
        #expect(AlarmSound.allCases.filter { $0.toneFileName != nil } == Self.tones.map(\.sound))
    }

    /// Apple's notification sound docs: a file over 30 seconds falls back to the default sound. The
    /// tones are made 25 seconds long, as 16-bit linear PCM, one of the formats those docs list.
    @Test(arguments: tones)
    func aToneIsTwentyFiveSecondsOfLinearPCM(sound: AlarmSound, file: String) throws {
        let url = try #require(Bundle.main.url(forResource: file, withExtension: nil))
        let audio = try AVAudioFile(forReading: url)
        let seconds = Double(audio.length) / audio.fileFormat.sampleRate

        #expect(abs(seconds - 25) < 1, "\(file) is \(seconds) seconds")
        #expect(audio.fileFormat.commonFormat == .pcmFormatInt16)
    }
}
