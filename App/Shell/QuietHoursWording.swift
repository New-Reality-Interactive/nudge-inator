import Foundation
import NudgeEngine

/// The words Settings' Quiet Hours row and page show (#370, the approved Quiet Hours page mockup):
/// the row's "Until 7:00 AM", "Starts Fri 11:00 PM" or "Off", and a schedule's range ("10:00 PM–
/// 7:00 AM") and days ("Every Sun, Mon, and Thu"), each with the words VoiceOver reads. Each is a
/// `LocalizedStringResource` with its times, weekdays and lists formatted inside it, so SwiftUI puts
/// the whole sentence into the view's language as it draws (CODING_STANDARDS.md, Localization).
struct QuietHoursWording {
    /// Its time zone and first weekday are the words'; the language is the view's. The app passes
    /// `.autoupdatingCurrent`.
    let calendar: Calendar

    /// What the row shows under its label, and what VoiceOver reads for it.
    struct Row {
        let text: LocalizedStringResource
        let spoken: LocalizedStringResource
    }

    /// While Quiet Now is on the row reads On, whatever the schedules say: the engine's state
    /// doesn't know about Quiet Now (#498). Off, it is the schedules' alone.
    func row(_ state: QuietHoursState, quietNowSince: Date?, now: Date) -> Row {
        if quietNowSince != nil {
            let on = LocalizedStringResource("On", comment: "Settings: the Quiet Hours row while Quiet Now is on, so every nudge is held.")
            return Row(text: on, spoken: on)
        }
        return scheduleRow(state, now: now)
    }

    private func scheduleRow(_ state: QuietHoursState, now: Date) -> Row {
        switch state {
        case .quietUntil(let end):
            return Row(
                text: LocalizedStringResource("Until \(end, format: timeStyle)",
                                              comment: "Settings: the Quiet Hours row while quiet hours hold nudges, with the time they get through again, such as \"Until 7:00 AM\"."),
                spoken: LocalizedStringResource("On until \(end, format: timeStyle)",
                                                comment: "Settings: what VoiceOver reads for the Quiet Hours row while quiet hours hold nudges, such as \"On until 7:00 AM\".")
            )
        case .startsAt(let start) where calendar.isDate(start, inSameDayAs: now):
            return Row(
                text: LocalizedStringResource("Starts \(start, format: timeStyle)",
                                              comment: "Settings: the Quiet Hours row when the next schedule starts later today, such as \"Starts 10:00 PM\"."),
                spoken: LocalizedStringResource("Starts at \(start, format: timeStyle)",
                                                comment: "Settings: what VoiceOver reads for the Quiet Hours row when the next schedule starts later today, such as \"Starts at 10:00 PM\".")
            )
        case .startsAt(let start):
            return Row(
                text: LocalizedStringResource("Starts \(start, format: weekdayStyle(.abbreviated)) \(start, format: timeStyle)",
                                              comment: "Settings: the Quiet Hours row when the next schedule starts on another day: the day, short, then the time, such as \"Starts Fri 11:00 PM\"."),
                spoken: LocalizedStringResource("Starts \(start, format: weekdayStyle(.wide)) at \(start, format: timeStyle)",
                                                comment: "Settings: what VoiceOver reads for the Quiet Hours row when the next schedule starts on another day, such as \"Starts Friday at 11:00 PM\".")
            )
        case .off:
            let off = LocalizedStringResource("Off", comment: "Settings: the Quiet Hours row when no schedule is on, so quiet hours never hold a nudge.")
            return Row(text: off, spoken: off)
        }
    }

    /// The line under the holding banner's title on Now, My Day and Reminders (#499, the approved
    /// Quiet hours banner mockup), or nil while nothing is held. It reads as Settings' row does:
    /// Quiet Now is until the person turns it off, whatever the schedules say, and a running schedule
    /// is until its end. Not tappable, so it says where to change quiet hours, in words alone.
    func holdingBannerDetail(_ state: QuietHoursState, quietNowSince: Date?) -> LocalizedStringResource? {
        if quietNowSince != nil {
            return LocalizedStringResource("Until you turn it off. Change this in Settings, under Quiet Hours.",
                                           comment: "Banner on Now, My Day and Reminders while Quiet Now is holding every nudge, under its title. Names where to change it: Settings, then the Quiet Hours row. Not a button.")
        }
        guard case .quietUntil(let end) = state else { return nil }
        return LocalizedStringResource("Until \(end, format: timeStyle). Change this in Settings, under Quiet Hours.",
                                       comment: "Banner on Now, My Day and Reminders while a quiet hours schedule is holding nudges, under its title, with the time they get through again, such as \"Until 7:00 AM.\" Names where to change it: Settings, then the Quiet Hours row. Not a button.")
    }

    /// Under the Quiet Now switch: what it does, or since when it has been on.
    func quietNowFooter(since: Date?) -> LocalizedStringResource {
        guard let since else {
            return LocalizedStringResource("Holds every nudge from now until you turn it off, whatever your schedules say.",
                                           comment: "Quiet Hours page: under the Quiet Now switch while it is off, saying what it does.")
        }
        return LocalizedStringResource("On since \(since, format: timeStyle). No nudge arrives until you turn it off.",
                                       comment: "Quiet Hours page: under the Quiet Now switch while it is on, with the time it was turned on, such as \"On since 8:20 AM.\"")
    }

