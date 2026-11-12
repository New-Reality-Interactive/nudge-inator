import Foundation
import NudgeEngine

/// A repeating sent reminder's 7-day history as one person's copy reports it (ticket 207, GLOSSARY's
/// 7-day history, DESIGN.md's 7-day history): the strip under a Sent row's text, and the list on the
/// details. Read from the engine's calendar and locale at one moment. A value, so the tests and
/// previews read it with no view.
struct SentHistory: Equatable {
    /// Today and the 7 days before, oldest first: the strip's eight cells.
    let days: [Day]
    /// What VoiceOver reads for the whole strip, one day after another, such as "Thursday: Done,
    /// Friday: Missed, …, Today: Coming up". Each day is a whole localized string, and the days are
    /// joined with the locale's list format.
    let voiceOverValue: String

    /// One day of the history.
    struct Day: Equatable, Identifiable {
        var day: CalendarDay
        /// The weekday's initial, such as "T", the cell's text.
        var initial: String
        /// "Today", or a short date such as "Wed, Oct 21": the details' row.
        var label: String
        /// The status of the occurrence due that day, or `nil` when none was.
        var status: ReportedStatus?
        var isToday: Bool

        var id: CalendarDay { day }
    }

    /// The details list the days newest first, today at the top, as the mockup's `viewSent` does.
    var newestFirst: [Day] { days.reversed() }

    init(engine: Engine, occurrences: [StatusReport.OccurrenceStatus]) {
        let history = engine.sevenDayHistory(of: occurrences)
        let today = engine.dayLabel(of: engine.startOfDay(engine.today))
        days = history.days.map { day in
            Day(
                day: day.day,
                initial: engine.weekdayInitial(of: day.day),
                label: day.isToday ? today : engine.shortDate(of: engine.startOfDay(day.day)),
                status: day.status,
                isToday: day.isToday
            )
        }
        voiceOverValue = history.days
            .map { day in String(localized: Self.spoken(day.isToday ? today : engine.weekdayName(of: day.day), day.status)) }
            .formatted(.list(type: .and, width: .narrow))
    }

    private static func spoken(_ day: String, _ status: ReportedStatus?) -> LocalizedStringResource {
        guard let status else {
            return LocalizedStringResource("\(day): Nothing due", comment: "VoiceOver, a repeating sent reminder's last 7 days on the Sent view: a day the person's copy had nothing due. The placeholder is the weekday, such as \"Thursday\", or \"Today\".")
        }
        let name = String(localized: status.name)
        return LocalizedStringResource("\(day): \(name)", comment: "VoiceOver, a repeating sent reminder's last 7 days on the Sent view: one day and how the person's copy went. 1: the weekday, such as \"Thursday\", or \"Today\". 2: the status, such as \"Done\" or \"Missed\".")
    }

    /// What the details say for a day with nothing due, where a status would trail.
    static let nothingDueText = LocalizedStringResource("Nothing due", comment: "A sent reminder's details, under \"<name>, Last 7 Days\": the person's copy had nothing due that day.")
}
