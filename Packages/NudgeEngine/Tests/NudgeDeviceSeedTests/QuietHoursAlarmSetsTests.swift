import Foundation
import NudgeEngine
import Testing
@testable import NudgeDeviceSeed

/// #379's four device checks need real alarms and a quiet window timed from the load. These
/// run each set through the engine at several moments inside the load's minute, so the timing a
/// check promises (which nudge is held, which rings, and when) holds whichever second the load lands on.
@MainActor
struct QuietHoursAlarmSetsTests {
    /// A whole minute, the `m` every time below is counted from.
    nonisolated static let m = Date(timeIntervalSinceReferenceDate: 800_000_040)
    nonisolated static let secondsIntoTheMinute: [TimeInterval] = [0, 1, 30, 59]

    nonisolated static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    final class Clock: EngineClock {
        var now: Date
        init(now: Date) { self.now = now }
    }

    final class Recorder: SchedulerAdapter {
        var last: SchedulePlan?
        func apply(_ plan: SchedulePlan) { last = plan }
    }

    /// The plan's nudges still to fire, as minutes after `m` and how each is delivered.
    struct Pending: Equatable {
        var minutes: Double
        var kind: DeliveryKind
        var nudge: Int
    }

    struct Setup {
        let clock: Clock
        let recorder = Recorder()
        var engine: Engine
        /// What the engine was last given, as the app's model holds it.
        private(set) var quietHours: QuietHours

        init(loadedAt now: Date, quietHours: QuietHours) {
            clock = Clock(now: now)
            self.quietHours = quietHours
            engine = Engine(clock: clock, scheduler: recorder, timeZone: TimeZone(secondsFromGMT: 0)!, quietHours: quietHours)
        }

        mutating func change(_ edit: (inout QuietHours) -> Void) {
            edit(&quietHours)
            engine.update(quietHours: quietHours)
        }

        var pending: [Pending] {
            (recorder.last?.items ?? [])
                .filter { $0.fireTime > clock.now }
                .sorted { $0.fireTime < $1.fireTime }
                .map { Pending(minutes: $0.fireTime.timeIntervalSince(QuietHoursAlarmSetsTests.m) / 60, kind: $0.deliveryKind, nudge: $0.nudgeNumber) }
        }
    }

    func schedules(of set: SeedSet, at now: Date, isOn: Bool = true) throws -> [QuietHoursSchedule] {
        guard let window = set.quietWindow else { return [] }
        let times = window.times(from: now, calendar: Self.calendar)
        return [try QuietHoursSchedule(start: times.start, end: times.end, days: Set(RepeatRule.Weekday.allCases), isOn: isOn)]
    }

    func load(_ set: SeedSet, secondsIn s: TimeInterval, quietHours: QuietHours? = nil) throws -> Setup {
        let now = Self.m + s
        var setup = Setup(loadedAt: now, quietHours: try quietHours ?? QuietHours(schedules: schedules(of: set, at: now)))
        setup.engine.update(reminders: set.reminders.map { $0.reminder(tagIDs: [], now: now) })
        return setup
    }

    // MARK: The sets are ones that ring

    @Test(arguments: QuietHoursAlarmSetsTests.ringingSets)
    func theSetsRemindersBreakThroughFocusOnAFirmLadder(set: SeedSet) {
        #expect(!set.reminders.isEmpty)
        #expect(set.reminders.allSatisfy { $0.breakThroughFocus && $0.strength == .firm })
    }

    nonisolated static let ringingSets: [SeedSet] = [.quietHoursWindow, .quietHoursRinging, .quietHoursEdit, .quietHoursQuietNow]

    // MARK: A window holds an alarm and a notification

