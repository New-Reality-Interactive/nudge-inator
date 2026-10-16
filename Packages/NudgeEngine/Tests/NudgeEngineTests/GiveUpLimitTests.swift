import Foundation
import Testing
@testable import NudgeEngine

/// The give-up limit: 20 nudges or 24 hours after the due time, whichever comes first. As in the
/// mockup's `simulate`, the occurrence gives up one wait after its last nudge (when the next
/// nudge would have fired), or at 24 hours if that comes sooner.
struct GiveUpLimitTests {
    let dueTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let clock: FakeClock
    let scheduler = FakeScheduler()

    init() {
        clock = FakeClock(now: dueTime)
    }

    func engine(for reminder: Reminder) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])
        return engine
    }

    /// Nudge 20 fires at +7 h 44 min 4 s (Gentle), +2 h 12 min 30 s (Firm) and +49 min 30 s
    /// (Relentless); one floor wait later (20, 5 and 2 min) the occurrence gives up, at
    /// +8 h 4 min 4 s, +2 h 17 min 30 s and +51 min 30 s. Every one is well inside 24 hours.
    @Test(arguments: [
        (Strength.gentle, 29044),
        (.firm, 8250),
        (.relentless, 3090),
    ])
    func countWinsAndOccurrenceClosesAsMissedOneWaitAfterNudgeTwenty(strength: Strength, giveUpSecond: Int) throws {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: strength)

        clock.now = dueTime + TimeInterval(giveUpSecond - 1)
        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.state == .nudging(nudgeNumber: 20))

        clock.now = dueTime + TimeInterval(giveUpSecond)
        let occurrence = try #require(engine(for: reminder).latestOccurrence(for: reminder.id))
        #expect(occurrence.state == .missed(reason: .giveUpLimit))
    }

    /// No strength's ladder lasts 24 hours today, so the span can only win with a shorter one.
    /// The span is internal (the spec fixes the limit and gives it no editor); the `Ladder`
    /// constants stay as they are. With 3 hours, Gentle sends nudges 1–5 (+0, +1 h, +1 h 45 min,
    /// +2 h 18 min 45 s, +2 h 44 min 4 s); nudge 6 would be at +3 h 4 min 4 s, past the span.
    @Test func gentleTimeWinsWithThreeHourSpanAfterNudgeFiveAndClosesAsMissedAtThreeHours() throws {
        let reminder = Reminder(title: "Water the plants", dueTime: dueTime, strength: .gentle)
        var engine = Engine(clock: clock, scheduler: scheduler, giveUpLimit: GiveUpLimit(nudgeCount: 20, span: 3 * 60 * 60))
        engine.update(reminders: [reminder])

        #expect(try #require(scheduler.lastPlan).items.map(\.nudgeNumber) == Array(1...5))

        clock.now = dueTime + 10_799
        #expect(engine.latestOccurrence(for: reminder.id)?.state == .nudging(nudgeNumber: 5))

        clock.now = dueTime + 10_800
        #expect(engine.latestOccurrence(for: reminder.id)?.state == .missed(reason: .giveUpLimit))
    }

    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func planHoldsNoNudgePastTwentyOrTwentyFourHours(strength: Strength) throws {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: strength)
        _ = engine(for: reminder)
        let items = try #require(scheduler.lastPlan).items

        #expect(items.map(\.nudgeNumber) == Array(1...20))
        #expect(items.allSatisfy { $0.fireTime < dueTime + 24 * 60 * 60 })
    }

    /// The app gets no callback when a nudge fires, so time passing doesn't re-plan on its own.
    /// The app hands the engine its reminders again (on launch or foreground) and gets a fresh plan.
    @Test(arguments: [
        (Strength.gentle, 29044),
        (.firm, 8250),
        (.relentless, 3090),
    ])
    func afterClosingAsMissedThePlanHoldsNothingForTheOccurrence(strength: Strength, giveUpSecond: Int) throws {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: strength)
        var engine = engine(for: reminder)

        clock.now = dueTime + TimeInterval(giveUpSecond)
        engine.update(reminders: [reminder])

        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    @Test func missedOccurrenceIsNoLongerOpen() {
        let reminder = Reminder(title: "Leave for the train", dueTime: dueTime, strength: .relentless)
        clock.now = dueTime + 3090
        #expect(engine(for: reminder).openOccurrence(for: reminder.id) == nil)
    }
}
