import Foundation
import NudgeEngine

/// The day My Day shows (#375), kept inside its range, with the days Previous Day and Next Day go
/// to and the words that name it. A value, so the tests read it with no view.
struct MyDayShownDay: Equatable {
    /// The day listed. `nil` only with no engine, when it is today with nothing in it.
    let day: CalendarDay?
    /// How the day relates to today, for the sentences that name it.
    let name: Name
    /// The day's date, such as "Tuesday, September 29", with the year when it isn't this year's.
    let longDate: String
    /// The day before, or `nil` at the range's start.
    let previous: CalendarDay?
    /// The day after, or `nil` at the range's end.
    let next: CalendarDay?

    var isToday: Bool { name == .today }
    /// After today: a row there says how it repeats.
    var isLater: Bool {
        switch name {
        case .tomorrow, .later: true
        case .today, .yesterday, .earlier: false
        }
    }

    enum Name: Equatable {
        case today
        case yesterday
        case tomorrow
        /// Before yesterday, with its short date, such as "Tue, Sep 29".
        case earlier(String)
        /// After tomorrow, with its short date.
        case later(String)
    }

    /// The mockup's day label on yesterday and tomorrow, which put the word before the date. Any
    /// other day's label is its date alone, as the formatter gives it, so it has no sentence.
    var labelSentence: LocalizedStringResource? {
        switch name {
        case .yesterday:
            LocalizedStringResource("Yesterday, \(longDate)", comment: "My Day: the label under the title on yesterday. The placeholder is its date, such as \"Monday, September 28\".")
        case .tomorrow:
            LocalizedStringResource("Tomorrow, \(longDate)", comment: "My Day: the label under the title on tomorrow. The placeholder is its date, such as \"Wednesday, September 30\".")
        case .today, .earlier, .later:
            nil
        }
    }

    /// The label as it reads, for VoiceOver's announcement and the tests.
    var labelWords: String {
        labelSentence.map { String(localized: $0) } ?? longDate
    }

    /// `asked` is the day the person moved to, today if none. A day outside the range, as after
    /// the reminders it reached back for were deleted, becomes the nearest end.
    init(engine: Engine, asked: CalendarDay?) {
        let today = engine.today
        let range = engine.myDayRange
        let day = min(max(asked ?? today, range.lowerBound), range.upperBound)
        self.day = day
        previous = day > range.lowerBound ? engine.day(day, movedBy: -1) : nil
        next = day < range.upperBound ? engine.day(day, movedBy: 1) : nil
        longDate = engine.longDate(of: day)
        if day == today {
            name = .today
        } else if day == engine.day(today, movedBy: -1) {
            name = .yesterday
        } else if day == engine.day(today, movedBy: 1) {
            name = .tomorrow
        } else {
            name = day < today ? .earlier(engine.shortDate(of: day)) : .later(engine.shortDate(of: day))
        }
    }

    /// What the list says when it has no rows, by the chosen count, in the day's words (the
    /// mockup's `dayEmpty`). Each is a whole sentence, so a translation can agree its words.
    func emptyMessage(forCount count: MyDayCount?) -> LocalizedStringResource {
        switch name {
        case .today: Self.todaysEmptyMessage(forCount: count)
        case .yesterday: Self.yesterdaysEmptyMessage(forCount: count)
        case .tomorrow: Self.tomorrowsEmptyMessage(forCount: count)
        case .earlier(let date): Self.earlierEmptyMessage(forCount: count, date: date)
        case .later(let date): Self.laterEmptyMessage(forCount: count, date: date)
        }
    }

    private static func todaysEmptyMessage(forCount count: MyDayCount?) -> LocalizedStringResource {
        switch count {
        case nil:
            LocalizedStringResource("Nothing is due today.", comment: "My Day: the list when nothing is due today.")
        case .done:
            LocalizedStringResource("Nothing is done yet today.", comment: "My Day: the list when Done is chosen and nothing is done yet today.")
        case .nudging:
            LocalizedStringResource("Nothing is nudging you.", comment: "My Day: the list when Nudging is chosen and nothing is nudging.")
        case .missed:
            LocalizedStringResource("Nothing was missed today.", comment: "My Day: the list when Missed is chosen and nothing was missed today.")
        case .left:
            LocalizedStringResource("Nothing is left to do today.", comment: "My Day: the list when Left is chosen and nothing is left to do today.")
        }
    }

