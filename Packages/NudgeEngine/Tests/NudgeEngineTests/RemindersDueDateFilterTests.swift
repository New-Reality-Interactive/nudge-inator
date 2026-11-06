import Foundation
import Testing
@testable import NudgeEngine

/// The Reminders tab's Due Date filter: From and To, both days included, in the engine's calendar
/// and time zone (spec #104, Filter and Edge cases). At 13:00 on Friday 16 October 2026 in New York,
/// from `RemindersListTests`.
struct RemindersDueDateFilterTests {
    let fixture = RemindersListTests()

    let first = CalendarDay(year: 2026, month: 10, day: 20)
    let last = CalendarDay(year: 2026, month: 10, day: 22)

    func titles(_ engine: Engine, _ filter: RemindersFilter) -> [String] {
        engine.remindersList(filteredBy: filter).items.map(\.reminder.title)
    }

    /// One-off reminders titled by when they're due, either side of the first day and of the last.
    func boundaries() -> Engine {
        fixture.engine(holding: [
            Reminder(title: "Day before", dueTime: NewYork.local(2026, 10, 19, 23, 59), strength: .gentle),
            Reminder(title: "First day at 00:00", dueTime: NewYork.local(2026, 10, 20, 0, 0), strength: .gentle),
            Reminder(title: "Last day at 23:59", dueTime: NewYork.local(2026, 10, 22, 23, 59), strength: .gentle),
            Reminder(title: "Day after", dueTime: NewYork.local(2026, 10, 23, 0, 0), strength: .gentle),
        ])
    }

    @Test func bothDaysIncludeEveryTimeOnThoseDaysAndNothingOutsideThem() {
        #expect(titles(boundaries(), RemindersFilter(dueFrom: first, dueTo: last)) == ["First day at 00:00", "Last day at 23:59"])
    }

    @Test func noDaysNarrowNothing() {
        #expect(titles(boundaries(), RemindersFilter()).count == 4)
    }

    @Test func noFirstDayIsDueOnOrBeforeTheLast() {
        #expect(titles(boundaries(), RemindersFilter(dueTo: last)) == ["Day before", "First day at 00:00", "Last day at 23:59"])
    }

    @Test func noLastDayIsDueOnOrAfterTheFirst() {
        #expect(titles(boundaries(), RemindersFilter(dueFrom: first)) == ["First day at 00:00", "Last day at 23:59", "Day after"])
    }

    @Test func aFirstDayEqualToTheLastIsExactlyThatDay() {
        let engine = fixture.engine(holding: [
            Reminder(title: "23:59 before", dueTime: NewYork.local(2026, 10, 19, 23, 59), strength: .gentle),
            Reminder(title: "00:00", dueTime: NewYork.local(2026, 10, 20, 0, 0), strength: .gentle),
            Reminder(title: "23:59", dueTime: NewYork.local(2026, 10, 20, 23, 59), strength: .gentle),
            Reminder(title: "00:00 after", dueTime: NewYork.local(2026, 10, 21, 0, 0), strength: .gentle),
        ])

        #expect(titles(engine, RemindersFilter(dueFrom: first, dueTo: first)) == ["00:00", "23:59"])
    }

