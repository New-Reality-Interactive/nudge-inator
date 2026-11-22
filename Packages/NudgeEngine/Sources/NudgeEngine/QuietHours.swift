import Foundation

/// A time on the clock with no day: 10 PM is `TimeOfDay(hour: 22)`. A wall-clock time, so it means
/// whatever the phone's clock reads in its time zone, including after a daylight saving change.
public struct TimeOfDay: Comparable, Hashable, Sendable {
    /// 0 to 23.
    public let hour: Int
    /// 0 to 59.
    public let minute: Int

    /// Throws `timeOutsideTheClock` for an hour not in 0 to 23 or a minute not in 0 to 59, so a
    /// saved value that doesn't read as a time is left out, not turned into another time.
    public init(hour: Int, minute: Int = 0) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else { throw QuietHoursError.timeOutsideTheClock }
        self.hour = hour
        self.minute = minute
    }

    /// The time `minutes` after midnight, wrapped onto the clock, so it never throws: 1,320 is
    /// 10 PM, 1,440 is midnight again and -60 is 11 PM. For a time written in code, such as a new
    /// schedule's start.
    public init(wrappingMinutes minutes: Int) {
        let onTheClock = ((minutes % 1440) + 1440) % 1440
        hour = onTheClock / 60
        minute = onTheClock % 60
    }

    var secondsIntoDay: Int { hour * 3600 + minute * 60 }

    public static func < (a: TimeOfDay, b: TimeOfDay) -> Bool {
        a.secondsIntoDay < b.secondsIntoDay
    }
}

/// Why a quiet hours schedule can't be made.
public enum QuietHoursError: Error, Equatable, Sendable {
    /// The hour or minute isn't one the clock shows.
    case timeOutsideTheClock
    /// The start is the end, so the window would mean nothing. A person who wants 24 hours uses
    /// two schedules.
    case startEqualsEnd
}

/// One window of quiet hours: from a start time to an end time on the days of the week it starts
/// on, switched on or off. A window whose end is not after its start crosses midnight and ends on
/// the next day: 10 PM to 7 AM on Sunday runs from Sunday 10 PM to Monday 7 AM. It includes its
/// start and ends at its end without including it.
///
/// Not a pace: a pace spaces a reminder's nudges, a schedule says when none is delivered.
///
/// Each schedule has its own identity (#371), which an edit keeps, so two schedules with the same
/// times and days are still two, and a change made on one never lands on another.
public struct QuietHoursSchedule: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let start: TimeOfDay
    public let end: TimeOfDay
    /// The days the window starts on.
    public let days: Set<RepeatRule.Weekday>
    /// Off keeps the schedule without it holding anything.
    public var isOn: Bool

    /// Throws `startEqualsEnd` when `start` is `end`. An edit passes the edited schedule's `id`; a
    /// new schedule gets one of its own.
    public init(id: UUID = UUID(), start: TimeOfDay, end: TimeOfDay, days: Set<RepeatRule.Weekday>, isOn: Bool = true) throws {
        guard start != end else { throw QuietHoursError.startEqualsEnd }
        self.id = id
        self.start = start
        self.end = end
        self.days = days
        self.isOn = isOn
    }

    /// Whether the window crosses midnight into the next day.
    var crossesMidnight: Bool { end < start }

    /// Whether this schedule is on and covers the moment that reads `secondsIntoDay` on
    /// `weekday`, a wall-clock reading in the engine's calendar.
    func covers(weekday: RepeatRule.Weekday, secondsIntoDay: Int) -> Bool {
        guard isOn else { return false }
        if !crossesMidnight {
            return days.contains(weekday) && start.secondsIntoDay <= secondsIntoDay && secondsIntoDay < end.secondsIntoDay
        }
        // The window's first part is on the day it starts on, its second on the day after.
        return (days.contains(weekday) && secondsIntoDay >= start.secondsIntoDay)
            || (days.contains(weekday.previous) && secondsIntoDay < end.secondsIntoDay)
    }
}

/// A person's quiet hours: a set of schedules. A moment is quiet when any schedule that is on
/// covers it. With no schedule, or every one off, nothing is quiet.
public struct QuietHours: Equatable, Sendable {
    public var schedules: [QuietHoursSchedule]

    public init(schedules: [QuietHoursSchedule] = []) {
        self.schedules = schedules
    }

    /// Turns the schedule `id` on or off, keeping it in its place (#370). An identity these quiet
    /// hours don't hold changes nothing.
    public mutating func switchSchedule(_ id: QuietHoursSchedule.ID, on: Bool) {
        guard let index = schedules.firstIndex(where: { $0.id == id }) else { return }
        schedules[index].isOn = on
    }

