#if DEBUG
import Foundation
import NudgeEngine

extension SeedSet {
    /// #458's device check of Use for All Reminders: one Firm reminder two days away on Chime, with
    /// Break Through Focus off, as every seeded reminder has, so it schedules no alarm until the check
    /// turns the switch on in Edit and its Sound row shows. The Default Alarm Sound starts on Default
    /// Alarm, so `clean` puts back the sound the phone had, whatever the check chose; it deletes the
    /// reminder too, which cancels the alarms that schedules.
    static let useForAll = SeedSet(
        name: "use-for-all",
        settings: [.defaultAlarmSound: "default"],
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(62), title: "Dentist appointment", notes: "Bring the insurance card.", dueIn: 2 * 86_400, createdAgo: 86_400, strength: .firm, alarmSound: .chime),
        ]
    )
}
#endif