    private static func yesterdaysEmptyMessage(forCount count: MyDayCount?) -> LocalizedStringResource {
        switch count {
        case nil:
            LocalizedStringResource("Nothing was due yesterday.", comment: "My Day on yesterday: the list when nothing was due.")
        case .done:
            LocalizedStringResource("Nothing was done yesterday.", comment: "My Day on yesterday: the list when Done is chosen and nothing was done.")
        case .nudging:
            LocalizedStringResource("Nothing from yesterday is nudging you.", comment: "My Day on yesterday: the list when Nudging is chosen and nothing due yesterday is nudging.")
        case .missed:
            LocalizedStringResource("Nothing was missed yesterday.", comment: "My Day on yesterday: the list when Missed is chosen and nothing was missed.")
        case .left:
            LocalizedStringResource("Nothing from yesterday is left to do.", comment: "My Day on yesterday: the list when Left is chosen and nothing due yesterday is left to do.")
        }
    }

    private static func tomorrowsEmptyMessage(forCount count: MyDayCount?) -> LocalizedStringResource {
        switch count {
        case nil:
            LocalizedStringResource("Nothing is due tomorrow.", comment: "My Day on tomorrow: the list when nothing is due.")
        case .done:
            LocalizedStringResource("Nothing is done yet for tomorrow.", comment: "My Day on tomorrow: the list when Done is chosen, which a day still to come can't have.")
        case .nudging:
            LocalizedStringResource("Nothing from tomorrow is nudging you yet.", comment: "My Day on tomorrow: the list when Nudging is chosen, which a day still to come can't have.")
        case .missed:
            LocalizedStringResource("Nothing is missed yet for tomorrow.", comment: "My Day on tomorrow: the list when Missed is chosen, which a day still to come can't have.")
        case .left:
            LocalizedStringResource("Nothing is left to do tomorrow.", comment: "My Day on tomorrow: the list when Left is chosen and nothing is due tomorrow.")
        }
    }

    private static func earlierEmptyMessage(forCount count: MyDayCount?, date: String) -> LocalizedStringResource {
        switch count {
        case nil:
            LocalizedStringResource("Nothing was due on \(date).", comment: "My Day on a day before yesterday: the list when nothing was due. The placeholder is the day, such as \"Tue, Sep 29\".")
        case .done:
            LocalizedStringResource("Nothing was done on \(date).", comment: "My Day on a day before yesterday: the list when Done is chosen and nothing was done. The placeholder is the day, such as \"Tue, Sep 29\".")
        case .nudging:
            LocalizedStringResource("Nothing from \(date) is nudging you.", comment: "My Day on a day before yesterday: the list when Nudging is chosen and nothing due that day is nudging. The placeholder is the day, such as \"Tue, Sep 29\".")
        case .missed:
            LocalizedStringResource("Nothing was missed on \(date).", comment: "My Day on a day before yesterday: the list when Missed is chosen and nothing was missed. The placeholder is the day, such as \"Tue, Sep 29\".")
        case .left:
            LocalizedStringResource("Nothing from \(date) is left to do.", comment: "My Day on a day before yesterday: the list when Left is chosen and nothing due that day is left to do. The placeholder is the day, such as \"Tue, Sep 29\".")
        }
    }

