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
public struct QuietHoursSchedule: Equatable, Sendable {
    public let start: TimeOfDay
    public let end: TimeOfDay
    /// The days the window starts on.
    public let days: Set<RepeatRule.Weekday>
    /// Off keeps the schedule without it holding anything.
    public var isOn: Bool

    /// Throws `startEqualsEnd` when `start` is `end`.
    public init(start: TimeOfDay, end: TimeOfDay, days: Set<RepeatRule.Weekday>, isOn: Bool = true) throws {
        guard start != end else { throw QuietHoursError.startEqualsEnd }
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
}

extension RepeatRule.Weekday {
    /// The day before, counted on the week, not by a date, so a daylight saving change can't move it.
    var previous: RepeatRule.Weekday {
        RepeatRule.Weekday(rawValue: (rawValue + 5) % 7 + 1) ?? .sunday
    }
}

extension Engine {
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
