import Foundation

/// The person's choices kept in `UserDefaults` that Delete All Data clears: Settings' Default Pace
/// and Default Alarm Sound, the Reminders and Tags tabs' sorts, and the quiet hours schedules.
/// Together, so the app model takes them as one and a new one is added here, not at every place a
/// model is made. The onboarding and sharing records stay apart: Delete All Data doesn't clear
/// them.
struct SettingsRecords {
    let defaultPace: DefaultPaceRecord
    let defaultAlarmSound: DefaultAlarmSoundRecord
    let remindersSort: RemindersSortRecord
    let tagsSort: TagsSortRecord
    let quietHours: QuietHoursRecord

    /// Every record over `defaults`.
    init(defaults: UserDefaults) {
        defaultPace = DefaultPaceRecord(defaults: defaults)
        defaultAlarmSound = DefaultAlarmSoundRecord(defaults: defaults)
        remindersSort = RemindersSortRecord(defaults: defaults)
        tagsSort = TagsSortRecord(defaults: defaults)
        quietHours = QuietHoursRecord(defaults: defaults)
    }

    init(
        defaultPace: DefaultPaceRecord,
        defaultAlarmSound: DefaultAlarmSoundRecord,
        remindersSort: RemindersSortRecord,
        tagsSort: TagsSortRecord,
        quietHours: QuietHoursRecord
    ) {
        self.defaultPace = defaultPace
        self.defaultAlarmSound = defaultAlarmSound
        self.remindersSort = remindersSort
        self.tagsSort = tagsSort
        self.quietHours = quietHours
    }

    static var standard: SettingsRecords { SettingsRecords(defaults: .standard) }
}
