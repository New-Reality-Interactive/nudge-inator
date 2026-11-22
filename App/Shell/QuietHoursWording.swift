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

    func row(_ state: QuietHoursState, now: Date) -> Row {
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

    // MARK: Formats

    private var timeStyle: Date.FormatStyle {
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

    private func onReferenceDay(_ time: TimeOfDay) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: referenceSunday) ?? referenceSunday
    }

    /// One date per day the schedule starts on, in the calendar's week order, standing for that weekday.
    private func weekdays(_ schedule: QuietHoursSchedule) -> [Date] {
        (0..<7)
            .compactMap { RepeatRule.Weekday(rawValue: (calendar.firstWeekday - 1 + $0) % 7 + 1) }
            .filter(schedule.days.contains)
            .compactMap { calendar.date(byAdding: .day, value: $0.rawValue - 1, to: referenceSunday) }
    }
}
