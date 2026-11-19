import ActivityKit
import Foundation
import NudgeEngine

extension AlarmSound {
    /// The name of this sound's file in the app bundle: the tone's ID plus `.caf` (App/Resources/Tones,
    /// made by scripts/tones/generate-tones.py). `nil` for Default, the standard alarm sound, which
    /// is no file the app can play.
    var toneFileName: String? {
        self == .default ? nil : "\(id).caf"
    }

    /// This tone's bundled file, for the picker's preview. `nil` for Default.
    var toneFileURL: URL? {
        toneFileName.flatMap { Bundle.main.url(forResource: $0, withExtension: nil) }
    }

    /// What AlarmKit is given to ring with: its own default sound for Default, exactly as before
    /// 1.5.0, or the tone's bundled file. Apple: `named(_:)` takes a file in the main bundle or
    /// `Library/Sounds`. The file is named with its extension: developers report the default sound
    /// played without it on iOS 26.5 (spec #129), a device check.
    var alertSound: AlertConfiguration.AlertSound {
        toneFileName.map { .named($0) } ?? .default
    }
}
