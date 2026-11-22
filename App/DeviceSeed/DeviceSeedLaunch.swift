#if DEBUG
import Foundation
import NudgeEngine
import os

/// The launch hook for loading test data on a device (docs/agents/device-testing.md): a launch with
/// `NUDGE_SEED=<set name>` loads that set, and `NUDGE_SEED=clean` removes what was loaded. A launch
/// without the variable does nothing. Debug builds only: Release builds contain no seed code, and
/// the test host has no model, so the tests never reach this.
@MainActor
enum DeviceSeedLaunch {
    static let variable = "NUDGE_SEED"

    /// Starts the command, if the launch carries one. It waits for the model to launch, then for
    /// both adapters to apply what the command changed, so a removal's cancels have reached them.
    static func runIfAsked(on model: AppModel, environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let command = environment[variable] else { return }
        Task {
            await model.launch()
            guard case .ready = model.launchState else {
                logger.error("Not seeding \(command, privacy: .public): the store hasn't been read")
                return
            }
            let outcome = DeviceSeed.run(
                command: command,
                sets: SeedSet.all,
                on: ModelSeedTarget(model: model),
                record: UserDefaultsSeedRecordStore.standard
            )
            await model.waitUntilApplied()
            logger.notice("Seed \(String(describing: outcome), privacy: .public)")
        }
    }

    private static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "DeviceSeed")
}

/// The model, as the seed sees it. Everything goes through the model's own add and delete, except
/// that an added reminder keeps its creation date (#248).
@MainActor
struct ModelSeedTarget: SeedTarget {
    let model: AppModel

    var now: Date { Date() }
    var reminders: [Reminder] { model.engine.reminders }
    var tags: [Tag] { model.engine.tags }

    func add(_ reminder: Reminder) {
        model.addKeepingCreationDate(reminder)
    }

    func delete(_ reminderID: Reminder.ID) {
        guard model.engine.reminders.contains(where: { $0.id == reminderID }) else { return }
        model.delete(reminderID)
    }

    func createTag(named name: String) -> Tag? {
        try? model.createTag(named: name)
    }

    func deleteTag(_ tagID: Tag.ID) {
        model.deleteTag(tagID)
    }

    func setting(_ setting: SeedSetting) -> String {
        switch setting {
        case .defaultPace: SeedSettingText.text(of: model.defaultPace)
        case .defaultAlarmSound: SeedSettingText.text(of: model.defaultAlarmSound)
        case .remindersSort: SeedSettingText.text(of: model.remindersSort)
        case .quietHours: SeedSettingText.text(of: model.quietHours)
        case .quietHoursTutorial: model.isQuietHoursTutorialDue ? SeedSeenText.unseen : SeedSeenText.seen
        }
    }

    func addQuietSpan(from start: Date, to end: Date, replacedAt: Date) {
        model.addSeedQuietSpan(from: start, to: end, replacedAt: replacedAt)
    }

    func removeQuietSpan(replacedAt: Date) {
        model.removeSeedQuietSpan(replacedAt: replacedAt)
    }

    func turnQuietNowOff() {
        model.turnQuietNow(on: false)
    }

    func setSetting(_ setting: SeedSetting, to value: String) {
        switch setting {
        case .defaultPace:
            if let pace = SeedSettingText.defaultPace(from: value) { model.defaultPace = pace }
        case .defaultAlarmSound:
            if let sound = SeedSettingText.defaultAlarmSound(from: value) { model.defaultAlarmSound = sound }
        case .remindersSort:
            if let sort = SeedSettingText.remindersSort(from: value) { model.remindersSort = sort }
        case .quietHours:
            if let quietHours = SeedSettingText.quietHours(from: value) { model.quietHours = quietHours }
        case .quietHoursTutorial:
            switch value {
            case SeedSeenText.seen: model.quietHoursTutorialClosed()
            case SeedSeenText.unseen: model.markQuietHoursTutorialUnseen()
            default: break
            }
        }
    }
}

