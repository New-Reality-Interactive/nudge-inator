import Foundation
import Testing
@testable import NudgeEngine

/// My Day on another day (#374): a past day as its history recorded it, a future day as what falls
/// due on it, and the range of days My Day can show. A day is the local day in the engine's time
/// zone, New York here, whatever the Mac's or the simulator's.
struct MyDayOtherDaysTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 6))
    let scheduler = FakeScheduler()

    let yesterday = CalendarDay(year: 2026, month: 10, day: 15)
    let today = CalendarDay(year: 2026, month: 10, day: 16)
    let tomorrow = CalendarDay(year: 2026, month: 10, day: 17)

    let meds = Reminder(title: "Morning meds", dueTime: NewYork.local(2026, 10, 1, 6, 30), repeatRule: .everyDay, strength: .gentle, createdAt: NewYork.local(2026, 9, 30, 20))
    let dog = Reminder(title: "Walk the dog", dueTime: NewYork.local(2026, 10, 1, 7), repeatRule: .everyDay, strength: .gentle, createdAt: NewYork.local(2026, 9, 30, 20))

    /// 13:00 on Friday 16 October. Yesterday the dog was walked at 7:10 and the meds were never
    /// taken, so they gave up; today the dog was walked at 7:05 and the meds are Missed again.
    func engineAtOnePM(_ more: [Reminder] = []) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [meds, dog] + more)
        clock.now = NewYork.local(2026, 10, 15, 7, 10)
        engine.markDone(dog.id)
        clock.now = NewYork.local(2026, 10, 16, 7, 5)
        engine.markDone(dog.id)
        clock.now = NewYork.local(2026, 10, 16, 13)
        engine.update(reminders: engine.reminders)
        return engine
    }

    @Test func aPastDayListsEachOccurrenceAsItsHistoryRecordedIt() {
        let engine = engineAtOnePM()

        let items = engine.myDay(on: yesterday).items

        #expect(items.map(\.reminderID) == [meds.id, dog.id])
        #expect(items.map(\.dueTime) == [NewYork.local(2026, 10, 15, 6, 30), NewYork.local(2026, 10, 15, 7)])
        #expect(items.map(\.status) == [.due(.missed(reason: .giveUpLimit)), .due(.done)])
    }

    /// Stretching was made this morning with a first due time two weeks back, so its rule reaches
    /// yesterday, but it didn't exist then: yesterday doesn't list it, and today does.
    @Test func aReminderCreatedAfterAPastDayIsntListedOnIt() {
        let stretch = Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 1, 10), repeatRule: .everyDay, strength: .gentle, createdAt: NewYork.local(2026, 10, 16, 8))
        let engine = engineAtOnePM([stretch])

        #expect(!engine.myDay(on: yesterday).items.map(\.reminderID).contains(stretch.id))
        #expect(engine.myDay(on: today).items.map(\.reminderID).contains(stretch.id))
    }

    /// Tomorrow lists what falls due on it: the dog as Left, and the meds as Paused, since Pause is
    /// on. Alex is nudging today, which leaves tomorrow's Nudging count at zero.
    @Test func aFutureDayListsWhatFallsDueAsLeftOrPaused() {
        let alex = Reminder(title: "Reply to Alex", dueTime: NewYork.local(2026, 10, 1, 12, 30), repeatRule: .everyDay, strength: .firm, createdAt: NewYork.local(2026, 9, 30, 20))
        var engine = engineAtOnePM([alex])
        engine.pause(meds.id)

        let myDay = engine.myDay(on: tomorrow)

        #expect(myDay.items.map(\.reminderID) == [meds.id, dog.id, alex.id])
        #expect(myDay.items.map(\.status) == [.paused, .left, .left])
        #expect(myDay.items.first?.dueTime == NewYork.local(2026, 10, 17, 6, 30))
        #expect(myDay.count(of: .nudging) == 0)
        #expect(engine.myDay(on: today).count(of: .nudging) == 1)
    }

    /// The counts and the tag filter work on every day.
    @Test func theTagFilterAndCountsApplyOnAnotherDay() {
        let home = Tag(name: "home")
        var engine = engineAtOnePM()
        engine.update(tags: [home])
        var homeDog = dog
        homeDog.tagIDs = [home.id]
        engine.update(reminders: [meds, homeDog])

        let filtered = engine.myDay(on: yesterday, tagFilter: .matchAll([home.id]))

        #expect(filtered.items.map(\.reminderID) == [dog.id])
        #expect(filtered.count(of: .done) == 1)
        #expect(filtered.count(of: .missed) == 0)
        #expect(engine.myDay(on: yesterday).count(of: .missed) == 1)
    }

    /// Back to the day the earliest reminder was made, in New York (23:30 there is already the
    /// next day in UTC), and forward 7 days, as Coming Up looks.
    @Test func theRangeRunsFromTheEarliestCreationDayToSevenDaysAhead() {
        let old = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 1, 9), repeatRule: .everyDay, strength: .gentle, createdAt: NewYork.local(2026, 9, 12, 23, 30))
        let engine = engineAtOnePM([old])

        #expect(engine.myDayRange == CalendarDay(year: 2026, month: 9, day: 12)...CalendarDay(year: 2026, month: 10, day: 23))
    }

    @Test func withNoRemindersTheRangeIsJustToday() {
        clock.now = NewYork.local(2026, 10, 16, 13)
        let engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)

        #expect(engine.myDayRange == today...today)
    }

    /// The swipe and Previous Day and Next Day move one calendar day (#375): across a month end, a
    /// year end, and New York's clock change on 1 November, whose day is 25 hours long.
    @Test(arguments: [
        (CalendarDay(year: 2026, month: 10, day: 31), 1, CalendarDay(year: 2026, month: 11, day: 1)),
        (CalendarDay(year: 2026, month: 11, day: 1), 1, CalendarDay(year: 2026, month: 11, day: 2)),
        (CalendarDay(year: 2026, month: 11, day: 2), -1, CalendarDay(year: 2026, month: 11, day: 1)),
        (CalendarDay(year: 2026, month: 1, day: 1), -1, CalendarDay(year: 2025, month: 12, day: 31)),
        (CalendarDay(year: 2026, month: 10, day: 16), 7, CalendarDay(year: 2026, month: 10, day: 23)),
    ])
    func aDayMovesByWholeCalendarDays(from day: CalendarDay, by days: Int, to expected: CalendarDay) {
        let engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)

        #expect(engine.day(day, movedBy: days) == expected)
    }

    /// My Day's day label and its sentences name a day by its date (#375), with the year only when
    /// it isn't this year's.
    @Test(arguments: [
        (CalendarDay(year: 2026, month: 9, day: 29), "Tuesday, September 29", "Tue, Sep 29"),
        (CalendarDay(year: 2025, month: 12, day: 29), "Monday, December 29, 2025", "Mon, Dec 29, 2025"),
    ])
    func aDayIsNamedByItsDateWithTheYearOnlyWhenItIsAnotherYears(day: CalendarDay, long: String, short: String) {
        clock.now = NewYork.local(2026, 10, 16, 13)
        let engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, locale: Locale(identifier: "en_US"))

        #expect(String(localized: engine.longDate(of: day)) == long)
        #expect(String(localized: engine.shortDate(of: day)) == short)
    }

    /// The developer's answer to question 6 (2026-11-23): an Edit that moves the due time keeps
    /// how every past occurrence closed, not only the latest and the last 24 hours', so the meds
    /// Missed on the 14th and the 15th still show at 6:30 on those days, and the evening time
    /// starts after the Edit. At 15:00 today's meds have given up too, so the due time can change.
    @Test(arguments: [14, 15])
    func anEditThatMovesTheDueTimeKeepsEveryPastDaysOutcome(day: Int) throws {
        var engine = engineAtOnePM()
        clock.now = NewYork.local(2026, 10, 16, 15)
        var evening = meds
        evening.dueTime = NewYork.local(2026, 10, 1, 21)
        try engine.edit(evening)

        let items = engine.myDay(on: CalendarDay(year: 2026, month: 10, day: day)).items.filter { $0.reminderID == meds.id }

        #expect(items.map(\.dueTime) == [NewYork.local(2026, 10, day, 6, 30)])
        #expect(items.map(\.status) == [.due(.missed(reason: .giveUpLimit))])
    }

    /// Every day at 9:00 from 1 October, Firm, received from someone.
    func received(_ state: ReminderOrigin.ReceivedState) -> Reminder {
        Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 1, 9), repeatRule: .everyDay, strength: .firm, createdAt: NewYork.local(2026, 9, 30, 20),
                 origin: .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 1, state: state))
    }

    /// The developer's answer to question 7 (2026-11-23): a past day shows what happened. Yesterday's
    /// 9:00 went unanswered before the sender deleted the reminder, so it stays Missed there;
    /// today and tomorrow say Canceled, as before.
    @Test func aCanceledCopyShowsItsHistoryOnAPastDayAndCanceledFromToday() {
        let copy = received(.accepted)
        var engine = engineAtOnePM([copy])
        engine.cancel(copy.id)

        func status(on day: CalendarDay) -> [MyDay.Status] {
            engine.myDay(on: day).items.filter { $0.reminderID == copy.id }.map(\.status)
        }

        #expect(status(on: yesterday) == [.due(.missed(reason: .giveUpLimit))])
        #expect(status(on: today) == [.canceled])
        #expect(status(on: tomorrow) == [.canceled])
    }

    /// A copy never accepted never nudged, so no past day lists it; today and tomorrow say Waiting.
    @Test func aWaitingCopyIsntListedOnAPastDay() {
        let copy = received(.waiting)
        let engine = engineAtOnePM([copy])

        func status(on day: CalendarDay) -> [MyDay.Status] {
            engine.myDay(on: day).items.filter { $0.reminderID == copy.id }.map(\.status)
        }

        #expect(status(on: yesterday).isEmpty)
        #expect(status(on: today) == [.waiting])
        #expect(status(on: tomorrow) == [.waiting])
    }

    /// Havana's clocks go from 0:00 to 1:00 on Sunday 8 March 2026, so that day has no midnight.
    /// Its My Day still ends at the next day's start: the 9th's 0:30 isn't in it.
    @Test func aDayWhoseMidnightIsSkippedEndsAtTheNextDaysStart() throws {
        let havana = try #require(TimeZone(identifier: "America/Havana"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = havana
        func local(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute)) ?? .distantPast
        }
        let clock = FakeClock(now: local(5, 12))
        let late = Reminder(title: "Lock up", dueTime: local(1, 0, 30), repeatRule: .everyDay, strength: .gentle, createdAt: local(1, 0))
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: havana)
        engine.update(reminders: [late])

        let dueTimes = engine.myDay(on: CalendarDay(year: 2026, month: 3, day: 8)).items.map(\.dueTime)

        #expect(dueTimes.allSatisfy { calendar.component(.day, from: $0) == 8 })
    }

    /// An Edit fixes only the occurrences on or after the day the reminder was made: Stretching,
    /// made this morning with its rule reaching back two weeks, keeps nothing from before today,
    /// so no past day lists it after the Edit either.
    @Test func anEditFixesNothingFromBeforeTheReminderWasMade() throws {
        let stretch = Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 1, 6), repeatRule: .everyDay, strength: .gentle, createdAt: NewYork.local(2026, 10, 16, 8))
        var engine = engineAtOnePM([stretch])
        clock.now = NewYork.local(2026, 10, 16, 15)
        var evening = stretch
        evening.dueTime = NewYork.local(2026, 10, 1, 21)
        try engine.edit(evening)

        let fixed = engine.histories[stretch.id]?.closedOccurrences.keys.sorted() ?? []

        #expect(fixed == [NewYork.local(2026, 10, 16, 6)])
    }

    /// Delete takes a reminder's history with it, so a past day no longer lists it.
    @Test func aDeletedReminderIsntListedOnAPastDay() {
        var engine = engineAtOnePM()
        engine.delete(dog.id)

        #expect(engine.myDay(on: yesterday).items.map(\.reminderID) == [meds.id])
    }
}
