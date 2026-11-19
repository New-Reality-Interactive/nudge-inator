import NudgeEngine

extension AlarmSound {
    /// The name of this sound's file in the app bundle: the tone's ID plus `.caf` (App/Resources/Tones,
    /// made by scripts/tones/generate-tones.py). `nil` for Default, the standard alarm sound, which
    /// is no file the app can play.
    var toneFileName: String? {
        self == .default ? nil : "\(id).caf"
    }
}
