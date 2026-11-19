#if DEBUG
import Foundation

extension SeedSet {
    /// #228's phone check of Settings' Default Alarm Sound: it starts on Default Alarm, and `clean`
    /// puts back the sound the phone had, whatever the check chose. No reminders, so no alarm.
    static let alarmSound = SeedSet(
        name: "alarm-sound",
        settings: [.defaultAlarmSound: "default"],
        reminders: []
    )
}
#endif
