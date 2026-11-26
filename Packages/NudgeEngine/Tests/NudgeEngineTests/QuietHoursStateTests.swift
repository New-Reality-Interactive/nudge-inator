import Foundation
import Testing
@testable import NudgeEngine

/// What Settings' Quiet Hours row reads (#370): whether quiet hours hold nudges now and until when,
/// or when the next schedule that's on starts, or that none is on. Every test names its time zone.
struct QuietHoursStateTests {
    // 2026-11-15 is a Sunday, so the 16th is a Monday.
    func engine(_ schedules: [QuietHoursSchedule]) -> Engine {
        Engine(
            clock: FakeClock(now: NewYork.local(2026, 11, 15)),
            scheduler: FakeScheduler(),
            timeZone: NewYork.timeZone,
            quietHours: QuietHours(schedules: schedules)
        )
    }

    func schedule(_ start: Int, _ end: Int, on days: Set<RepeatRule.Weekday>, isOn: Bool = true) throws -> QuietHoursSchedule {
        try QuietHoursSchedule(start: TimeOfDay(hour: start), end: TimeOfDay(hour: end), days: days, isOn: isOn)
    }

    @Test func aNightWindowHoldsUntilItsEndTheNextMorning() throws {
        let engine = engine([try schedule(22, 7, on: [.sunday])])
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 15, 23, 0)) == .quietUntil(NewYork.local(2026, 11, 16, 7, 0)))
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 16, 6, 0)) == .quietUntil(NewYork.local(2026, 11, 16, 7, 0)))
    }

    @Test func aWindowInsideOneDayHoldsUntilItsEndThatDay() throws {
        let engine = engine([try schedule(13, 15, on: [.sunday])])
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 15, 14, 0)) == .quietUntil(NewYork.local(2026, 11, 15, 15, 0)))
    }

    /// 2026-03-08, a Sunday, has no 2:30 AM in New York: the clocks go from 2:00 to 3:00, so
    /// nudges get through at 3:00.
    @Test func anEndTheClocksSkipIsTheNextTimeThatExists() throws {
        let earlyMorning = try QuietHoursSchedule(start: TimeOfDay(hour: 1), end: TimeOfDay(hour: 2, minute: 30), days: [.sunday])
        let engine = engine([earlyMorning])
        #expect(engine.quietHoursState(at: NewYork.local(2026, 3, 8, 1, 30)) == .quietUntil(NewYork.local(2026, 3, 8, 3, 0)))
    }

    @Test func overlappingWindowsHoldUntilTheLaterEnd() throws {
        let engine = engine([try schedule(22, 7, on: [.sunday]), try schedule(23, 8, on: [.sunday])])
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 15, 23, 30)) == .quietUntil(NewYork.local(2026, 11, 16, 8, 0)))
    }

    @Test func backToBackWindowsHoldUntilTheLastOneEnds() throws {
        // Sunday 10 PM to Monday 7 AM, then Monday 7 AM to 9 AM: nudges get through at 9.
        let engine = engine([try schedule(22, 7, on: [.sunday]), try schedule(7, 9, on: [.monday])])
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 15, 23, 0)) == .quietUntil(NewYork.local(2026, 11, 16, 9, 0)))
    }

    @Test func outsideAWindowItSaysWhenTheNextOneStarts() throws {
        let engine = engine([try schedule(22, 7, on: [.sunday]), try schedule(23, 8, on: [.friday])])
        // Sunday afternoon: tonight's.
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 15, 14, 0)) == .startsAt(NewYork.local(2026, 11, 15, 22, 0)))
        // Monday morning, after Sunday night's ended: Friday's, days away.
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 16, 8, 0)) == .startsAt(NewYork.local(2026, 11, 20, 23, 0)))
        // Next Sunday, a week on, once Friday's has passed.
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 21, 9, 0)) == .startsAt(NewYork.local(2026, 11, 22, 22, 0)))
    }

    @Test func aScheduleThatIsOffIsNotTheNextStart() throws {
        let engine = engine([try schedule(13, 15, on: [.sunday], isOn: false), try schedule(22, 7, on: [.sunday])])
        #expect(engine.quietHoursState(at: NewYork.local(2026, 11, 15, 12, 0)) == .startsAt(NewYork.local(2026, 11, 15, 22, 0)))
    }

    @Test func withNoScheduleOnItIsOff() throws {
        let now = NewYork.local(2026, 11, 15, 23, 0)
        #expect(engine([]).quietHoursState(at: now) == .off)
        #expect(engine([try schedule(22, 7, on: [.sunday], isOn: false)]).quietHoursState(at: now) == .off)
    }
}
