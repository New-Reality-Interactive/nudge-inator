import Foundation
import Testing
@testable import NudgeEngine

/// Pause stops a reminder nudging without losing it: a Nudging occurrence closes as Skipped, not
/// Missed, and anything due while it's paused is skipped. Resume brings it back at its next future
/// due time, or is rejected when it has none (a Never whose due time has passed).
struct PauseAndResumeTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    /// Every day at 9:00 from Thursday 15 October 2026.
    let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)

    func engine(for reminder: Reminder) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder])
        return engine
    }

    @Test func pausingANudgingReminderClosesItsOccurrenceAsSkippedAndEmptiesThePlan() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)

        engine.pause(pills.id)

        let occurrence = try #require(engine.latestOccurrence(for: pills.id))
        #expect(occurrence == Occurrence(dueTime: NewYork.local(2026, 10, 15), state: .skipped(reason: .paused)))
        #expect(engine.openOccurrence(for: pills.id) == nil)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    /// Two days later, the app opened: the due times that passed while paused nudged no one. Each
    /// reads back as Skipped (the mockup's "Anything due while it's paused is skipped, not
    /// missed"), and the plan stays empty.
    @Test func whilePausedTimePassingOpensNoOccurrenceAndPlansNothing() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: pills)
        engine.pause(pills.id)

        clock.now = NewYork.local(2026, 10, 17, 9, 30)
        engine.update(reminders: [pills])

        #expect(engine.openOccurrence(for: pills.id) == nil)
        let states = [15, 16, 17].map { engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, $0))?.state }
        #expect(states == Array(repeating: .skipped(reason: .paused), count: 3))
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    /// Resumed at 9:30 on the 17th: that morning's 9:00 fell due while paused, so it stays Skipped
    /// and nothing is open. The plan starts with nudge 1 at 9:00 on the 18th.
    @Test func resumingARepeatSchedulesItsNextFutureOccurrenceNotAPastOne() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: pills)
        engine.pause(pills.id)

        clock.now = NewYork.local(2026, 10, 17, 9, 30)
        try engine.resume(pills.id)

        #expect(!engine.isPaused(pills.id))
        #expect(engine.openOccurrence(for: pills.id) == nil)
        #expect(engine.latestOccurrence(for: pills.id)?.state == .skipped(reason: .paused))
        let plan = try #require(scheduler.lastPlan)
        let first = try #require(plan.items.min { $0.fireTime < $1.fireTime })
        #expect(first.fireTime == NewYork.local(2026, 10, 18))
        #expect(first.nudgeNumber == 1)
    }

    /// Pause, edit, Resume (ADR 0002): a Never reminder paused while Nudging can't resume at its
    /// passed due time. Resume is rejected and it stays paused, and the screen sends the person to
    /// the edit form. With the due time moved to tomorrow, Resume succeeds.
    @Test func resumingANeverReminderPastItsDueTimeNeedsANewDueTime() throws {
        var call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        clock.now = NewYork.local(2026, 10, 15, 9, 20)
        var engine = engine(for: call)
        engine.pause(call.id)

        #expect(throws: ResumeError.needsNewDueTime) { try engine.resume(call.id) }
        #expect(engine.isPaused(call.id))
        #expect(try #require(scheduler.lastPlan).items.isEmpty)

        call.dueTime = NewYork.local(2026, 10, 16)
        engine.update(reminders: [call])
        try engine.resume(call.id)

        #expect(!engine.isPaused(call.id))
        let plan = try #require(scheduler.lastPlan)
        #expect(plan.items.first { $0.nudgeNumber == 1 }?.fireTime == NewYork.local(2026, 10, 16))
    }

    /// A paused reminder isn't locked, so its due time can move earlier than the Pause: 9:00 to
    /// 8:00, for a Never reminder and for a repeat. The occurrence that edit lands on fell due
    /// before the Pause, but it would still have been open when Pause came, so it is Skipped too,
    /// and a Done can't close it.
    @Test(arguments: [nil, RepeatRule.everyDay])
    func anEditToAnEarlierDueTimeWhilePausedOpensNoOccurrence(repeatRule: RepeatRule?) throws {
        var call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15), repeatRule: repeatRule, strength: .firm)
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: call)
        engine.pause(call.id)

        clock.now = NewYork.local(2026, 10, 15, 9, 45)
        call.dueTime = NewYork.local(2026, 10, 15, 8)
        engine.update(reminders: [call])
        engine.markDone(call.id)

        #expect(engine.openOccurrence(for: call.id) == nil)
        #expect(engine.latestOccurrence(for: call.id)?.state == .skipped(reason: .paused))
    }

    /// Pause, edit to 8:00, Resume: the 8:00 that already passed stays Skipped, even after Firm's
    /// give-up time would have come, and the plan starts at 8:00 the next day.
    @Test func afterAnEditToAnEarlierDueTimeResumeStartsAtTheNextFutureDueTime() throws {
        var pills = pills
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        engine.pause(pills.id)
        clock.now = NewYork.local(2026, 10, 15, 9, 45)
        pills.dueTime = NewYork.local(2026, 10, 15, 8)
        engine.update(reminders: [pills])

        try engine.resume(pills.id)

        let plan = try #require(scheduler.lastPlan)
        #expect(plan.items.min { $0.fireTime < $1.fireTime }?.fireTime == NewYork.local(2026, 10, 16, 8))
        clock.now = NewYork.local(2026, 10, 15, 20)
        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15, 8))?.state == .skipped(reason: .paused))
    }

    /// Resumed at the very instant a due time comes: "next future" means after now, so that one
    /// counts as due while paused and stays Skipped, and the plan starts at the next day's.
    @Test func resumingExactlyAtADueTimeSkipsItAndStartsAtTheNext() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: pills)
        engine.pause(pills.id)

        clock.now = NewYork.local(2026, 10, 16)
        try engine.resume(pills.id)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .skipped(reason: .paused))
        let plan = try #require(scheduler.lastPlan)
        #expect(plan.items.min { $0.fireTime < $1.fireTime }?.fireTime == NewYork.local(2026, 10, 17))
    }

    /// An occurrence that closed before the Pause keeps how it closed: Firm gives up at
    /// +2 h 17 min 30 s, so the 15th is Missed by noon, and pausing then doesn't make it Skipped.
    @Test func anOccurrenceMissedBeforeThePauseStaysMissed() {
        clock.now = NewYork.local(2026, 10, 15, 12)
        var engine = engine(for: pills)

        engine.pause(pills.id)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .missed(reason: .giveUpLimit))
    }

    /// The same for take-over. With ticket 10's widened limit (10,000 nudges or 72 hours) the 15th
    /// is still within its limit on the 16th, but the 16th took it over at 9:00, so a Pause at
    /// 10:00 leaves it Missed and skips only the 16th.
    @Test func anOccurrenceTakenOverBeforeThePauseStaysMissed() {
        clock.now = NewYork.local(2026, 10, 16, 10)
        var engine = Engine(clock: clock, scheduler: scheduler, giveUpLimit: GiveUpLimit(nudgeCount: 10_000, span: 72 * 60 * 60), timeZone: NewYork.timeZone)
        engine.update(reminders: [pills])

        engine.pause(pills.id)

        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .missed(reason: .nextTookOver))
        #expect(engine.latestOccurrence(for: pills.id)?.state == .skipped(reason: .paused))
    }

    /// Pause can come twice (from two screens, or a double tap). The second is ignored, so one
    /// Resume brings the reminder back.
    @Test func pausingTwiceNeedsOnlyOneResume() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: pills)
        engine.pause(pills.id)
        clock.now = NewYork.local(2026, 10, 15, 8, 30)
        engine.pause(pills.id)

        clock.now = NewYork.local(2026, 10, 16, 8)
        try engine.resume(pills.id)
        clock.now = NewYork.local(2026, 10, 16, 9)
        engine.update(reminders: [pills])

        #expect(!engine.isPaused(pills.id))
        #expect(engine.openOccurrence(for: pills.id) == Occurrence(dueTime: NewYork.local(2026, 10, 16), state: .nudging(nudgeNumber: 1)))
    }

    /// With nothing open, Pause closes nothing: a Never reminder not yet due has no occurrence.
    /// Resumed before its due time, it nudges when that comes.
    @Test func pausingBeforeTheDueTimeOnlyFlipsPausedState() throws {
        let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 16), strength: .firm)
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        var engine = engine(for: call)

        engine.pause(call.id)

        #expect(engine.isPaused(call.id))
        #expect(engine.latestOccurrence(for: call.id) == nil)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)

        try engine.resume(call.id)
        clock.now = NewYork.local(2026, 10, 16)
        engine.update(reminders: [call])
        #expect(engine.openOccurrence(for: call.id) == Occurrence(dueTime: NewYork.local(2026, 10, 16), state: .nudging(nudgeNumber: 1)))
    }

    /// With today's occurrence already Done, Pause closes nothing and Done stays Done. Resumed,
    /// the repeat nudges again the next day.
    @Test func pausingAfterDoneKeepsTheOccurrenceDone() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        var engine = engine(for: pills)
        engine.markDone(pills.id)

        engine.pause(pills.id)

        #expect(engine.isPaused(pills.id))
        #expect(engine.latestOccurrence(for: pills.id)?.state == .done)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)

        try engine.resume(pills.id)
        clock.now = NewYork.local(2026, 10, 16)
        engine.update(reminders: [pills])
        #expect(engine.openOccurrence(for: pills.id) == Occurrence(dueTime: NewYork.local(2026, 10, 16), state: .nudging(nudgeNumber: 1)))
    }

    /// Paused at nudge 3 (+45 min for Firm), the occurrence stays Skipped while paused: past the
    /// time Firm would give up (+2 h 17 min 30 s) and past the next day's due time. It never
    /// becomes Missed, so My Day (ticket 16) can't count it as one.
    @Test(arguments: [
        NewYork.local(2026, 10, 15, 12),
        NewYork.local(2026, 10, 16, 10),
    ])
    func aSkippedOccurrenceNeverBecomesMissedWhilePaused(readAt: Date) {
        clock.now = NewYork.local(2026, 10, 15, 9, 45)
        var engine = engine(for: pills)
        engine.pause(pills.id)

        clock.now = readAt
        engine.update(reminders: [pills])

        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .skipped(reason: .paused))
    }

    /// Nor after Resume: read a day later, the occurrence paused at nudge 3 is still Skipped.
    @Test func aSkippedOccurrenceStaysSkippedAfterResume() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 45)
        var engine = engine(for: pills)
        engine.pause(pills.id)
        clock.now = NewYork.local(2026, 10, 17, 9, 30)
        try engine.resume(pills.id)

        clock.now = NewYork.local(2026, 10, 18, 10)
        engine.update(reminders: [pills])

        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .skipped(reason: .paused))
    }

    /// Nothing is open while paused, so a Done (say, from a notification still on screen) is
    /// ignored as ticket 07 ignores any Done with nothing open. It doesn't turn Skipped into Done.
    @Test func doneWhilePausedIsIgnored() {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        engine.pause(pills.id)

        engine.markDone(pills.id)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .skipped(reason: .paused))
        #expect(engine.isPaused(pills.id))
    }

    /// A repeat that ran out (COUNT=3: the 15th, 16th and 17th) while paused has no future due
    /// time either, so Resume is rejected the same way as a passed Never.
    @Test func resumingARepeatThatEndedWhilePausedNeedsANewDueTime() throws {
        let rule = try RepeatRule(rrule: "FREQ=DAILY;COUNT=3")
        let course = Reminder(title: "Finish the antibiotics", dueTime: NewYork.local(2026, 10, 15), repeatRule: rule, strength: .firm)
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: course)
        engine.pause(course.id)

        clock.now = NewYork.local(2026, 10, 18)
        #expect(throws: ResumeError.needsNewDueTime) { try engine.resume(course.id) }
        #expect(engine.isPaused(course.id))
    }

    /// Resume on a reminder that isn't paused is ignored, and doesn't throw.
    @Test func resumingAReminderThatIsNotPausedChangesNothing() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)

        try engine.resume(pills.id)

        #expect(engine.openOccurrence(for: pills.id) == Occurrence(dueTime: NewYork.local(2026, 10, 15), state: .nudging(nudgeNumber: 2)))
    }
}
