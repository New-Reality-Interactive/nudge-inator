import Foundation
import NudgeEngine

/// What Add Schedule's or a schedule's sheet holds while the person changes it (#371, the approved
/// Quiet Hours page mockup): the start, the end, the days, the switch, and what stops Save. A new
/// schedule starts at 10:00 PM to 7:00 AM, every day, on; an edited one starts as saved and keeps
/// its identity. Edit Schedule's Schedule switch writes `isOn`, kept on Save like the rest (the
/// approved schedule switch mockup). It can't copy another schedule's start, end and days (the
/// approved duplicate schedule mockup).
struct QuietHoursScheduleDraft {
    var start: TimeOfDay
    var end: TimeOfDay
    private(set) var days: Set<RepeatRule.Weekday>
    /// Whether the schedule is on. Only Edit Schedule shows it; a new schedule is saved on.
    var isOn: Bool

    /// The schedule being edited, as it was saved, or nil for a new one.
    let saved: QuietHoursSchedule?
    /// What the sheet opened with, so Cancel knows whether anything would be lost.
    private let openedStart: TimeOfDay
    private let openedEnd: TimeOfDay
    private let openedDays: Set<RepeatRule.Weekday>
    private let openedIsOn: Bool
    /// The other schedules, which this one may not copy.
    private let others: [QuietHoursSchedule]
    /// A new schedule's identity, made once so saving a draft twice can't add two schedules.
    private let newID = UUID()

    /// Why Save is off, said under the times or under the days.
    enum Problem: Equatable {
        case startEqualsEnd
        case noDays
        case sameAsAnother

        var message: LocalizedStringResource {
            switch self {
            case .startEqualsEnd:
                LocalizedStringResource("The start and end are the same. Change one to save.",
                                        comment: "Add Schedule and Edit Schedule (quiet hours): under Starts and Ends, in red, while they are the same time, so Save is off.")
            case .noDays:
                LocalizedStringResource("Choose at least one day to save.",
                                        comment: "Add Schedule and Edit Schedule (quiet hours): under the days, in red, while no day is checked, so Save is off.")
            case .sameAsAnother:
                LocalizedStringResource("You already have a schedule with these times and days.",
                                        comment: "Add Schedule and Edit Schedule (quiet hours): under Starts and Ends, in red, while the start, end and days are another schedule's, so Save is off.")
            }
        }
    }

    /// A new schedule, among the `schedules` there are.
    init(among schedules: [QuietHoursSchedule] = []) {
        self.init(start: TimeOfDay(wrappingMinutes: 22 * 60), end: TimeOfDay(wrappingMinutes: 7 * 60),
                  days: Set(RepeatRule.Weekday.allCases), isOn: true, saved: nil, others: schedules)
    }

    /// `schedule`, among the `schedules` there are, which may hold it.
    init(editing schedule: QuietHoursSchedule, among schedules: [QuietHoursSchedule] = []) {
        self.init(start: schedule.start, end: schedule.end, days: schedule.days, isOn: schedule.isOn, saved: schedule,
                  others: schedules.filter { $0.id != schedule.id })
    }

    private init(start: TimeOfDay, end: TimeOfDay, days: Set<RepeatRule.Weekday>, isOn: Bool, saved: QuietHoursSchedule?, others: [QuietHoursSchedule]) {
        self.start = start
        self.end = end
        self.days = days
        self.isOn = isOn
        self.saved = saved
        self.others = others
        openedStart = start
        openedEnd = end
        openedDays = days
        openedIsOn = isOn
    }

    var isNew: Bool { saved == nil }

    /// Checks `day`, or unchecks it if it was checked.
    mutating func toggle(_ day: RepeatRule.Weekday) {
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
    }

    /// What stops Save, the times' first. A copy of another schedule has a start unlike its end and
    /// some days, so it never shows with the others.
    var problems: [Problem] {
        var problems: [Problem] = []
        if start == end { problems.append(.startEqualsEnd) }
        if days.isEmpty { problems.append(.noDays) }
        if others.contains(where: { $0.start == start && $0.end == end && $0.days == days }) { problems.append(.sameAsAnother) }
        return problems
    }

    /// The schedule Save writes, or nil while a problem stops it.
    var schedule: QuietHoursSchedule? {
        guard problems.isEmpty else { return nil }
        return try? QuietHoursSchedule(id: saved?.id ?? newID, start: start, end: end, days: days, isOn: isOn)
    }

    /// Whether Cancel would lose anything: the times, days or switch differ from what the sheet
    /// opened with.
    var hasChanges: Bool {
        start != openedStart || end != openedEnd || days != openedDays || isOn != openedIsOn
    }
}