    /// The schedule's times, as the iOS Focus schedules list writes them: "10:00 PM–7:00 AM".
    func range(_ schedule: QuietHoursSchedule) -> LocalizedStringResource {
        LocalizedStringResource("\(onReferenceDay(schedule.start), format: timeStyle)–\(onReferenceDay(schedule.end), format: timeStyle)",
                                comment: "Quiet Hours page: a schedule's times, start then end, joined by an en dash with no spaces, such as \"10:00 PM–7:00 AM\".")
    }

    /// The days the schedule starts on, in the calendar's week order: "Every Fri and Sat", or
    /// "Every day" for all seven.
    func days(_ schedule: QuietHoursSchedule) -> LocalizedStringResource {
        guard schedule.days.count < 7 else {
            return LocalizedStringResource("Every day", comment: "Quiet Hours page: under a schedule's times, when it runs on every day of the week.")
        }
        return LocalizedStringResource("Every \(weekdays(schedule), format: weekdayList)",
                                       comment: "Quiet Hours page: under a schedule's times, the days it starts on as a list of short day names, such as \"Every Fri and Sat\" or \"Every Sun, Mon, and Thu\".")
    }

    /// What VoiceOver reads for a schedule: "10:00 PM to 7:00 AM, Every Fri and Sat".
    func spoken(_ schedule: QuietHoursSchedule) -> LocalizedStringResource {
        let start = onReferenceDay(schedule.start), end = onReferenceDay(schedule.end)
        guard schedule.days.count < 7 else {
            return LocalizedStringResource("\(start, format: timeStyle) to \(end, format: timeStyle), Every day",
                                           comment: "Quiet Hours page: what VoiceOver reads for a schedule that runs every day: its start and end times, such as \"10:00 PM to 7:00 AM, Every day\".")
        }
        return LocalizedStringResource("\(start, format: timeStyle) to \(end, format: timeStyle), Every \(weekdays(schedule), format: weekdayList)",
                                       comment: "Quiet Hours page: what VoiceOver reads for a schedule: its start and end times, then the days it starts on, such as \"10:00 PM to 7:00 AM, Every Fri and Sat\".")
    }

    // MARK: The schedule's sheet (#371)

    /// The line under Starts and Ends: "Ends at 7:00 AM the next day." or "… the same day.", or
    /// nil while the start equals the end, when the sheet says why it can't be saved instead.
    func ends(_ draft: QuietHoursScheduleDraft) -> LocalizedStringResource? {
        guard draft.start != draft.end else { return nil }
        let end = onReferenceDay(draft.end)
        if draft.end < draft.start {
            return LocalizedStringResource("Ends at \(end, format: timeStyle) the next day.",
                                           comment: "Add Schedule and Edit Schedule (quiet hours): under Starts and Ends when the end is earlier than the start, so the schedule runs past midnight, such as \"Ends at 7:00 AM the next day.\"")
        }
        return LocalizedStringResource("Ends at \(end, format: timeStyle) the same day.",
                                       comment: "Add Schedule and Edit Schedule (quiet hours): under Starts and Ends when the end is later than the start on the same day, such as \"Ends at 1:30 PM the same day.\"")
    }

    /// The days of the week in the calendar's order, as the sheet's checklist lists them.
    var weekOrder: [RepeatRule.Weekday] {
        (0..<7).compactMap { RepeatRule.Weekday(rawValue: (calendar.firstWeekday - 1 + $0) % 7 + 1) }
    }

    /// A date that stands for `day`, to format its name with `dayName`.
    func date(of day: RepeatRule.Weekday) -> Date {
        calendar.date(byAdding: .day, value: day.rawValue - 1, to: referenceSunday) ?? referenceSunday
    }

    /// A day's full name, as the checklist shows it: "Sunday".
    var dayName: Date.FormatStyle { weekdayStyle(.wide) }

    /// The date a time pill shows for `time`, on a day with no clock change.
    func date(of time: TimeOfDay) -> Date {
        onReferenceDay(time)
    }

    /// The time a pill's `date` reads on the clock.
    func time(of date: Date) -> TimeOfDay? {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = parts.hour, let minute = parts.minute else { return nil }
        return try? TimeOfDay(hour: hour, minute: minute)
    }

    // MARK: Formats

    /// A time as the schedules write it, such as "10:00 PM" (and How Quiet Hours Work, #468).
    var timeStyle: Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .shortened, calendar: calendar, timeZone: calendar.timeZone)
    }

    private func weekdayStyle(_ width: Date.FormatStyle.Symbol.Weekday) -> Date.FormatStyle {
        Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(width)
    }

    private var weekdayList: ListFormatStyle<Date.FormatStyle, [Date]> {
        .list(memberStyle: weekdayStyle(.abbreviated), type: .and)
    }

    // MARK: Dates that stand for a time or a weekday

    /// 2001-01-07, a Sunday in a week with no clock change: a wall-clock time or a weekday is
    /// formatted on it, so a 2:30 AM schedule never reads 3:00 AM on the day the clocks skip 2:30.
    private var referenceSunday: Date {
        calendar.date(from: DateComponents(year: 2001, month: 1, day: 7)) ?? .distantPast
    }

    func onReferenceDay(_ time: TimeOfDay) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: referenceSunday) ?? referenceSunday
    }

    /// One date per day the schedule starts on, in the calendar's week order, standing for that weekday.
    private func weekdays(_ schedule: QuietHoursSchedule) -> [Date] {
        weekOrder.filter(schedule.days.contains).map(date(of:))
    }
}
