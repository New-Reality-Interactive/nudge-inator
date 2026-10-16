import Foundation
import Testing
@testable import NudgeEngine

/// Delete removes a reminder and everything the engine holds for it: its plan items, its
/// occurrences (removed, not left as Missed) and its Done and pause records, as the mockup's
/// `deleteReminder` drops the reminder and its occurrences together. The confirmation is the
/// screen's (ticket 27).
struct DeleteReminderTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    /// Every day at 9:00 from Thursday 15 October 2026.
    let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)

    func engine(for reminders: [Reminder]) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    @Test func deletingANudgingReminderLeavesNothingPlannedOrOpenForIt() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: [pills])

        engine.delete(pills.id)

        #expect(try #require(scheduler.lastPlan).items.isEmpty)
        #expect(engine.openOccurrence(for: pills.id) == nil)
        #expect(engine.latestOccurrence(for: pills.id) == nil)
        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15)) == nil)
    }

    /// The bins are Nudging too, so both reminders have a ladder in the plan when the pills go.
    @Test func deletingOneReminderLeavesAnothersPlanItemsUnchanged() throws {
        let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 15, 9, 15), strength: .relentless)
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: [pills, bins])
        let binsItemsBefore = try #require(scheduler.lastPlan).items.filter { $0.reminderID == bins.id }

        engine.delete(pills.id)

        let plan = try #require(scheduler.lastPlan)
        #expect(!binsItemsBefore.isEmpty)
        #expect(plan.items == binsItemsBefore)
        #expect(engine.openOccurrence(for: bins.id)?.dueTime == NewYork.local(2026, 10, 15, 9, 15))
    }

    /// Like Done with nothing open, there's nothing to act on, so nothing is reported and no
    /// plan is re-applied. The second Delete can come from two surfaces at once.
    @Test func deletingAReminderTwiceIgnoresTheSecond() {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: [pills])
        engine.delete(pills.id)
        let plansBefore = scheduler.appliedPlans.count

        engine.delete(pills.id)

        #expect(scheduler.appliedPlans.count == plansBefore)
        #expect(engine.latestOccurrence(for: pills.id) == nil)
    }

    @Test func deletingAnUnknownReminderChangesNothing() {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: [pills])
        let plansBefore = scheduler.appliedPlans.count

        engine.delete(UUID())

        #expect(scheduler.appliedPlans.count == plansBefore)
        #expect(engine.openOccurrence(for: pills.id)?.dueTime == NewYork.local(2026, 10, 15))
    }

    /// Delete takes the reminder's history with it (the mockup's "This deletes its history
    /// too"), so a reminder that comes back under the same ID doesn't inherit a Done.
    @Test func aReminderAddedBackAfterDeleteDoesNotInheritItsDone() {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: [pills])
        engine.markDone(pills.id)

        engine.delete(pills.id)
        engine.update(reminders: [pills])

        #expect(engine.latestOccurrence(for: pills.id)?.state == .nudging(nudgeNumber: 2))
    }

    @Test func aPausedReminderAddedBackAfterDeleteIsNotPausedOrSkipped() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: [pills])
        engine.pause(pills.id)

        engine.delete(pills.id)
        engine.update(reminders: [pills])

        #expect(!engine.isPaused(pills.id))
        #expect(engine.latestOccurrence(for: pills.id)?.state == .nudging(nudgeNumber: 2))
        #expect(try #require(scheduler.lastPlan).items.contains { $0.reminderID == pills.id })
    }

    /// The app may push the store's new list before it sends Delete. The reminder is already gone,
    /// so there's no plan to re-apply, but its history still goes.
    @Test func deletingAReminderAlreadyDroppedFromTheListStillClearsItsHistory() {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: [pills])
        engine.markDone(pills.id)
        engine.pause(pills.id)
        engine.update(reminders: [])
        let plansBefore = scheduler.appliedPlans.count

        engine.delete(pills.id)
        #expect(scheduler.appliedPlans.count == plansBefore)
        engine.update(reminders: [pills])

        #expect(!engine.isPaused(pills.id))
        #expect(engine.latestOccurrence(for: pills.id)?.state == .nudging(nudgeNumber: 2))
    }

    /// An Edit while Nudging keeps the old title on nudges already delivered. That record goes with
    /// Delete, so a reminder added back under the same ID carries only its own title, passed
    /// nudges included.
    @Test func aReminderAddedBackAfterDeleteDoesNotInheritItsEarlierTitles() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: [pills])
        var edited = pills
        edited.title = "Take the vitamins"
        try engine.edit(edited)

        engine.delete(pills.id)
        var addedBack = pills
        addedBack.title = "Water the plants"
        engine.update(reminders: [addedBack])

        let items = try #require(scheduler.lastPlan).items
        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.title == "Water the plants" })
    }
}
