import NudgeEngine

extension AlarmSound {
    /// The file an alarm or the preview plays for this sound: the tone's ID plus `.caf`, in the app
    /// bundle (App/Resources/Tones, made by scripts/tones/generate-tones.py). `nil` for Default,
    /// the standard alarm sound, which is no file the app can play.
    var toneFileName: String? {
        self == .default ? nil : "\(id).caf"
    }
}
