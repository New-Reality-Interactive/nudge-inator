import Foundation

/// How a repeat ends, as the form's End Repeat chooses it for any repeat, preset or custom (#287):
/// never, after a number of times, or on a date. The person never sees the rule's `COUNT` or
/// `UNTIL` (ADR 0003).
public struct RepeatEnd: Equatable, Sendable {
    public enum Ending: Hashable, Sendable {
        case never
        case afterCount
        case onDate
    }

    public var ending: Ending
    /// How many times it falls due when it ends after a count, kept while another ending is chosen.
    public var count: Int
    /// The last day it can fall due when it ends on a date, any time that day. Kept while another
    /// ending is chosen.
    public var endDate: Date

    public init(ending: Ending, count: Int, endDate: Date) {
        self.ending = ending
        self.count = count
        self.endDate = endDate
    }

    /// The After stepper's limits.
    public static let counts = 2...30
}

extension Engine {
    /// A rule's end as End Repeat shows it. With no end it is Never, with After at 10 times and
    /// End Date three months after the start, the mockup's defaults. A count outside the
    /// stepper's limits is read in within them.
    public func repeatEnd(of rule: RepeatRule?, startingAt start: Date) -> RepeatEnd {
        var end = RepeatEnd(ending: .never, count: 10, endDate: calendar.date(byAdding: .month, value: 3, to: start) ?? start)
        switch rule?.end {
        case nil: break
        case .count(let count):
            end.ending = .afterCount
            end.count = count.clamped(to: RepeatEnd.counts)
        case let .untilDate(year, month, day):
            end.ending = .onDate
            end.endDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? end.endDate
        case .untilTime(let time):
            end.ending = .onDate
            end.endDate = time
        }
        return end
    }

    /// The rule ending as `end` says, in place of any end it had.
    public func rule(_ rule: RepeatRule, ending end: RepeatEnd) -> RepeatRule {
        var rule = rule
        switch end.ending {
        case .never: rule.end = nil
        case .afterCount: rule.end = .count(end.count)
        case .onDate:
            let date = end.endDate
            rule.end = .untilDate(year: calendar.component(.year, from: date), month: calendar.component(.month, from: date),
                                  day: calendar.component(.day, from: date))
        }
        return rule
    }

    /// Whether the end is on a day before the start's, the mockup's `untilTooEarly`. The end date
    /// is a whole day, so ending on the start's own day is fine.
    public func endsBeforeStart(_ end: RepeatEnd, startingAt start: Date) -> Bool {
        end.ending == .onDate && calendar.startOfDay(for: end.endDate) < calendar.startOfDay(for: start)
    }
}
