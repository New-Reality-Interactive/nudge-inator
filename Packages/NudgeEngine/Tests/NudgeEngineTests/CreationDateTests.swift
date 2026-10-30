import Foundation
import Testing
@testable import NudgeEngine

/// A reminder's creation date is the moment it was added, from the engine's clock. Nothing that
/// happens to the reminder afterwards changes it (GLOSSARY.md, Creation date).
struct CreationDateTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let scheduler = FakeScheduler()
    /// Every day at 9:00 from Thursday 15 October 2026.
    let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)

    func engine(adding reminder: Reminder) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.add(reminder)
        return engine
    }

    func createdAt(in engine: Engine) throws -> Date {
        try #require(engine.reminders.first { $0.id == pills.id }).createdAt
    }

    @Test func addingAReminderSetsItsCreationDateToNow() throws {
        let engine = engine(adding: pills)

        #expect(try createdAt(in: engine) == NewYork.local(2026, 10, 15, 8))
    }

    @Test func addingKeepsTheRemindersAlreadyThereAndAppendsTheNewOne() {
        var engine = engine(adding: pills)
        let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 15, 19), strength: .gentle)
        clock.now = NewYork.local(2026, 10, 15, 8, 30)

        engine.add(bins)

        #expect(engine.reminders.map(\.id) == [pills.id, bins.id])
        #expect(engine.reminders.map(\.createdAt) == [NewYork.local(2026, 10, 15, 8), NewYork.local(2026, 10, 15, 8, 30)])
    }

    @Test func addingPlansTheNewRemindersNudges() throws {
        _ = engine(adding: pills)

        #expect(try !#require(scheduler.lastPlan).items.isEmpty)
    }

    @Test func anEditKeepsTheCreationDateEvenWhenTheEditedValueCarriesAnother() throws {
        var engine = engine(adding: pills)
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        var edited = pills
        edited.title = "Take the evening pills"
        edited.createdAt = clock.now

        try engine.edit(edited)

        #expect(try createdAt(in: engine) == NewYork.local(2026, 10, 15, 8))
        #expect(try #require(engine.reminders.first).title == "Take the evening pills")
    }

    @Test func pauseResumeAndDoneKeepTheCreationDate() throws {
        var engine = engine(adding: pills)
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        engine.markDone(pills.id)
        engine.pause(pills.id)
        clock.now = NewYork.local(2026, 10, 15, 12)
        try engine.resume(pills.id)

        #expect(try createdAt(in: engine) == NewYork.local(2026, 10, 15, 8))
    }

    @Test func anOccurrenceGoingMissedKeepsTheCreationDate() throws {
        var engine = engine(adding: pills)
        clock.now = NewYork.local(2026, 10, 17, 12)
        engine.update(reminders: engine.reminders)

        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .missed(reason: .giveUpLimit))
        #expect(try createdAt(in: engine) == NewYork.local(2026, 10, 15, 8))
    }

    @Test func aReminderBuiltWithoutADateHasNoCreationDateUntilItIsAdded() {
        #expect(pills.createdAt == .distantPast)
    }
}