    /// Saves `schedule` (#371): an edited one replaces the one with its identity, in its place; a
    /// new one goes at the end, so the list stays in the order schedules were added.
    public mutating func saveSchedule(_ schedule: QuietHoursSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            schedules.append(schedule)
        }
    }

    /// Deletes the schedule `id` (#371). An identity these quiet hours don't hold changes nothing.
    public mutating func deleteSchedule(_ id: QuietHoursSchedule.ID) {
        schedules.removeAll { $0.id == id }
    }
}

extension RepeatRule.Weekday {
    /// The day before, counted on the week, not by a date, so a daylight saving change can't move it.
    var previous: RepeatRule.Weekday {
        RepeatRule.Weekday(rawValue: (rawValue + 5) % 7 + 1) ?? .sunday
    }
}

/// Whether quiet hours hold nudges at a moment, and until when (#370): what Settings' Quiet Hours
/// row reads.
public enum QuietHoursState: Equatable, Sendable {
    /// Nudges are held until this moment, when they get through again.
    case quietUntil(Date)
    /// Nothing is held now; the next schedule that's on starts at this moment.
    case startsAt(Date)
    /// No schedule is on, so nothing is held.
    case off
}

extension Engine {
    /// Whether quiet hours hold nudges at `date` and until when, read on the wall clock in the
    /// engine's time zone and calendar.
    public func quietHoursState(at date: Date) -> QuietHoursState {
        if let end = quietEnd(after: date) { return .quietUntil(end) }
        guard let start = nextStart(after: date) else { return .off }
        return .startsAt(start)
    }

    /// When nudges get through again, if `date` is quiet: the latest end of the windows covering
    /// it, followed on while another window covers that end, so back-to-back schedules read as one.
    /// Follows at most 14 windows, so schedules that leave no gap at all still give an answer.
    func quietEnd(after date: Date) -> Date? {
        var end: Date?
        var moment = date
        for _ in 0..<14 {
            guard let next = quietHours.schedules.compactMap({ windowEnd(of: $0, covering: moment) }).max() else { break }
            end = next
            moment = next
        }
        return end
    }

    /// The first start of a schedule that's on after `date`, looking a week and a day ahead so a
    /// schedule on `date`'s weekday whose start has passed is found a week on.
    func nextStart(after date: Date) -> Date? {
        let today = calendar.startOfDay(for: date)
        let starts = (0...7).flatMap { offset -> [Date] in
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: today),
                let weekday = RepeatRule.Weekday(rawValue: calendar.component(.weekday, from: day))
            else { return [] }
            return quietHours.schedules
                .filter { $0.isOn && $0.days.contains(weekday) }
                .compactMap { calendar.date(bySettingHour: $0.start.hour, minute: $0.start.minute, second: 0, of: day) }
        }
        return starts.filter { $0 > date }.min()
    }

    /// When the window of `schedule` that covers `date` ends, or nil if none covers it: later the
    /// same day, or the next day for a window that crosses midnight and started on `date`'s day.
    func windowEnd(of schedule: QuietHoursSchedule, covering date: Date) -> Date? {
        let parts = calendar.dateComponents([.weekday, .hour, .minute, .second], from: date)
        guard
            let weekday = parts.weekday.flatMap(RepeatRule.Weekday.init(rawValue:)),
            let hour = parts.hour, let minute = parts.minute, let second = parts.second
        else { return nil }
        let secondsIntoDay = hour * 3600 + minute * 60 + second
        guard schedule.covers(weekday: weekday, secondsIntoDay: secondsIntoDay) else { return nil }
        let endsTomorrow = schedule.crossesMidnight && secondsIntoDay >= schedule.start.secondsIntoDay
        let day = calendar.startOfDay(for: date)
        guard let endDay = calendar.date(byAdding: .day, value: endsTomorrow ? 1 : 0, to: day) else { return nil }
        return calendar.date(bySettingHour: schedule.end.hour, minute: schedule.end.minute, second: 0, of: endDay)
    }

    /// Whether `date` is quiet under the current quiet hours, read on the wall clock in the engine's
    /// time zone and calendar, so it follows the phone's clock and time zone.
    public func isQuiet(at date: Date) -> Bool {
        isQuiet(at: date, under: quietHours)
    }

    /// Whether `date` is quiet under `quietHours`, which may be ones a change has since replaced.
    func isQuiet(at date: Date, under quietHours: QuietHours) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute, .second], from: date)
        guard
            let weekday = parts.weekday.flatMap(RepeatRule.Weekday.init(rawValue:)),
            let hour = parts.hour, let minute = parts.minute, let second = parts.second
        else { return false }
        let secondsIntoDay = hour * 3600 + minute * 60 + second
        return quietHours.schedules.contains { $0.covers(weekday: weekday, secondsIntoDay: secondsIntoDay) }
    }
}
