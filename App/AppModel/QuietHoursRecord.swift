import Foundation
import NudgeEngine

/// The quiet hours schedules (#366), kept in `UserDefaults` so they outlive a relaunch, as the
/// Default Pace is. Delete All Data clears it, back to none, which means off. It holds no field of
/// the reminder store, so an install updated from an earlier version, with nothing saved, opens
/// with no migration.
///
/// Each schedule is one property list entry: the start and end as minutes into the day, the days
/// as the weekday numbers `Calendar` uses, and on or off. The read is defensive: an entry that
/// isn't a dictionary, lacks a field or fails the engine's throwing initializers (a time the clock
/// doesn't show, a start equal to the end, a day that isn't a weekday) is left out and the others
/// are kept, in the order they were saved.
struct QuietHoursRecord {
    let defaults: UserDefaults

    static var standard: QuietHoursRecord { QuietHoursRecord(defaults: .standard) }

    /// The key the list is saved under.
    static let key = "quietHoursSchedules"

    /// The fields of one entry.
    enum Field {
        static let start = "start"
        static let end = "end"
        static let days = "days"
        static let isOn = "isOn"
    }

    var quietHours: QuietHours {
        get {
            let entries = defaults.array(forKey: Self.key) ?? []
            return QuietHours(schedules: entries.compactMap(Self.schedule(from:)))
        }
        nonmutating set {
            defaults.set(newValue.schedules.map(Self.entry(for:)), forKey: Self.key)
        }
    }

    /// Back to none.
    func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    private static func entry(for schedule: QuietHoursSchedule) -> [String: Any] {
        [
            Field.start: schedule.start.hour * 60 + schedule.start.minute,
            Field.end: schedule.end.hour * 60 + schedule.end.minute,
            Field.days: schedule.days.map(\.rawValue).sorted(),
            Field.isOn: schedule.isOn,
        ]
    }

    private static func schedule(from entry: Any) -> QuietHoursSchedule? {
        guard
            let entry = entry as? [String: Any],
            let start = entry[Field.start] as? Int, let end = entry[Field.end] as? Int,
            let dayNumbers = entry[Field.days] as? [Int],
            let isOn = entry[Field.isOn] as? Bool,
            let startTime = time(minutes: start), let endTime = time(minutes: end)
        else { return nil }
        let days = dayNumbers.compactMap(RepeatRule.Weekday.init(rawValue:))
        // A day that isn't a weekday makes the whole entry unreadable, not a schedule on fewer days.
        guard days.count == dayNumbers.count else { return nil }
        return try? QuietHoursSchedule(start: startTime, end: endTime, days: Set(days), isOn: isOn)
    }

    private static func time(minutes: Int) -> TimeOfDay? {
        guard minutes >= 0 else { return nil }
        return try? TimeOfDay(hour: minutes / 60, minute: minutes % 60)
    }
}
