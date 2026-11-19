import Foundation
import NudgeEngine

/// Settings' Default Alarm Sound (#228, GLOSSARY.md, Default alarm sound), kept in `UserDefaults`
/// beside the Default Pace so it outlives a relaunch. Delete All Data clears it back to Default.
struct DefaultAlarmSoundRecord {
    let defaults: UserDefaults

    static var standard: DefaultAlarmSoundRecord { DefaultAlarmSoundRecord(defaults: .standard) }

    private static let key = "defaultAlarmSound"

    /// Saved by the sound's ID, so an ID a newer build saved reads as Default (`AlarmSound(id:)`).
    var sound: AlarmSound {
        get { defaults.string(forKey: Self.key).map(AlarmSound.init(id:)) ?? .default }
        nonmutating set { defaults.set(newValue.id, forKey: Self.key) }
    }

    /// Back to Default.
    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