    @Test(arguments: QuietHoursAlarmSetsTests.secondsIntoTheMinute)
    func withoutAWindowTheNotificationAndTheAlarmWouldComeAtTwoAndFourMinutes(s: TimeInterval) throws {
        let setup = try load(.quietHoursWindow, secondsIn: s, quietHours: QuietHours())

        #expect(Array(setup.pending.prefix(3)) == [
            Pending(minutes: 2, kind: .timeSensitiveNotification, nudge: 3),
            Pending(minutes: 4, kind: .alarm, nudge: 4),
            Pending(minutes: 6, kind: .alarm, nudge: 5),
        ])
    }

    @Test(arguments: QuietHoursAlarmSetsTests.secondsIntoTheMinute)
    func theWindowHoldsTheNotificationAndTheAlarmAndTheNextNudgeComesAtSixMinutes(s: TimeInterval) throws {
        let setup = try load(.quietHoursWindow, secondsIn: s)

        #expect(Array(setup.pending.prefix(2)) == [
            Pending(minutes: 6, kind: .alarm, nudge: 5),
            Pending(minutes: 8, kind: .alarm, nudge: 6),
        ])
    }

    // MARK: An alarm already ringing

    @Test(arguments: QuietHoursAlarmSetsTests.secondsIntoTheMinute)
    func theAlarmRingsAtTwoMinutesAndTheWindowThatStartsAtThreeHoldsTheNextThree(s: TimeInterval) throws {
        let setup = try load(.quietHoursRinging, secondsIn: s)

        #expect(Array(setup.pending.prefix(2)) == [
            Pending(minutes: 2, kind: .alarm, nudge: 4),
            Pending(minutes: 10, kind: .alarm, nudge: 8),
        ])
    }

    // MARK: Editing a schedule while a reminder is Nudging

    @Test(arguments: QuietHoursAlarmSetsTests.secondsIntoTheMinute)
    func theScheduleAsSeededHoldsNothingStillToFire(s: TimeInterval) throws {
        let setup = try load(.quietHoursEdit, secondsIn: s)

        #expect(Array(setup.pending.prefix(3)) == [
            Pending(minutes: 5, kind: .timeSensitiveNotification, nudge: 3),
            Pending(minutes: 10, kind: .alarm, nudge: 4),
            Pending(minutes: 15, kind: .alarm, nudge: 5),
        ])
    }

    /// The check's edit: the same schedule with its end moved to 13 minutes after `m`.
    @Test(arguments: QuietHoursAlarmSetsTests.secondsIntoTheMinute)
    func movingTheEndCancelsTheNotificationAndTheAlarmAndSchedulesTheRest(s: TimeInterval) throws {
        var setup = try load(.quietHoursEdit, secondsIn: s)
        setup.clock.now = Self.m + 60
        let seeded = try #require(setup.quietHours.schedules.first)
        let endTime = Self.m + 13 * 60
        let end = Self.calendar.dateComponents([.hour, .minute], from: endTime)
        let edited = try QuietHoursSchedule(id: seeded.id, start: seeded.start, end: TimeOfDay(hour: end.hour!, minute: end.minute!), days: seeded.days)

        setup.change { $0.saveSchedule(edited) }

        #expect(Array(setup.pending.prefix(2)) == [
            Pending(minutes: 15, kind: .alarm, nudge: 5),
            Pending(minutes: 20, kind: .alarm, nudge: 6),
        ])
    }

    // MARK: Quiet Now

    @Test(arguments: QuietHoursAlarmSetsTests.secondsIntoTheMinute)
    func quietNowHoldsEveryNudgeAndTurningItOffLeavesNoCatchUp(s: TimeInterval) throws {
        var setup = try load(.quietHoursQuietNow, secondsIn: s)
        #expect(Array(setup.pending.prefix(3)).map(\.minutes) == [5, 10, 15])

        setup.clock.now = Self.m + 60
        let turnedOn = setup.clock.now
        setup.change { $0.turnOnQuietNow(at: turnedOn) }
        #expect(setup.pending.isEmpty)

        setup.clock.now = Self.m + 12 * 60
        setup.change { $0.turnOffQuietNow() }

        // Nudges 3 and 4 (5 and 10 minutes) were held and are not made up; nudge 5 is the next.
        #expect(Array(setup.pending.prefix(2)) == [
            Pending(minutes: 15, kind: .alarm, nudge: 5),
            Pending(minutes: 20, kind: .alarm, nudge: 6),
        ])
    }

    @Test func theQuietNowSetLeavesNoScheduleToHoldAnything() {
        #expect(SeedSet.quietHoursQuietNow.quietWindow == nil)
        #expect(SeedSet.quietHoursQuietNow.settings[.quietHours] == "")
    }
}