    private static func laterEmptyMessage(forCount count: MyDayCount?, date: String) -> LocalizedStringResource {
        switch count {
        case nil:
            LocalizedStringResource("Nothing is due on \(date).", comment: "My Day on a day after tomorrow: the list when nothing is due. The placeholder is the day, such as \"Fri, Oct 2\".")
        case .done:
            LocalizedStringResource("Nothing is done yet for \(date).", comment: "My Day on a day after tomorrow: the list when Done is chosen, which a day still to come can't have. The placeholder is the day, such as \"Fri, Oct 2\".")
        case .nudging:
            LocalizedStringResource("Nothing from \(date) is nudging you yet.", comment: "My Day on a day after tomorrow: the list when Nudging is chosen, which a day still to come can't have. The placeholder is the day, such as \"Fri, Oct 2\".")
        case .missed:
            LocalizedStringResource("Nothing is missed yet for \(date).", comment: "My Day on a day after tomorrow: the list when Missed is chosen, which a day still to come can't have. The placeholder is the day, such as \"Fri, Oct 2\".")
        case .left:
            LocalizedStringResource("Nothing is left to do on \(date).", comment: "My Day on a day after tomorrow: the list when Left is chosen and nothing is due that day. The placeholder is the day, such as \"Fri, Oct 2\".")
        }
    }

    /// How the chosen tags combine, for the line under the filter tokens.
    enum TagCombination {
        case noTags, oneTag, all, any
    }

    /// The line under the filter tokens: the day and how the tags combine, not their names, which
    /// the tokens show (ticket 20).
    func filterSummary(_ combination: TagCombination) -> LocalizedStringResource {
        switch (name, combination) {
        case (.today, .noTags): LocalizedStringResource("Due today with no tags", comment: "My Day: under the No Tags filter token.")
        case (.today, .oneTag): LocalizedStringResource("Due today with the selected tag", comment: "My Day: under the filter token when one tag is chosen.")
        case (.today, .all): LocalizedStringResource("Due today with all selected tags", comment: "My Day: under the filter tokens when two or more tags are chosen and Match is All Tags.")
        case (.today, .any): LocalizedStringResource("Due today with any selected tags", comment: "My Day: under the filter tokens when two or more tags are chosen and Match is Any Tag.")
        case (.yesterday, .noTags): LocalizedStringResource("Due yesterday with no tags", comment: "My Day on yesterday: under the No Tags filter token.")
        case (.yesterday, .oneTag): LocalizedStringResource("Due yesterday with the selected tag", comment: "My Day on yesterday: under the filter token when one tag is chosen.")
        case (.yesterday, .all): LocalizedStringResource("Due yesterday with all selected tags", comment: "My Day on yesterday: under the filter tokens when two or more tags are chosen and Match is All Tags.")
        case (.yesterday, .any): LocalizedStringResource("Due yesterday with any selected tags", comment: "My Day on yesterday: under the filter tokens when two or more tags are chosen and Match is Any Tag.")
        case (.tomorrow, .noTags): LocalizedStringResource("Due tomorrow with no tags", comment: "My Day on tomorrow: under the No Tags filter token.")
        case (.tomorrow, .oneTag): LocalizedStringResource("Due tomorrow with the selected tag", comment: "My Day on tomorrow: under the filter token when one tag is chosen.")
        case (.tomorrow, .all): LocalizedStringResource("Due tomorrow with all selected tags", comment: "My Day on tomorrow: under the filter tokens when two or more tags are chosen and Match is All Tags.")
        case (.tomorrow, .any): LocalizedStringResource("Due tomorrow with any selected tags", comment: "My Day on tomorrow: under the filter tokens when two or more tags are chosen and Match is Any Tag.")
        case (.earlier(let date), .noTags), (.later(let date), .noTags):
            LocalizedStringResource("Due on \(date) with no tags", comment: "My Day on a day other than today, yesterday or tomorrow: under the No Tags filter token. The placeholder is the day, such as \"Tue, Sep 29\".")
        case (.earlier(let date), .oneTag), (.later(let date), .oneTag):
            LocalizedStringResource("Due on \(date) with the selected tag", comment: "My Day on a day other than today, yesterday or tomorrow: under the filter token when one tag is chosen. The placeholder is the day, such as \"Tue, Sep 29\".")
        case (.earlier(let date), .all), (.later(let date), .all):
            LocalizedStringResource("Due on \(date) with all selected tags", comment: "My Day on a day other than today, yesterday or tomorrow: under the filter tokens when two or more tags are chosen and Match is All Tags. The placeholder is the day, such as \"Tue, Sep 29\".")
        case (.earlier(let date), .any), (.later(let date), .any):
            LocalizedStringResource("Due on \(date) with any selected tags", comment: "My Day on a day other than today, yesterday or tomorrow: under the filter tokens when two or more tags are chosen and Match is Any Tag. The placeholder is the day, such as \"Tue, Sep 29\".")
        }
    }

