import Foundation
import Testing
@testable import NudgeEngine

/// The spec's Quiet hours rule for the plan: a nudge whose time is quiet is held, left out of the
/// plan, and counts as dismissed, so the ladder moves on without it (ADR 0007). Monday 2026-11-16
/// in New York. Relentless nudges a 9:00 occurrence at 9:00, 9:10, 9:15 and 9:17:30, then every 2
/// minutes from nudge 5 at 9:19:30 to nudge 20 at 9:49:30, and gives up at 9:51:30.
struct HeldNudgeTests {
    let dueTime = NewYork.local(2026, 11, 16)
    let clock = FakeClock(now: NewYork.local(2026, 11, 16, 8, 0))
    let scheduler = FakeScheduler()

    static func monday(from start: TimeOfDay, to end: TimeOfDay) throws -> QuietHours {
        QuietHours(schedules: [try QuietHoursSchedule(start: start, end: end, days: [.monday])])
    }

    func engine(_ quietHours: QuietHours, with reminders: [Reminder]) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, quietHours: quietHours)
        engine.update(reminders: reminders)
        return engine
    }

    func reminder(_ strength: Strength = .relentless, dueAt dueTime: Date? = nil, breakThroughFocus: Bool = true) -> Reminder {
        Reminder(title: "Leave for the train", dueTime: dueTime ?? self.dueTime, strength: strength, breakThroughFocus: breakThroughFocus)
    }

    func planItems() throws -> [SchedulePlan.Item] {
        try #require(scheduler.lastPlan).items
    }

    /// 9:12 to 9:18 holds nudges 3 (9:15) and 4 (9:17:30). Nudge 5 is still nudge 5 of 20.
    @Test func aNudgeAtAQuietTimeIsLeftOutAndTheRestKeepTheirNumbers() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18))
        _ = engine(quiet, with: [reminder()])

        let items = try planItems()
        #expect(items.map(\.nudgeNumber) == [1, 2] + Array(5...20))
        #expect(items.allSatisfy { $0.nudgesInAll == 20 })
    }

    /// "Quiet hours held 2 of its 20 nudges": the count and the total the Missed note reads.
    @Test func aMissedOccurrenceSaysHowManyOfItsNudgesWereHeld() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18))
        let train = reminder()
        let engine = engine(quiet, with: [train])

        clock.now = NewYork.local(2026, 11, 16, 10, 0)
        let closed = try #require(engine.closedOccurrence(of: train.id, dueAt: dueTime))
        #expect(closed.occurrence.state == .missed(reason: .giveUpLimit))
        #expect(closed.nudgesHeld == 2)
        #expect(closed.nudgesSent == 20)
        #expect(closed.missedNudgesHeld == 2)
    }

    /// The Missed note's rule (#369): only an occurrence that closed as Missed with a nudge held
    /// has a count to show. Done, Skipped, and Missed with none held have none.
    @Test(arguments: [
        (OccurrenceState.missed(reason: .giveUpLimit), 3, 3 as Int?),
        (.missed(reason: .nextTookOver), 1, 1),
        (.missed(reason: .giveUpLimit), 0, nil),
        (.done, 2, nil),
        (.skipped(reason: .paused), 1, nil),
    ])
    func onlyAMissedOccurrenceWithAHeldNudgeHasAMissedHeldCount(state: OccurrenceState, held: Int, count: Int?) {
        let closed = ClosedOccurrence(
            reminderID: UUID(), occurrence: Occurrence(dueTime: dueTime, state: state), closedAt: dueTime, nudgesSent: 20, nudgesHeld: held
        )

        #expect(closed.missedNudgesHeld == count)
    }

    /// A 9:00 to 9:40 schedule added at 9:20 holds only what is due after it: nudges 6 (9:21:30)
    /// to 15 (9:39:30). Nudges 1 to 5 had already been sent and stay sent.
    @Test func addingAScheduleHoldsOnlyNudgesDueAfterTheEdit() throws {
        let train = reminder()
        var engine = engine(QuietHours(), with: [train])

        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        engine.update(quietHours: try Self.monday(from: TimeOfDay(hour: 9), to: TimeOfDay(hour: 9, minute: 40)))

        #expect(try planItems().map(\.nudgeNumber) == Array(1...5) + Array(16...20))
        clock.now = NewYork.local(2026, 11, 16, 10, 0)
        #expect(engine.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 10)
    }

    /// Deleting the 9:12 to 9:18 schedule at 9:20 brings back none of nudges 3 and 4, and the
    /// Missed occurrence still says quiet hours held 2.
    @Test func removingAScheduleLeavesWhatItHeldHeld() throws {
        let train = reminder()
        var engine = engine(try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18)), with: [train])

        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        engine.update(quietHours: QuietHours())

        #expect(try planItems().map(\.nudgeNumber) == [1, 2] + Array(5...20))
        clock.now = NewYork.local(2026, 11, 16, 10, 0)
        #expect(engine.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 2)
    }

    /// After a relaunch the engine starts with the quiet hours as they are now; handed back the
    /// ones they replaced, it reads the Missed occurrence's count as it was.
    @Test func theReplacedQuietHoursHandedBackAtLaunchKeepAPastCountTrue() throws {
        let train = reminder()
        var before = engine(try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18)), with: [train])
        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        before.update(quietHours: QuietHours())

        clock.now = NewYork.local(2026, 11, 16, 10, 0)
        var relaunched = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, quietHours: QuietHours())
        relaunched.update(replacedQuietHours: before.replacedQuietHours)
        relaunched.update(reminders: [train])

        #expect(relaunched.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 2)
    }

    /// Relentless to Gentle after the Missed occurrence closed: Gentle's ladder (9:00, 10:00, …)
    /// has no nudge in 9:12 to 9:18, but the occurrence was nudged by Relentless's, so it still
    /// says 2. The count is fixed with the closing, in the history the store saves.
    @Test func anEditThatMovesTheNudgeTimesKeepsAPastCount() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18))
        let train = reminder()
        var engine = engine(quiet, with: [train])

        clock.now = NewYork.local(2026, 11, 16, 10, 0)
        var gentle = train
        gentle.strength = .gentle
        try engine.edit(gentle)

        #expect(engine.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 2)
        #expect(engine.histories[train.id]?.closedOccurrences[dueTime]?.nudgesHeld == 2)
    }

    /// At 9:11, with 9:12 to 9:18 holding nudges 3 and 4, the nudge card's next nudge is the next
    /// that will arrive: nudge 5 at 9:19:30. Its count is still nudge 2 of 20.
    @Test func theNudgeCardsNextNudgeIsTheNextThatWillArrive() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18))
        let train = reminder()
        let engine = engine(quiet, with: [train])

        clock.now = NewYork.local(2026, 11, 16, 9, 11)
        let status = try #require(engine.nudgingStatus(of: train.id))
        #expect(status.nudgesSent == 2)
        #expect(status.nudgesInAll == 20)
        #expect(status.nextNudge?.nudgeNumber == 5)
        #expect(status.nextNudge?.fireTime == NewYork.local(2026, 11, 16, 9, 19) + 30)
    }

    /// With every nudge left held by 9:00 to 10:00, the card has no next nudge to name.
    @Test func theNudgeCardNamesNoNextNudgeWhenEveryOneLeftIsHeld() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9), to: TimeOfDay(hour: 10))
        let train = reminder()
        let engine = engine(quiet, with: [train])

        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        let status = try #require(engine.nudgingStatus(of: train.id))
        #expect(status.nudgesSent == 5)
        #expect(status.nextNudge == nil)
    }

    /// A count the store hands back stands, whatever the schedules say now.
    @Test func aSavedCountIsReadAsSaved() throws {
        let train = reminder()
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        clock.now = NewYork.local(2026, 11, 16, 10, 0)
        let closing = Closing(state: .missed(reason: .giveUpLimit), closedAt: NewYork.local(2026, 11, 16, 9, 51) + 30, nudgesSent: 20, nudgesHeld: 3)
        engine.update(histories: [train.id: ReminderHistory(closedOccurrences: [dueTime: closing])])
        engine.update(reminders: [train])

        #expect(engine.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 3)

        var gentle = train
        gentle.strength = .gentle
        try engine.edit(gentle)
        #expect(engine.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 3)
    }

    /// A closing saved with no count was saved before quiet hours, when nothing could be held. A
    /// 1.5.0 Edit may have moved its reminder's ladder since (Relentless to Gentle here, whose
    /// nudge 2 is at 10:00), so the ladder isn't read: 10:00 is quiet now, but the count is 0, and an
    /// Edit fixes 0.
    @Test func aClosingSavedBeforeQuietHoursHeldNothing() throws {
        var train = reminder()
        train.strength = .gentle
        var engine = Engine(
            clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone,
            quietHours: try Self.monday(from: TimeOfDay(hour: 9, minute: 30), to: TimeOfDay(hour: 10, minute: 30))
        )
        clock.now = NewYork.local(2026, 11, 16, 11, 0)
        let closing = Closing(state: .missed(reason: .giveUpLimit), closedAt: NewYork.local(2026, 11, 16, 9, 51) + 30, nudgesSent: 20)
        engine.update(histories: [train.id: ReminderHistory(closedOccurrences: [dueTime: closing])])
        engine.update(reminders: [train])

        #expect(engine.closedOccurrence(of: train.id, dueAt: dueTime)?.nudgesHeld == 0)
        var firm = train
        firm.strength = .firm
        try engine.edit(firm)
        #expect(engine.histories[train.id]?.closedOccurrences[dueTime]?.nudgesHeld == 0)
    }

    /// A Done chosen at 9:20 and queued until the store could be read keeps the count of the nudges
    /// 9:12 to 9:18 held before it: nudges 3 and 4.
    @Test func aQueuedDoneKeepsTheCountOfTheNudgesHeldBeforeIt() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18))
        let train = reminder()
        var engine = engine(quiet, with: [train])

        clock.now = NewYork.local(2026, 11, 16, 9, 30)
        engine.markDone(train.id, occurrenceDueAt: dueTime, doneAt: NewYork.local(2026, 11, 16, 9, 20))

        let closed = try #require(engine.closedOccurrence(of: train.id, dueAt: dueTime))
        #expect(closed.occurrence.state == .done)
        #expect(closed.nudgesSent == 5)
        #expect(closed.nudgesHeld == 2)
    }

    /// 8:30 to 6 PM covers every ladder (Gentle, the slowest, gives up at 5:04:04 PM), so all 20
    /// nudges planned without it are held, Relentless included.
    @Test(arguments: [Strength.gentle, .firm, .relentless], [true, false])
    func aWindowHoldsEveryStrength(strength: Strength, breakThroughFocus: Bool) throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 8, minute: 30), to: TimeOfDay(hour: 18))
        let train = reminder(strength, breakThroughFocus: breakThroughFocus)
        _ = engine(QuietHours(), with: [train])
        #expect(try planItems().count == 20)

        _ = engine(quiet, with: [train])
        #expect(try planItems().isEmpty)
    }

    /// Firm breaking through Focus plans notifications, Time Sensitive ones and alarms; the
    /// window holds every one of them.
    @Test func aWindowHoldsEveryDeliveryKind() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 8, minute: 30), to: TimeOfDay(hour: 18))
        let train = reminder(.firm)
        _ = engine(QuietHours(), with: [train])
        #expect(try Set(planItems().map(\.deliveryKind)) == [.notification, .timeSensitiveNotification, .alarm])

        _ = engine(quiet, with: [train])
        #expect(try planItems().isEmpty)
    }

    /// Due at 9:00 inside 8:55 to 9:05: nothing sounds at the due time, and nudge 2 (9:10) is the
    /// first to arrive.
    @Test func aReminderDueInsideAWindowHasItsFirstNudgeHeld() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 8, minute: 55), to: TimeOfDay(hour: 9, minute: 5))
        _ = engine(quiet, with: [reminder()])

        let first = try #require(planItems().first)
        #expect(first.nudgeNumber == 2)
        #expect(first.fireTime == NewYork.local(2026, 11, 16, 9, 10))
    }

    /// The first nudge after 9:12 to 9:18 is nudge 5 at its own time, 9:19:30: no held nudge is
    /// sent at 9:18, late, and nothing else fires between.
    @Test func theFirstNudgeAfterAWindowComesAtItsOwnTimeWithNoBurst() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18))
        _ = engine(quiet, with: [reminder()])

        let afterNudge2 = try planItems().filter { $0.fireTime > NewYork.local(2026, 11, 16, 9, 10) }
        #expect(afterNudge2.first?.nudgeNumber == 5)
        #expect(afterNudge2.first?.fireTime == NewYork.local(2026, 11, 16, 9, 19) + 30)
        #expect(afterNudge2.dropFirst().first?.fireTime == NewYork.local(2026, 11, 16, 9, 21) + 30)
    }

    /// 9:00 to 10:00 holds all 20 nudges. The occurrence reads Nudging until it gives up at
    /// 9:51:30, then Missed, with all 20 held, though nothing ever sounded.
    @Test func anOccurrenceThatGivesUpInsideAWindowClosesAsMissed() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9), to: TimeOfDay(hour: 10))
        let train = reminder()
        let engine = engine(quiet, with: [train])

        clock.now = NewYork.local(2026, 11, 16, 9, 51)
        #expect(engine.latestOccurrence(for: train.id)?.state == .nudging(nudgeNumber: 20))

        clock.now = NewYork.local(2026, 11, 16, 9, 51) + 30
        let closed = try #require(engine.closedOccurrence(of: train.id, dueAt: dueTime))
        #expect(closed.occurrence.state == .missed(reason: .giveUpLimit))
        #expect(closed.nudgesHeld == 20)
        #expect(closed.nudgesSent == 20)
    }

    /// Inside 9:00 to 10:00 at 9:20, the occurrence reads Nudging at nudge 5, Done closes it as
    /// Done and Pause closes it as Skipped, as they do outside a window.
    @Test func doneAndPauseInsideAWindowCloseAsTheyAlwaysDo() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9), to: TimeOfDay(hour: 10))
        let done = reminder()
        let paused = reminder()
        var engine = engine(quiet, with: [done, paused])

        clock.now = NewYork.local(2026, 11, 16, 9, 20)
        #expect(engine.latestOccurrence(for: done.id)?.state == .nudging(nudgeNumber: 5))
        engine.markDone(done.id)
        engine.pause(paused.id)

        #expect(engine.latestOccurrence(for: done.id)?.state == .done)
        #expect(engine.latestOccurrence(for: paused.id)?.state == .skipped(reason: .paused))
        #expect(engine.closedOccurrence(of: done.id, dueAt: dueTime)?.nudgesHeld == 5)
        #expect(engine.histories[done.id]?.closedOccurrences[dueTime]?.nudgesHeld == 5)
    }

    /// With room for 3 alarms, held alarms take none of it: 9:00 to 9:16 holds nudges 1 to 3, so
    /// nudges 4 to 6 ring and 7 on fall back.
    @Test func heldAlarmsTakeNoPartInTheAlarmLimit() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9), to: TimeOfDay(hour: 9, minute: 16))
        var engine = Engine(
            clock: clock, scheduler: scheduler, giveUpLimit: .shipped, alarmLimit: AlarmLimit(pendingAlarms: 3),
            timeZone: NewYork.timeZone, quietHours: quiet
        )
        engine.update(reminders: [reminder()])

        let items = try planItems()
        #expect(items.map(\.nudgeNumber) == Array(4...20))
        #expect(items.filter { !$0.isPastAlarmLimit }.map(\.nudgeNumber) == [4, 5, 6])
    }

    /// Two Relentless reminders due 9:00 and 9:30, with 9:25 to 9:35 holding nudges 8 to 12 of the
    /// first and nudge 1 of the second. A held nudge counts as dismissed, so the second is Nudging
    /// from 9:30 and the first's nudges after the window stamp 2; the second's stamp 1 once the
    /// first gives up at 9:51:30.
    @Test func thePredictedBadgeCountFollowsThePlan() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9, minute: 25), to: TimeOfDay(hour: 9, minute: 35))
        let first = reminder()
        let second = reminder(dueAt: NewYork.local(2026, 11, 16, 9, 30))
        _ = engine(quiet, with: [first, second])

        let items = try planItems()
        #expect(items.filter { $0.reminderID == first.id }.map(\.predictedBadgeCount) == [Int](repeating: 1, count: 7) + [Int](repeating: 2, count: 8))
        #expect(items.filter { $0.reminderID == second.id }.map(\.predictedBadgeCount) == [Int](repeating: 2, count: 4) + [Int](repeating: 1, count: 15))
    }

    /// A reminder received from someone else is held by the same rule as one's own.
    @Test func aReceivedReminderIsHeldByTheSameRule() throws {
        let quiet = try Self.monday(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18))
        var received = reminder()
        received.origin = .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 1, state: .accepted)
        _ = engine(quiet, with: [received])

        #expect(try planItems().map(\.nudgeNumber) == [1, 2] + Array(5...20))
    }

    /// With no schedule, or one that is off, every strength plans all 20 nudges, as before quiet
    /// hours, and the two plans are the same.
    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func withNoScheduleOnThePlanIsTheSameAsBefore(strength: Strength) throws {
        let off = try QuietHoursSchedule(
            start: TimeOfDay(hour: 0), end: TimeOfDay(hour: 23, minute: 59), days: Set(RepeatRule.Weekday.allCases), isOn: false
        )
        let train = reminder(strength)
        _ = engine(QuietHours(), with: [train])
        let none = try #require(scheduler.lastPlan)
        _ = engine(QuietHours(schedules: [off]), with: [train])

        #expect(none.items.map(\.nudgeNumber) == Array(1...20))
        #expect(try #require(scheduler.lastPlan) == none)
    }
}
