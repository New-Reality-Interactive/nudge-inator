import Foundation
import Testing
import NudgeEngine

/// The 7-day history a Sent row shows for a repeating reminder (ticket 207, spec #127 Status): the
/// eight days, today and the 7 before, worked out from a status report's occurrences and the
/// engine's today.
struct SevenDayHistoryTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 12))

    var engine: Engine {
        Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone)
    }

    func day(_ month: Int, _ day: Int, year: Int = 2026) -> CalendarDay {
        CalendarDay(year: year, month: month, day: day)
    }

    /// An occurrence due at 9:00 on `day` October 2026, or in `month`.
    func occurrence(_ day: Int, month: Int = 10, at hour: Int = 9, _ label: ReportedStatus) -> StatusReport.OccurrenceStatus {
        StatusReport.OccurrenceStatus(dueTime: NewYork.local(2026, month, day, hour), day: self.day(month, day), label: label)
    }

    func occurrences(_ occurrences: StatusReport.OccurrenceStatus...) -> [StatusReport.OccurrenceStatus] {
        occurrences
    }

    @Test func aDailyReminderShowsTodayAndTheSevenDaysBeforeOldestFirst() {
        let history = engine.sevenDayHistory(of: occurrences(
            occurrence(8, .done), occurrence(9, .done), occurrence(10, .missed), occurrence(11, .done),
            occurrence(12, .skipped), occurrence(13, .done), occurrence(14, .paused), occurrence(15, .nudging)
        ))

        #expect(history.days.map(\.day) == (8...15).map { day(10, $0) })
        #expect(history.days.map(\.status) == [.done, .done, .missed, .done, .skipped, .done, .paused, .nudging])
        #expect(history.days.map(\.isToday) == [false, false, false, false, false, false, false, true])
    }

    @Test func aDayWithNothingDueHasNoStatusAndDaysOutsideTheEightAreLeftOut() {
        // Every Monday and Thursday: 5, 8, 12 and 15 October.
        let history = engine.sevenDayHistory(of: occurrences(
            occurrence(5, .done), occurrence(8, .missed), occurrence(12, .done), occurrence(15, .comingUp)
        ))

        #expect(history.days.map(\.status) == [.missed, nil, nil, nil, .done, nil, nil, .comingUp])
    }

    @Test func twoOccurrencesOnOneDayShowTheLaterOnes() {
        let history = engine.sevenDayHistory(of: occurrences(occurrence(14, at: 9, .missed), occurrence(14, at: 18, .done)))

        #expect(history.days[6].status == .done)
    }

    @Test func theDaysReachBackAcrossAMonthsEnd() {
        clock.now = NewYork.local(2026, 11, 3, 0, 30)

        let history = engine.sevenDayHistory(of: occurrences(occurrence(27, .done), occurrence(3, month: 11, .comingUp)))

        #expect(history.days.map(\.day) == [day(10, 27), day(10, 28), day(10, 29), day(10, 30), day(10, 31), day(11, 1), day(11, 2), day(11, 3)])
        #expect(history.days.first?.status == .done)
        #expect(history.days.last?.status == .comingUp)
    }

    @Test func aRecipientADayAheadKeepsTheirTodayAsTheLastDay() {
        // 11 PM on the 15th here; already the 16th where the recipient is.
        clock.now = NewYork.local(2026, 10, 15, 23)

        let history = engine.sevenDayHistory(of: occurrences(occurrence(9, .done), occurrence(15, .done), occurrence(16, .comingUp)))

        #expect(history.days.map(\.day) == (9...16).map { day(10, $0) })
        #expect(history.days.last?.status == .comingUp)
        #expect(history.days.last?.isToday == true)
    }
}
