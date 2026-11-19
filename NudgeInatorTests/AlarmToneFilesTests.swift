import AVFoundation
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The six alarm tones the app ships (#225) are in the built app under the names the alarm adapter
/// and the preview pass. The test bundle is hosted in the app, so `Bundle.main` is the app's bundle.
struct AlarmToneFilesTests {
    static let tones: [AlarmSound] = [.chime, .bell, .pulse, .beacon, .rise, .siren]

    @Test func eachToneIsAFileNamedAfterItsIDInTheAppBundle() throws {
        for sound in Self.tones {
            let name = try #require(sound.toneFileName)

            #expect(name == "\(sound.id).caf")
            #expect(Bundle.main.url(forResource: name, withExtension: nil) != nil, "\(name) is not in the app bundle")
        }
    }

    @Test func defaultHasNoFile() {
        #expect(AlarmSound.default.toneFileName == nil)
    }

    @Test func everySoundButDefaultIsOneOfTheSixTones() {
        #expect(AlarmSound.allCases.filter { $0.toneFileName != nil } == Self.tones)
    }

    /// Apple: a notification sound over 30 seconds falls back to the default sound.
    @Test func eachToneIsAboutTwentyFiveSecondsAndUnderThirty() throws {
        for sound in Self.tones {
            let name = try #require(sound.toneFileName)
            let url = try #require(Bundle.main.url(forResource: name, withExtension: nil))
            let file = try AVAudioFile(forReading: url)
            let seconds = Double(file.length) / file.processingFormat.sampleRate

            #expect(seconds > 20 && seconds < 30, "\(sound.id) is \(seconds) seconds")
        }
    }
}