    /// The day is the engine's: 01:00 on the 20th in UTC is still the 19th in New York.
    @Test func aDayIsInTheEnginesTimeZone() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let dueTime = utc.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 1)) ?? .distantPast
        let engine = fixture.engine(holding: [Reminder(title: "Late evening", dueTime: dueTime, strength: .gentle)])

        #expect(titles(engine, RemindersFilter(dueFrom: first)) == [])
        #expect(titles(engine, RemindersFilter(dueTo: CalendarDay(year: 2026, month: 10, day: 19))) == ["Late evening"])
    }

    /// The engine's zone is injected, and its default follows the device's: `autoupdatingCurrent`
    /// changes with Settings while the app runs, so the same reminders fall on other days after a
    /// time-zone change (spec #104, Decision 61). A test can't change the device's zone, so two
    /// engines in different zones stand for the phone before and after a flight.
    @Test func theSameRemindersFallOnOtherDaysInAnotherTimeZone() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let reminders = [
            Reminder(title: "Late evening in New York", dueTime: NewYork.local(2026, 10, 21, 22), strength: .gentle),
            Reminder(title: "Morning in New York", dueTime: NewYork.local(2026, 10, 21, 8), strength: .gentle),
        ]
        let twentyFirst = RemindersFilter(dueFrom: CalendarDay(year: 2026, month: 10, day: 21), dueTo: CalendarDay(year: 2026, month: 10, day: 21))
        let twentySecond = RemindersFilter(dueFrom: CalendarDay(year: 2026, month: 10, day: 22), dueTo: CalendarDay(year: 2026, month: 10, day: 22))
        func engine(in timeZone: TimeZone) -> Engine {
            var engine = Engine(clock: fixture.clock, scheduler: fixture.scheduler, timeZone: timeZone)
            engine.update(reminders: reminders)
            return engine
        }

        // Tokyo is 13 hours ahead of New York in October: 8:00 is 21:00 the same day, and 22:00 is
        // 11:00 the next.
        #expect(titles(engine(in: NewYork.timeZone), twentyFirst) == ["Late evening in New York", "Morning in New York"])
        #expect(titles(engine(in: NewYork.timeZone), twentySecond) == [])
        #expect(titles(engine(in: tokyo), twentyFirst) == ["Morning in New York"])
        #expect(titles(engine(in: tokyo), twentySecond) == ["Late evening in New York"])
    }

    /// Without a zone passed, the engine's calendar is the device's autoupdating one, not the zone
    /// the app launched in. `autoupdatingCurrent` compares equal only to itself, so a fixed
    /// `TimeZone.current` copy would fail this.
    @Test func theDefaultTimeZoneIsTheDevicesAutoupdatingOne() {
        let engine = Engine(clock: fixture.clock, scheduler: fixture.scheduler)

        #expect(engine.calendar.timeZone == TimeZone.autoupdatingCurrent)
    }

    @Test func aNudgingReminderIsTestedByItsOpenOccurrencesDueTime() {
        // Every day at 12:30: today's is open, and tomorrow's is the next.
        let reply = Reminder(title: "Reply", dueTime: NewYork.local(2026, 10, 16, 12, 30), repeatRule: .everyDay, strength: .firm)
        let engine = fixture.engine(holding: [reply])
        let today = CalendarDay(year: 2026, month: 10, day: 16)
        let tomorrow = CalendarDay(year: 2026, month: 10, day: 17)

        #expect(engine.status(of: reply.id) == .nudging)
        #expect(titles(engine, RemindersFilter(dueFrom: today, dueTo: today)) == ["Reply"])
        #expect(titles(engine, RemindersFilter(dueFrom: tomorrow, dueTo: tomorrow)) == [])
    }

    @Test func aComingUpReminderIsTestedByItsNextDueTime() {
        // Walk the dog: every day at 7:00, today's Done, so tomorrow's is next.
        let day = fixture.oneOfEach()
        let tomorrow = CalendarDay(year: 2026, month: 10, day: 17)
        let today = CalendarDay(year: 2026, month: 10, day: 16)

        #expect(titles(day.engine, RemindersFilter(statuses: [.comingUp], dueFrom: tomorrow, dueTo: tomorrow)).contains("Walk the dog"))
        #expect(titles(day.engine, RemindersFilter(statuses: [.comingUp], dueFrom: today, dueTo: today)) == [])
    }

    @Test func aFinishedReminderIsTestedByItsLatestOccurrencesDueTime() {
        // Book the car service: due on Wednesday the 14th, and nothing more coming.
        let day = fixture.oneOfEach()
        let wednesday = CalendarDay(year: 2026, month: 10, day: 14)

        #expect(titles(day.engine, RemindersFilter(dueFrom: wednesday, dueTo: wednesday)) == ["Book the car service"])
    }

    @Test func aPausedReminderIsTestedByTheDueTimeItWouldBeSkippedAt() {
        // Stretch break: every day at 10:00, paused at 13:00 today, so tomorrow's is next.
        let day = fixture.oneOfEach()
        let tomorrow = CalendarDay(year: 2026, month: 10, day: 17)
        let today = CalendarDay(year: 2026, month: 10, day: 16)

        #expect(titles(day.engine, RemindersFilter(statuses: [.paused], dueFrom: tomorrow, dueTo: tomorrow)) == ["Stretch break"])
        #expect(titles(day.engine, RemindersFilter(statuses: [.paused], dueFrom: today, dueTo: today)) == [])
    }

    /// Nothing changes in the engine at midnight: only the clock moves, and the next due time with it.
    @Test func theRangeIsWorkedOutAfreshEitherSideOfMidnight() {
        // Every day at 00:00, paused, so its next due time is always the coming midnight.
        let walk = Reminder(title: "Midnight walk", dueTime: NewYork.local(2026, 10, 1, 0), repeatRule: .everyDay, strength: .gentle)
        let clock = fixture.clock
        clock.now = NewYork.local(2026, 9, 30, 23)
        var engine = Engine(clock: clock, scheduler: fixture.scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [walk])
        engine.pause(walk.id)
        let saturday = RemindersFilter(dueFrom: CalendarDay(year: 2026, month: 10, day: 17), dueTo: CalendarDay(year: 2026, month: 10, day: 17))
        let sunday = RemindersFilter(dueFrom: CalendarDay(year: 2026, month: 10, day: 18), dueTo: CalendarDay(year: 2026, month: 10, day: 18))

        clock.now = NewYork.local(2026, 10, 16, 23, 59)
        #expect(titles(engine, saturday) == ["Midnight walk"])
        #expect(titles(engine, sunday) == [])

        clock.now = NewYork.local(2026, 10, 17, 0, 1)
        #expect(titles(engine, saturday) == [])
        #expect(titles(engine, sunday) == ["Midnight walk"])
    }

    @Test func todayFollowsTheClockOverMidnight() {
        let clock = fixture.clock
        let engine = Engine(clock: clock, scheduler: fixture.scheduler, timeZone: NewYork.timeZone)

        clock.now = NewYork.local(2026, 10, 16, 23, 59)
        #expect(engine.today == CalendarDay(year: 2026, month: 10, day: 16))

        clock.now = NewYork.local(2026, 10, 17, 0, 0)
        #expect(engine.today == CalendarDay(year: 2026, month: 10, day: 17))
    }

    @Test func aDaysStartIsThatDayAt0000AndReadsBackAsThatDay() {
        let engine = fixture.engine(holding: [])

        #expect(engine.startOfDay(first) == NewYork.local(2026, 10, 20, 0))
        #expect(engine.calendarDay(of: engine.startOfDay(first)) == first)
    }

    @Test func theRangeNarrowsTogetherWithStatusAndSearch() {
        let engine = fixture.engine(holding: [
            Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 20, 9), strength: .gentle),
            Reminder(title: "Pay tax", dueTime: NewYork.local(2026, 10, 25, 9), strength: .gentle),
            Reminder(title: "Mow lawn", dueTime: NewYork.local(2026, 10, 20, 9), strength: .gentle),
        ])

        #expect(titles(engine, RemindersFilter(statuses: [.comingUp], dueFrom: first, dueTo: last, search: "pay")) == ["Pay rent"])
        #expect(titles(engine, RemindersFilter(statuses: [.paused], dueFrom: first, dueTo: last, search: "pay")) == [])
    }

    @Test func eitherDayCountsAsASheetFilter() {
        #expect(RemindersFilter(dueFrom: first).hasSheetFilters)
        #expect(RemindersFilter(dueTo: last).hasSheetFilters)
        #expect(!RemindersFilter().hasSheetFilters)
    }

    @Test func theTotalStaysEveryReminderUnderTheRange() {
        let shown = boundaries().remindersList(filteredBy: RemindersFilter(dueFrom: first, dueTo: first))

        #expect(shown.items.count == 1)
        #expect(shown.total == 4)
    }
}
