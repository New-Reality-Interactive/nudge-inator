import Foundation
import Testing
@testable import NudgeEngine

/// The spec's Quiet hours rule: a moment is quiet when any schedule that is on covers it. Every
/// test names its time zone, so none depends on the Mac's or the simulator's.
struct QuietHoursTests {
    // 2026-11-15 is a Sunday, so the 16th is a Monday.
    func engine(_ schedules: [QuietHoursSchedule], timeZone: TimeZone = NewYork.timeZone) -> Engine {
        Engine(
            clock: FakeClock(now: NewYork.local(2026, 11, 15)),
            scheduler: FakeScheduler(),
            timeZone: timeZone,
            quietHours: QuietHours(schedules: schedules)
        )
    }

    func schedule(
        from start: TimeOfDay,
        to end: TimeOfDay,
        on days: Set<RepeatRule.Weekday>,
        isOn: Bool = true
    ) throws -> QuietHoursSchedule {
        try QuietHoursSchedule(start: start, end: end, days: days, isOn: isOn)
    }

    @Test func aWindowThatCrossesMidnightCoversTheDayItStartsOnAndTheNext() throws {
        let sundayNight = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: [.sunday])
        let engine = engine([sundayNight])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, 23, 0)))
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 16, 6, 0)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 6, 0)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 16, 23, 0)))
    }

    @Test func withNoScheduleNothingIsQuiet() {
        let engine = engine([])
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 23, 0)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 16, 3, 0)))
    }

    @Test func aScheduleThatIsOffHoldsNothing() throws {
        let off = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: Set(RepeatRule.Weekday.allCases), isOn: false)
        #expect(!engine([off]).isQuiet(at: NewYork.local(2026, 11, 15, 23, 0)))
    }

    @Test func anOffScheduleDoesNotStopAnOnOneFromCovering() throws {
        let off = try schedule(from: TimeOfDay(hour: 13), to: TimeOfDay(hour: 15), on: [.sunday], isOn: false)
        let on = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 23), on: [.sunday])
        let engine = engine([off, on])
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 14, 0)))
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, 22, 30)))
    }

    @Test func aWindowInsideOneDayCoversOnlyThatDay() throws {
        let afternoon = try schedule(from: TimeOfDay(hour: 13), to: TimeOfDay(hour: 15), on: [.sunday])
        let engine = engine([afternoon])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, 14, 0)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 12, 59)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 16, 0)))
        // It doesn't run on into the next day, or back into the one before.
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 16, 14, 0)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 14, 14, 0)))
    }

    @Test func aWindowIncludesItsStartAndEndsAtItsEnd() throws {
        let afternoon = try schedule(from: TimeOfDay(hour: 13), to: TimeOfDay(hour: 15, minute: 30), on: [.sunday])
        let engine = engine([afternoon])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, 13, 0)))
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, 15, 29)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 15, 30)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 15, 30).addingTimeInterval(30)))
    }

    @Test func aWindowThatCrossesMidnightIncludesItsStartAndEndsAtItsEnd() throws {
        let night = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: [.sunday])
        let engine = engine([night])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, 22, 0)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 21, 59)))
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 16, 6, 59)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 16, 7, 0)))
    }

    @Test func midnightItselfIsInsideAWindowThatCrossesIt() throws {
        let night = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: [.saturday])
        // Saturday's night runs through Sunday's midnight to 7 AM, and ends before Monday's midnight.
        #expect(engine([night]).isQuiet(at: NewYork.local(2026, 11, 15, 0, 0)))
        #expect(!engine([night]).isQuiet(at: NewYork.local(2026, 11, 16, 0, 0)))
    }

    @Test func aWindowCoversOnlyTheDaysItStartsOn() throws {
        let weeknights = try schedule(
            from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7),
            on: [.sunday, .monday, .tuesday, .wednesday, .thursday]
        )
        let engine = engine([weeknights])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 19, 23, 0)))   // Thursday night
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 20, 6, 0)))    // ends Friday morning
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 20, 23, 0)))  // Friday night isn't a start
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 21, 6, 0)))   // so Saturday morning isn't covered
    }

    @Test func overlappingSchedulesCombine() throws {
        let early = try schedule(from: TimeOfDay(hour: 20), to: TimeOfDay(hour: 23), on: [.sunday])
        let late = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: [.sunday])
        let engine = engine([early, late])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, 21, 0)))   // only the early one
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, 22, 30)))  // both
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 16, 5, 0)))    // only the late one
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 15, 19, 0)))
    }

    @Test func aScheduleWithNoDaysCoversNothing() throws {
        let none = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: [])
        #expect(!engine([none]).isQuiet(at: NewYork.local(2026, 11, 15, 23, 0)))
    }

    @Test func aStartEqualToItsEndIsRefused() {
        #expect(throws: QuietHoursError.startEqualsEnd) {
            try QuietHoursSchedule(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 9), days: [.monday])
        }
        #expect(throws: QuietHoursError.startEqualsEnd) {
            try QuietHoursSchedule(start: TimeOfDay(hour: 0), end: TimeOfDay(hour: 0), days: Set(RepeatRule.Weekday.allCases))
        }
    }

    @Test(arguments: 0..<24)
    func twentyFourHoursTakesTwoSchedules(hour: Int) throws {
        let first = try schedule(from: TimeOfDay(hour: 0), to: TimeOfDay(hour: 12), on: [.sunday])
        let second = try schedule(from: TimeOfDay(hour: 12), to: TimeOfDay(hour: 0), on: [.sunday])
        let engine = engine([first, second])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 15, hour, 30)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 16, 0, 30)))
    }

    @Test(arguments: [(24, 0), (25, 70), (-1, 0), (9, 60), (9, -1)])
    func aTimeThatTheClockDoesNotShowIsRefused(hour: Int, minute: Int) {
        #expect(throws: QuietHoursError.timeOutsideTheClock) {
            try TimeOfDay(hour: hour, minute: minute)
        }
    }

    @Test func theClocksFirstAndLastMinutesAreTimes() throws {
        #expect(try TimeOfDay(hour: 0, minute: 0).secondsIntoDay == 0)
        #expect(try TimeOfDay(hour: 23, minute: 59).secondsIntoDay == 23 * 3600 + 59 * 60)
    }

    // MARK: Wall-clock times, in the engine's time zone

    @Test func theSameInstantIsQuietOrNotByTheEnginesTimeZone() throws {
        let eveningHour = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 23), on: [.sunday])
        let instant = NewYork.local(2026, 11, 15, 22, 30)
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(engine([eveningHour], timeZone: NewYork.timeZone).isQuiet(at: instant))
        #expect(!engine([eveningHour], timeZone: losAngeles).isQuiet(at: instant))
        #expect(!engine([eveningHour], timeZone: tokyo).isQuiet(at: instant))
    }

    @Test func aWindowEndsAtItsWallClockEndWhenTheClocksGoBack() throws {
        // 2026-11-01: New York goes from 2 AM EDT back to 1 AM EST, so Saturday's night is 9 hours.
        let night = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: [.saturday])
        let engine = engine([night])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 1, 6, 59)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 1, 7, 0)))
    }

    @Test func bothHoursOfARepeatedWallClockHourAreInsideAWindowCoveringIt() throws {
        let earlyMorning = try schedule(from: TimeOfDay(hour: 1), to: TimeOfDay(hour: 2), on: [.sunday])
        let engine = engine([earlyMorning])
        let firstOneThirty = NewYork.local(2026, 11, 1, 1, 30)   // EDT
        let secondOneThirty = firstOneThirty.addingTimeInterval(3600)   // EST, the same wall-clock time
        #expect(engine.isQuiet(at: firstOneThirty))
        #expect(engine.isQuiet(at: secondOneThirty))
        #expect(!engine.isQuiet(at: secondOneThirty.addingTimeInterval(1800)))
    }

    @Test func aWindowEndsAtItsWallClockEndWhenTheClocksGoForward() throws {
        // 2026-03-08: New York goes from 2 AM EST to 3 AM EDT, so Saturday's night is 8 hours.
        let night = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: [.saturday])
        let engine = engine([night])
        #expect(engine.isQuiet(at: NewYork.local(2026, 3, 8, 6, 59)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 3, 8, 7, 0)))
        #expect(engine.isQuiet(at: NewYork.local(2026, 3, 8, 3, 0)))
    }

    @Test func theSundayAfterTheClocksChangeStillBelongsToSaturdaysWindow() throws {
        // The day before is found on the week, so a 23- or 25-hour day can't move a window's day.
        let night = try schedule(from: TimeOfDay(hour: 22), to: TimeOfDay(hour: 7), on: [.saturday])
        let engine = engine([night])
        #expect(engine.isQuiet(at: NewYork.local(2026, 11, 1, 0, 30)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 11, 2, 0, 30)))
    }

    @Test func aWindowStartingInTheSkippedHourIsCoveredFromTheWallClockStart() throws {
        // 2026-03-08: 2 AM EST becomes 3 AM EDT, so 2:00 to 7:00 has no 2 AM, and a window that
        // starts at 2:00 is covered from the 3:00 the wall clock shows next.
        let earlyMorning = try schedule(from: TimeOfDay(hour: 2), to: TimeOfDay(hour: 7), on: [.sunday])
        let engine = engine([earlyMorning])
        #expect(!engine.isQuiet(at: NewYork.local(2026, 3, 8, 1, 59)))
        #expect(engine.isQuiet(at: NewYork.local(2026, 3, 8, 3, 0)))
        #expect(!engine.isQuiet(at: NewYork.local(2026, 3, 8, 7, 0)))
    }
}