/// How a setting's value is written in a set and in the record: `created.ascending` for the sort,
/// `consistent.600` for the Default Pace (choice, then the Consistent wait in seconds), and the
/// sound's ID for the Default Alarm Sound, and for quiet hours each schedule as
/// `22:00-07:00 SU,MO on`, joined by `; ` (none is empty).
enum SeedSettingText {
    static func text(of sort: RemindersSort) -> String {
        "\(sort.field.rawValue).\(sort.order.rawValue)"
    }

    static func remindersSort(from text: String) -> RemindersSort? {
        let parts = text.split(separator: ".").map(String.init)
        guard parts.count == 2,
              let field = RemindersSort.Field(rawValue: parts[0]),
              let order = RemindersSort.Order(rawValue: parts[1])
        else { return nil }
        return RemindersSort(field: field, order: order)
    }

    static func text(of pace: DefaultPace) -> String {
        "\(pace.choice.rawValue).\(Int(pace.consistentWait))"
    }

    static func defaultPace(from text: String) -> DefaultPace? {
        let parts = text.split(separator: ".").map(String.init)
        guard parts.count == 2,
              let choice = PaceChoice(rawValue: parts[0]),
              let wait = TimeInterval(parts[1]),
              Pace.consistentWaits.contains(wait)
        else { return nil }
        return DefaultPace(choice: choice, consistentWait: wait)
    }

    static func text(of sound: AlarmSound) -> String {
        sound.id
    }

    static func text(of quietHours: QuietHours) -> String {
        quietHours.schedules.map { schedule in
            let days = RepeatRule.Weekday.allCases.filter(schedule.days.contains).map { dayCodes[$0.rawValue - 1] }.joined(separator: ",")
            return "\(clock(schedule.start))-\(clock(schedule.end)) \(days) \(schedule.isOn ? "on" : "off")"
        }.joined(separator: "; ")
    }

    /// Nil when any schedule doesn't read, so a set never applies part of its schedules.
    static func quietHours(from text: String) -> QuietHours? {
        guard !text.isEmpty else { return QuietHours() }
        var schedules: [QuietHoursSchedule] = []
        for entry in text.components(separatedBy: "; ") {
            let parts = entry.split(separator: " ").map(String.init)
            let times = parts.first?.split(separator: "-").map(String.init) ?? []
            guard parts.count == 3, times.count == 2,
                  let start = timeOfDay(times[0]), let end = timeOfDay(times[1]),
                  parts[2] == "on" || parts[2] == "off"
            else { return nil }
            let days = parts[1].split(separator: ",").compactMap { code in dayCodes.firstIndex(of: String(code)).flatMap { RepeatRule.Weekday(rawValue: $0 + 1) } }
            guard let schedule = try? QuietHoursSchedule(start: start, end: end, days: Set(days), isOn: parts[2] == "on") else { return nil }
            schedules.append(schedule)
        }
        return QuietHours(schedules: schedules)
    }

    /// RRULE's day codes, Sunday first as `RepeatRule.Weekday`'s raw values are.
    private static let dayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

    private static func clock(_ time: TimeOfDay) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    private static func timeOfDay(_ text: String) -> TimeOfDay? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return try? TimeOfDay(hour: parts[0], minute: parts[1])
    }

    /// Only an ID this build knows: unlike the store, a set naming no sound changes nothing.
    static func defaultAlarmSound(from text: String) -> AlarmSound? {
        AlarmSound.allCases.first { $0.id == text }
    }
}

/// The record in the app's own `UserDefaults`, so it outlives the load launch.
struct UserDefaultsSeedRecordStore: SeedRecordStore {
    let defaults: UserDefaults

    static var standard: UserDefaultsSeedRecordStore { UserDefaultsSeedRecordStore(defaults: .standard) }

    private static let key = "deviceSeedRecord"

    func read() -> SeedRecord {
        defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(SeedRecord.self, from: $0) } ?? SeedRecord()
    }

    func write(_ record: SeedRecord) {
        if record == SeedRecord() {
            defaults.removeObject(forKey: Self.key)
        } else if let data = try? JSONEncoder().encode(record) {
            // A record that can't be encoded leaves the last one, which still lists earlier data.
            defaults.set(data, forKey: Self.key)
        }
    }
}
#endif
