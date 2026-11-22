import Foundation
import NudgeEngine

/// What Add Schedule's or a schedule's sheet holds while the person changes it (#371, the approved
/// Quiet Hours page mockup): the start, the end and the days, and what stops Save. A new schedule
/// starts at 10:00 PM to 7:00 AM, every day, on; an edited one starts as saved and keeps its
/// identity and its switch.
struct QuietHoursScheduleDraft {
    var start: TimeOfDay
    var end: TimeOfDay
    private(set) var days: Set<RepeatRule.Weekday>

    /// The schedule being edited, as it was saved, or nil for a new one.
    let saved: QuietHoursSchedule?
    /// What the sheet opened with, so Cancel knows whether anything would be lost.
    private let openedStart: TimeOfDay
    private let openedEnd: TimeOfDay
    private let openedDays: Set<RepeatRule.Weekday>
    /// A new schedule's identity, made once so saving a draft twice can't add two schedules.
    private let newID = UUID()

    /// Why Save is off, said under the times or under the days.
    enum Problem: Equatable {
        case startEqualsEnd
        case noDays

        var message: LocalizedStringResource {
            switch self {
            case .startEqualsEnd:
                LocalizedStringResource("The start and end are the same. Change one to save.",
                                        comment: "Add Schedule and Edit Schedule (quiet hours): under Starts and Ends, in red, while they are the same time, so Save is off.")
            case .noDays:
                LocalizedStringResource("Choose at least one day to save.",
                                        comment: "Add Schedule and Edit Schedule (quiet hours): under the days, in red, while no day is checked, so Save is off.")
            }
        }
    }

    /// A new schedule.
    init() {
        self.init(start: TimeOfDay(wrappingMinutes: 22 * 60), end: TimeOfDay(wrappingMinutes: 7 * 60),
                  days: Set(RepeatRule.Weekday.allCases), saved: nil)
    }

    init(editing schedule: QuietHoursSchedule) {
        self.init(start: schedule.start, end: schedule.end, days: schedule.days, saved: schedule)
    }

    private init(start: TimeOfDay, end: TimeOfDay, days: Set<RepeatRule.Weekday>, saved: QuietHoursSchedule?) {
        self.start = start
        self.end = end
        self.days = days
        self.saved = saved
        openedStart = start
        openedEnd = end
        openedDays = days
    }

    var isNew: Bool { saved == nil }

    /// Checks `day`, or unchecks it if it was checked.
    mutating func toggle(_ day: RepeatRule.Weekday) {
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
    }

    /// What stops Save, the times' first.
    var problems: [Problem] {
        var problems: [Problem] = []
        if start == end { problems.append(.startEqualsEnd) }
        if days.isEmpty { problems.append(.noDays) }
        return problems
    }

    /// The schedule Save writes, or nil while a problem stops it.
    var schedule: QuietHoursSchedule? {
        guard problems.isEmpty else { return nil }
        return try? QuietHoursSchedule(id: saved?.id ?? newID, start: start, end: end, days: days, isOn: saved?.isOn ?? true)
    }

    /// Whether Cancel would lose anything: the times or days differ from what the sheet opened with.
    var hasChanges: Bool {
        start != openedStart || end != openedEnd || days != openedDays
    }
}
