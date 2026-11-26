import Foundation
import Testing
@testable import NudgeEngine

/// Quiet Now (#497): one on or off state beside the schedules. While it is on, every nudge due
/// from the moment it was turned on is held, and it never ends by itself. Monday 2026-11-16 in
/// New York; the 9:00 Relentless occurrence nudges at 9:00, 9:10, 9:15, 9:17:30, then every 2
/// minutes from nudge 5 at 9:19:30 to nudge 20 at 9:49:30 (see `HeldNudgeTests`).
struct QuietNowTests {
    let dueTime = NewYork.local(2026, 11, 16)
    let clock = FakeClock(now: NewYork.local(2026, 11, 16, 8, 0))
    let scheduler = FakeScheduler()

    func engine(with reminders: [Reminder], quietHours: QuietHours = QuietHours()) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, quietHours: quietHours)
        engine.update(reminders: reminders)
        return engine
    }

    func reminder(_ strength: Strength = .relentless, breakThroughFocus: Bool = true) -> Reminder {
        Reminder(title: "Leave for the train", dueTime: dueTime, strength: strength, breakThroughFocus: breakThroughFocus)
    }

    func planned() throws -> [Int] {
        try #require(scheduler.lastPlan).items.map(\.nudgeNumber)
    }

    func turnedOn(at date: Date, from quietHours: QuietHours = QuietHours()) -> QuietHours {
        var quietHours = quietHours
        quietHours.turnOnQuietNow(at: date)
        return quietHours
    }

    @Test func itIsOffUntilTurnedOnAndReadsSinceWhen() {
        var quietHours = QuietHours()
        #expect(quietHours.quietNowSince == nil)

        let since = NewYork.local(2026, 11, 16, 9, 20)
        quietHours.turnOnQuietNow(at: since)
        #expect(quietHours.quietNowSince == since)

        quietHours.turnOffQuietNow()
        #expect(quietHours.quietNowSince == nil)
    }

    /// Turning it on again while it is on keeps the first moment, so nothing already held is lost.
    @Test func turningItOnAgainKeepsTheFirstMoment() {
        let first = NewYork.local(2026, 11, 16, 9, 20)
        var quietHours = turnedOn(at: first)

        quietHours.turnOnQuietNow(at: NewYork.local(2026, 11, 16, 9, 30))

        #expect(quietHours.quietNowSince == first)
    }

    /// Turned on at 9:20: nudges 1 to 5 were sent, 6 (9:21:30) onward are held.
    @Test func turningItOnHoldsEveryNudgeDueFromThatMoment() throws {
        var engine = engine(with: [reminder()])
        clock.now = NewYork.local(2026, 11, 16, 9, 20)

        engine.update(quietHours: turnedOn(at: clock.now))

        #expect(try planned() == [1, 2, 3, 4, 5])
    }

    /// No schedule is set, and the strength and Break Through Focus change nothing.
    @Test(arguments: [Strength.gentle, .firm, .relentless], [true, false])
    func itHoldsEveryStrengthWhateverBreakThroughFocusIs(strength: Strength, breakThroughFocus: Bool) throws {
        var engine = engine(with: [reminder(strength, breakThroughFocus: breakThroughFocus)])
        clock.now = NewYork.local(2026, 11, 16, 8, 30)

        engine.update(quietHours: turnedOn(at: clock.now))

        #expect(try planned().isEmpty)
    }

    /// Schedules that are off or elsewhere don't matter: Quiet Now holds by itself.
    @Test func itHoldsWithSchedulesThatAreOff() throws {
        let off = QuietHours(schedules: [try QuietHoursSchedule(start: TimeOfDay(hour: 1), end: TimeOfDay(hour: 2), days: [.monday], isOn: false)])
        var engine = engine(with: [reminder()], quietHours: off)
        clock.now = NewYork.local(2026, 11, 16, 8, 30)

        engine.update(quietHours: turnedOn(at: clock.now, from: off))

        #expect(try planned().isEmpty)
    }

    /// It never ends by itself: still on hours later, a reminder due the next day is held.
    @Test func itNeverEndsByItself() throws {
        var engine = engine(with: [])
        clock.now = NewYork.local(2026, 11, 16, 8, 0)
        engine.update(quietHours: turnedOn(at: clock.now))
        let nextWeek = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 11, 23, 9), strength: .firm)

        engine.update(reminders: [nextWeek])

        #expect(try planned().isEmpty)
        #expect(engine.isHeld(firingAt: NewYork.local(2026, 11, 23, 9)))
    }

    /// Off at 9:40: nudges 16 (9:41:30) to 20 come back at their own times, with no catch-up.
    @Test func turningItOffSchedulesTheNextNudgesOnTheLadderWithNoCatchUp() throws {
        var engine = engine(with: [reminder()])
        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        engine.update(quietHours: turnedOn(at: clock.now))

        clock.now = NewYork.local(2026, 11, 16, 9, 40)
        engine.update(quietHours: QuietHours())

        // 1 to 5 were sent before it was on and 6 to 15 stay held: nothing from the hold comes back.
        #expect(try planned() == Array(1...5) + Array(16...20))
        let items = try #require(scheduler.lastPlan).items
        #expect(items.first { $0.nudgeNumber == 16 }?.fireTime == NewYork.local(2026, 11, 16, 9, 41).addingTimeInterval(30))
    }

    /// Held 9:20 to 9:40 is nudges 6 to 15: 10 of 20, still 10 after it is turned off and after a
    /// relaunch that hands the replaced quiet hours back.
    @Test func aMissedOccurrencesHeldCountIncludesWhatQuietNowHeldAndStaysAfterItIsOff() throws {
        let train = reminder()
        var engine = engine(with: [train])
        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        engine.update(quietHours: turnedOn(at: clock.now))
        clock.now = NewYork.local(2026, 11, 16, 9, 40)
        engine.update(quietHours: QuietHours())

        clock.now = NewYork.local(2026, 11, 16, 10, 0)
        let closed = try #require(engine.closedOccurrence(of: train.id, dueAt: dueTime))
        #expect(closed.occurrence.state == .missed(reason: .giveUpLimit))
        #expect(closed.nudgesHeld == 10)
        #expect(closed.missedNudgesHeld == 10)

        var relaunched = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, quietHours: QuietHours())
        relaunched.update(replacedQuietHours: engine.replacedQuietHours)
        relaunched.update(reminders: [train])
        #expect(relaunched.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 10)
    }

    /// Still on at the close: the held count reads 15 (nudges 6 to 20).
    @Test func aMissedOccurrenceHeldByQuietNowStillOnCountsEveryNudgeSince() throws {
        let train = reminder()
        var engine = engine(with: [train])
        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        engine.update(quietHours: turnedOn(at: clock.now))

        clock.now = NewYork.local(2026, 11, 16, 10, 0)

        #expect(engine.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 15)
    }

    @Test func aScheduleAndQuietNowTogetherHoldWhateverEitherDoes() throws {
        let nineToQuarterPast = QuietHours(schedules: [
            try QuietHoursSchedule(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 9, minute: 16), days: [.monday]),
        ])
        var engine = engine(with: [reminder()], quietHours: nineToQuarterPast)
        #expect(try planned() == Array(4...20))

        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        engine.update(quietHours: turnedOn(at: clock.now, from: nineToQuarterPast))
        #expect(try planned() == [4, 5])

        clock.now = NewYork.local(2026, 11, 16, 9, 40)
        var off = nineToQuarterPast
        off.turnOffQuietNow()
        engine.update(quietHours: off)
        #expect(try planned() == [4, 5] + Array(16...20))
    }

    @Test func aDefaultInstallThatNeverTurnsItOnPlansAsBefore() throws {
        _ = engine(with: [reminder()])

        #expect(try planned() == Array(1...20))
    }
}