    /// The filter sheet's line above Reset: how many Apply would show on the day.
    func sheetResult(due: Int) -> LocalizedStringResource {
        switch name {
        case .today:
            LocalizedStringResource("Apply shows \(due) reminders due today.", comment: "My Day's filter sheet: above Reset. The placeholder is how many reminders due today My Day would show with these filters. VoiceOver also speaks it when a choice changes it.")
        case .yesterday:
            LocalizedStringResource("Apply shows \(due) reminders due yesterday.", comment: "My Day's filter sheet on yesterday: above Reset. The placeholder is how many reminders due yesterday My Day would show with these filters. VoiceOver also speaks it when a choice changes it.")
        case .tomorrow:
            LocalizedStringResource("Apply shows \(due) reminders due tomorrow.", comment: "My Day's filter sheet on tomorrow: above Reset. The placeholder is how many reminders due tomorrow My Day would show with these filters. VoiceOver also speaks it when a choice changes it.")
        case .earlier(let date), .later(let date):
            LocalizedStringResource("Apply shows \(due) reminders due on \(date).", comment: "My Day's filter sheet on a day other than today, yesterday or tomorrow: above Reset. 1: how many reminders due that day My Day would show with these filters. 2: the day, such as \"Tue, Sep 29\". VoiceOver also speaks it when a choice changes it.")
        }
    }

    /// What VoiceOver says on arriving at the day (the mockup's `goDay`): the day and how many
    /// are due on it. Today says it is today, as its label doesn't. With a filter on it says so,
    /// without naming the tags, which the tokens show (the developer's answer to question 2).
    func announcement(due: Int, filtered: Bool) -> LocalizedStringResource {
        switch (isToday, filtered) {
        case (true, false):
            LocalizedStringResource("Today, \(labelWords). \(due) reminders due.", comment: "VoiceOver, when My Day moves back to today. 1: today's date, such as \"Monday, September 28\". 2: how many reminders are due today.")
        case (true, true):
            LocalizedStringResource("Today, \(labelWords). \(due) reminders due with your filter.", comment: "VoiceOver, when My Day moves back to today with a tag filter on. 1: today's date, such as \"Monday, September 28\". 2: how many reminders due today the filter shows.")
        case (false, false):
            LocalizedStringResource("\(labelWords). \(due) reminders due.", comment: "VoiceOver, when My Day moves to another day. 1: the day as its label reads, such as \"Tomorrow, Tuesday, September 29\". 2: how many reminders are due that day.")
        case (false, true):
            LocalizedStringResource("\(labelWords). \(due) reminders due with your filter.", comment: "VoiceOver, when My Day moves to another day with a tag filter on. 1: the day as its label reads, such as \"Tomorrow, Tuesday, September 29\". 2: how many reminders due that day the filter shows.")
        }
    }

    /// VoiceOver's name for the group of four counts.
    var countsLabel: LocalizedStringResource {
        switch name {
        case .today:
            LocalizedStringResource("Today's counts. Choose one to show only those.", comment: "VoiceOver label of the group of four counts on My Day.")
        case .yesterday:
            LocalizedStringResource("Counts for yesterday. Choose one to show only those.", comment: "VoiceOver label of the group of four counts on My Day on yesterday.")
        case .tomorrow:
            LocalizedStringResource("Counts for tomorrow. Choose one to show only those.", comment: "VoiceOver label of the group of four counts on My Day on tomorrow.")
        case .earlier(let date), .later(let date):
            LocalizedStringResource("Counts for \(date). Choose one to show only those.", comment: "VoiceOver label of the group of four counts on My Day on a day other than today, yesterday or tomorrow. The placeholder is the day, such as \"Tue, Sep 29\".")
        }
    }

    /// Today with no engine: the test host and previews.
    init(now: Date) {
        day = nil
        name = .today
        longDate = now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        previous = nil
        next = nil
    }
}
