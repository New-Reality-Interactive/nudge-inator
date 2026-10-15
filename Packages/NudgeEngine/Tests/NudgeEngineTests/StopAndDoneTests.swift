import Foundation
import Testing
@testable import NudgeEngine

/// Stop silences one ring and moves the ladder along; Done is the only act that closes an
/// occurrence as Done (ADR 0001). Stop never reaches the engine: the system handles it and the
/// pre-scheduled chain carries on, so it is tested as nudges firing with no Done.
struct StopAndDoneTests {
    let dueTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let clock: FakeClock
    let scheduler = FakeScheduler()

    init() {
        clock = FakeClock(now: dueTime)
    }

    /// Nudge 4 fires at +2 h 18 min 45 s (Gentle), +56 min 15 s (Firm), +18 min 45 s (Relentless).
    @Test(arguments: [
        (Strength.gentle, 8325),
        (.firm, 3375),
        (.relentless, 1125),
    ])
    func doneAtNudgeFourClosesTheOccurrenceAndEmptiesItsPlan(strength: Strength, nudgeFourSecond: Int) throws {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: strength)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])

        clock.now = dueTime + TimeInterval(nudgeFourSecond)
        engine.markDone(reminder.id)

        #expect(engine.latestOccurrence(for: reminder.id)?.state == .done)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    /// Done can race the give-up limit (a Done from a notification just after Relentless gives up
    /// at +51 min 30 s). As in the mockup's `ack`, it is ignored: the close reason stays Missed.
    @Test func doneAfterTheOccurrenceIsMissedIsIgnored() {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: .relentless)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])

        clock.now = dueTime + 3090
        engine.markDone(reminder.id)

        #expect(engine.latestOccurrence(for: reminder.id)?.state == .missed(reason: .giveUpLimit))
    }

    /// The app hands the engine its reminders again on launch and foreground. A Done occurrence
    /// stays Done, and stays out of the plan, even past the time it would have given up.
    @Test func doneSurvivesAFreshUpdatePastTheGiveUpTime() throws {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: .relentless)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])
        engine.markDone(reminder.id)

        clock.now = dueTime + 3090
        engine.update(reminders: [reminder])

        #expect(engine.latestOccurrence(for: reminder.id)?.state == .done)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    /// Done closes one occurrence, not the reminder. Once it is closed the due time is no longer
    /// locked (ADR 0002), and a reminder moved to a later due time has a new occurrence that nudges.
    @Test func doneClosesTheOccurrenceNotTheReminder() throws {
        var reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: .relentless)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])
        engine.markDone(reminder.id)

        reminder.dueTime = dueTime + 24 * 60 * 60
        engine.update(reminders: [reminder])
        clock.now = reminder.dueTime

        #expect(engine.latestOccurrence(for: reminder.id)?.state == .nudging(nudgeNumber: 1))
        #expect(try #require(scheduler.lastPlan).items.map(\.nudgeNumber) == Array(1...20))
    }

    @Test func doneClosesOnlyItsOwnOccurrence() throws {
        let train = Reminder(title: "Leave for the train", dueTime: dueTime, strength: .relentless)
        let plants = Reminder(title: "Water the plants", dueTime: dueTime, strength: .gentle)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [train, plants])

        engine.markDone(train.id)

        #expect(engine.latestOccurrence(for: plants.id)?.state == .nudging(nudgeNumber: 1))
        let items = try #require(scheduler.lastPlan).items
        #expect(items.allSatisfy { $0.reminderID == plants.id })
        #expect(items.map(\.nudgeNumber) == Array(1...20))
    }

    /// The spec offers Done only on a nudging occurrence. Before the due time there is none, so
    /// Done is ignored and the occurrence still nudges when it comes due.
    @Test func doneBeforeTheDueTimeIsIgnored() throws {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: .relentless)
        clock.now = dueTime - 60
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])

        engine.markDone(reminder.id)
        #expect(try #require(scheduler.lastPlan).items.map(\.nudgeNumber) == Array(1...20))

        clock.now = dueTime
        #expect(engine.latestOccurrence(for: reminder.id)?.state == .nudging(nudgeNumber: 1))
    }

    /// Stop at nudge 4 is the ring silenced and nothing else: the app may come to the foreground
    /// and re-plan, and the occurrence is still Nudging with nudges 5–20 where they were.
    @Test(arguments: [
        (Strength.gentle, 8325),
        (.firm, 3375),
        (.relentless, 1125),
    ])
    func afterStopAtNudgeFourTheLaterNudgesStayAtTheirOriginalTimes(strength: Strength, nudgeFourSecond: Int) throws {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: strength)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])
        let laterNudges = try #require(scheduler.lastPlan).items.filter { $0.nudgeNumber >= 5 }

        clock.now = dueTime + TimeInterval(nudgeFourSecond)
        engine.update(reminders: [reminder])

        #expect(engine.latestOccurrence(for: reminder.id)?.state == .nudging(nudgeNumber: 4))
        let items = try #require(scheduler.lastPlan).items
        #expect(items.filter { $0.nudgeNumber >= 5 } == laterNudges)
        #expect(laterNudges.map(\.nudgeNumber) == Array(5...20))
    }

    /// Stopping every ring, the last one included, with the app re-planning after each, never
    /// closes the occurrence as Done. It nudges through nudge 20 and closes as Missed at the
    /// give-up limit (+51 min 30 s for Relentless).
    @Test func stoppingEveryRingIncludingTheLastNeverClosesAsDone() throws {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: .relentless)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])
        let fireTimes = try #require(scheduler.lastPlan).items.map(\.fireTime)

        for (index, fireTime) in fireTimes.enumerated() {
            clock.now = fireTime
            engine.update(reminders: [reminder])
            #expect(engine.latestOccurrence(for: reminder.id)?.state == .nudging(nudgeNumber: index + 1))
        }

        clock.now = dueTime + 3090
        engine.update(reminders: [reminder])
        #expect(engine.latestOccurrence(for: reminder.id)?.state == .missed(reason: .giveUpLimit))
    }

    /// Opening the app is `update(reminders:)`: the engine reads the clock, counts every nudge
    /// whose time has passed as sent, and applies the give-up limit. Three hours after both fall
    /// due, Firm gave up at +2 h 17 min 30 s, and Gentle's nudge 5 fired at +2 h 44 min 4 s.
    @Test func appOpenedAfterALongGapClosesOverLimitAsMissedAndKeepsWithinLimitNudging() throws {
        let firm = Reminder(title: "Leave for the train", dueTime: dueTime, strength: .firm)
        let gentle = Reminder(title: "Water the plants", dueTime: dueTime, strength: .gentle)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [firm, gentle])

        clock.now = dueTime + 3 * 60 * 60
        engine.update(reminders: [firm, gentle])

        #expect(engine.latestOccurrence(for: firm.id)?.state == .missed(reason: .giveUpLimit))
        #expect(engine.latestOccurrence(for: gentle.id)?.state == .nudging(nudgeNumber: 5))
        let items = try #require(scheduler.lastPlan).items
        #expect(items.allSatisfy { $0.reminderID == gentle.id })
    }
}
