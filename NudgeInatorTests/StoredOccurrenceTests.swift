import Foundation
import Testing
import NudgeEngine
@testable import NudgeInator

/// Occurrence state isn't saved as such: it's worked out from the clock and what the store saves
/// (reminders, tags and histories). Each test runs an engine, saves it to a temporary file, opens
/// the file in a new store, and hands what it reads to a new engine at the same clock.
@MainActor
struct StoredOccurrenceTests {
    let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    /// Thursday 15 October 2026 at 9:00, once. Firm nudges at 9:00, 9:30, 9:45 and 9:52:30.
    let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15), strength: .firm)

    func engine(holding reminder: Reminder) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder])
        return engine
    }

    /// Saves `engine`, then reads it back from disk into a new engine, in ticket 21's launch order.
    func relaunched(from engine: Engine) throws -> Engine {
        try ReminderStore(location: .file(fileURL))
            .save(StoredData(reminders: engine.reminders, tags: engine.tags, histories: engine.histories))
        let stored = try ReminderStore(location: .file(fileURL)).load()
        var relaunched = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        relaunched.update(tags: stored.tags)
        relaunched.update(histories: stored.histories)
        relaunched.update(reminders: stored.reminders)
        return relaunched
    }

    @Test func doneReadsBackAsDone() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 55)
        var engine = engine(holding: call)
        engine.markDone(call.id)

        let relaunched = try relaunched(from: engine)

        #expect(relaunched.latestOccurrence(for: call.id)?.state == .done)
    }

    @Test func nudgingAtNudgeFourReadsBackAtNudgeFour() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 55)
        let engine = engine(holding: call)

        let relaunched = try relaunched(from: engine)

        let occurrence = try #require(relaunched.openOccurrence(for: call.id))
        #expect(occurrence.dueTime == call.dueTime)
        #expect(occurrence.state == .nudging(nudgeNumber: 4))
    }

    @Test func missedAtTheGiveUpLimitReadsBackWithItsReason() throws {
        clock.now = NewYork.local(2026, 10, 16)
        let engine = engine(holding: call)

        let relaunched = try relaunched(from: engine)

        #expect(relaunched.latestOccurrence(for: call.id)?.state == .missed(reason: .giveUpLimit))
    }

    /// Missed at 11:12:30, then edited to Gentle, which would still be nudging at noon: the Edit fixed the
    /// Missed closing, and the store keeps it.
    @Test func missedFixedByAnEditReadsBackMissed() throws {
        clock.now = NewYork.local(2026, 10, 15, 12)
        var engine = engine(holding: call)
        var gentle = call
        gentle.strength = .gentle
        try engine.edit(gentle)

        let relaunched = try relaunched(from: engine)

        #expect(relaunched.latestOccurrence(for: call.id)?.state == .missed(reason: .giveUpLimit))
    }

    @Test func skippedByAPauseReadsBackSkippedAndStillPaused() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 55)
        var engine = engine(holding: call)
        engine.pause(call.id)

        let relaunched = try relaunched(from: engine)

        #expect(relaunched.latestOccurrence(for: call.id)?.state == .skipped(reason: .paused))
        #expect(relaunched.isPaused(call.id))
    }
}
