import Foundation
import Testing
@testable import NudgeEngine

/// While a reminder has a Nudging occurrence, its due time, repeat, strength, pace and Break through
/// Focus are Locked (ADR 0002): an Edit that changes any of them is rejected whole. Title, notes and tags
/// stay editable. The lock lifts when the occurrence closes.
struct LockWhileNudgingTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    /// Every day at 9:00 from Thursday 15 October 2026.
    let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)

    func engine(for reminder: Reminder) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder])
        return engine
    }

    /// Firm's nudges 1 and 2 came at 9:00 and 9:30, before the 9:40 Edit, so they keep the title
    /// they were delivered with. Every later item, the next day's ladder included, carries the new one.
    @Test func editingTheTitleWhileNudgingChangesOnlyLaterPlanItems() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)

        var edited = pills
        edited.title = "Take the vitamins"
        try engine.edit(edited)

        let items = try #require(scheduler.lastPlan).items
        let passed = items.filter { $0.fireTime <= clock.now }
        let later = items.filter { $0.fireTime > clock.now }
        #expect(passed.map(\.nudgeNumber) == [1, 2])
        #expect(passed.allSatisfy { $0.title == "Take the pills" })
        #expect(!later.isEmpty)
        #expect(later.allSatisfy { $0.title == "Take the vitamins" })
    }

    /// Firm's nudge 3 fires at 9:45, between two title Edits at 9:40 and 9:50, so it keeps the
    /// middle title. Nudges 1 and 2 keep the first, and everything after 9:50 carries the last.
    @Test func eachPassedNudgeKeepsTheTitleItWasDeliveredWith() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        var edited = pills
        edited.title = "Take the vitamins"
        try engine.edit(edited)

        clock.now = NewYork.local(2026, 10, 15, 9, 50)
        edited.title = "Take the fish oil"
        try engine.edit(edited)

        let items = try #require(scheduler.lastPlan).items
        let today = items.filter { $0.fireTime < NewYork.local(2026, 10, 16) }
        #expect(today.prefix(3).map(\.title) == ["Take the pills", "Take the pills", "Take the vitamins"])
        #expect(items.dropFirst(3).allSatisfy { $0.title == "Take the fish oil" })
    }

    /// One edit per locked field, each a value the form could save.
    static let lockedEdits: [(LockedField, @Sendable (inout Reminder) -> Void)] = [
        (.dueTime, { $0.dueTime = NewYork.local(2026, 10, 15, 10) }),
        (.repeatRule, { $0.repeatRule = .everyWeekday }),
        (.strength, { $0.strength = .gentle }),
        (.pace, { $0.pace = .consistent(wait: 10 * 60) }),
        (.breakThroughFocus, { $0.breakThroughFocus = false }),
    ]

    @Test(arguments: lockedEdits)
    func anEditThatChangesAnyLockedFieldWhileNudgingIsRejectedNamingThatField(
        field: LockedField,
        change: @Sendable (inout Reminder) -> Void
    ) {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        let occurrenceBefore = engine.openOccurrence(for: pills.id)
        let plansBefore = scheduler.appliedPlans

        var edited = pills
        change(&edited)
        #expect(throws: EditError.locked([field])) { try engine.edit(edited) }

        #expect(engine.openOccurrence(for: pills.id) == occurrenceBefore)
        #expect(scheduler.appliedPlans == plansBefore)
        #expect(engine.lockedFields(of: pills.id) == Set(LockedField.allCases))
    }

    /// A Consistent reminder's wait is part of its pace, so changing only the wait is rejected too.
    @Test func changingAConsistentWaitWhileNudgingIsRejectedAsAPaceChange() {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var consistent = pills
        consistent.pace = .consistent(wait: 30 * 60)
        var engine = engine(for: consistent)
        let plansBefore = scheduler.appliedPlans

        var edited = consistent
        edited.pace = .consistent(wait: 15 * 60)
        #expect(throws: EditError.locked([.pace])) { try engine.edit(edited) }
        edited.pace = .escalating
        #expect(throws: EditError.locked([.pace])) { try engine.edit(edited) }

        #expect(scheduler.appliedPlans == plansBefore)
    }

    /// No partial apply: the new title goes nowhere either, and the error names both locked fields.
    @Test func anEditThatChangesLockedFieldsAndTheTitleIsRejectedWhole() {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        let plansBefore = scheduler.appliedPlans

        var edited = pills
        edited.title = "Take the vitamins"
        edited.strength = .relentless
        edited.breakThroughFocus = false
        #expect(throws: EditError.locked([.strength, .breakThroughFocus])) { try engine.edit(edited) }

        #expect(scheduler.appliedPlans == plansBefore)
    }

    /// The form saves the whole reminder, so the locked fields arrive at their current values.
    @Test func notesAndTagsEditsWhileNudgingAreAcceptedAndNeverReachThePlan() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        let plansBefore = scheduler.appliedPlans.count

        var edited = pills
        edited.notes = "Behind the coffee"
        let home = Tag(name: "home")
        engine.update(tags: [home])
        edited.tagIDs = [home.id]
        try engine.edit(edited)

        #expect(scheduler.appliedPlans.count == plansBefore + 1)
        let texts = try #require(scheduler.lastPlan).items.flatMap { [$0.title, $0.body] }
        #expect(!texts.isEmpty)
        #expect(texts.allSatisfy { !$0.contains("coffee") && !$0.contains("home") && !$0.contains(home.id.uuidString) })
    }

    /// The Edit rejected at 9:40 is accepted once Done closes the occurrence at 9:50. Relentless
    /// applies from tomorrow's occurrence: its nudge 2 comes 10 minutes after the due time, Firm's 30.
    @Test func afterDoneTheRejectedEditIsAcceptedAndAppliesFromTheNextOccurrence() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        var edited = pills
        edited.strength = .relentless
        #expect(throws: EditError.locked([.strength])) { try engine.edit(edited) }

        clock.now = NewYork.local(2026, 10, 15, 9, 50)
        engine.markDone(pills.id)
        #expect(engine.lockedFields(of: pills.id).isEmpty)
        try engine.edit(edited)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .done)
        let items = try #require(scheduler.lastPlan).items
        #expect(items.first { $0.nudgeNumber == 2 }?.fireTime == NewYork.local(2026, 10, 16, 9, 10))
    }

    /// Firm gives up at +2 h 17 min 30 s. After that the same Edit is accepted, and today's
    /// occurrence stays Missed.
    @Test func afterMissedTheRejectedEditIsAcceptedAndAppliesFromTheNextOccurrence() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        var edited = pills
        edited.strength = .relentless
        #expect(throws: EditError.locked([.strength])) { try engine.edit(edited) }

        clock.now = NewYork.local(2026, 10, 15, 11, 30)
        engine.update(reminders: [pills])
        #expect(engine.lockedFields(of: pills.id).isEmpty)
        try engine.edit(edited)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .missed(reason: .giveUpLimit))
        let items = try #require(scheduler.lastPlan).items
        #expect(items.first { $0.nudgeNumber == 2 }?.fireTime == NewYork.local(2026, 10, 16, 9, 10))
    }

    /// Gentle would still be nudging at 11:30 (it gives up at +8 h 4 min 4 s), but today's
    /// occurrence already closed as Missed under Firm. An Edit applies from the next occurrence,
    /// so it doesn't reopen today's or lock the reminder again.
    @Test func anEditToASlowerStrengthAfterMissedLeavesTheOccurrenceMissed() throws {
        clock.now = NewYork.local(2026, 10, 15, 11, 30)
        var engine = engine(for: pills)
        var edited = pills
        edited.strength = .gentle
        try engine.edit(edited)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .missed(reason: .giveUpLimit))
        #expect(engine.lockedFields(of: pills.id).isEmpty)
        let items = try #require(scheduler.lastPlan).items
        #expect(items.allSatisfy { $0.fireTime >= NewYork.local(2026, 10, 16) })
    }

    /// The pace Edit rejected at 9:40 is accepted after Done at 9:50, and applies from tomorrow:
    /// Consistent · 2 min brings nudge 2 at 9:02, where Firm's came at 9:30.
    @Test func afterDoneTheRejectedPaceEditIsAcceptedAndAppliesFromTheNextOccurrence() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        var edited = pills
        edited.pace = .consistent(wait: 2 * 60)
        #expect(throws: EditError.locked([.pace])) { try engine.edit(edited) }

        clock.now = NewYork.local(2026, 10, 15, 9, 50)
        engine.markDone(pills.id)
        try engine.edit(edited)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .done)
        let items = try #require(scheduler.lastPlan).items
        #expect(items.first { $0.nudgeNumber == 2 }?.fireTime == NewYork.local(2026, 10, 16, 9, 2))
    }

    /// Consistent · 16 h would still be nudging at 11:30, but today's occurrence already closed as
    /// Missed under Firm's Escalating pace. Like a strength Edit, a pace Edit applies from the next
    /// occurrence, so it doesn't reopen today's or lock the reminder again.
    @Test func anEditToASlowerPaceAfterMissedLeavesTheOccurrenceMissed() throws {
        clock.now = NewYork.local(2026, 10, 15, 11, 30)
        var engine = engine(for: pills)
        var edited = pills
        edited.pace = .consistent(wait: 16 * 60 * 60)
        try engine.edit(edited)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .missed(reason: .giveUpLimit))
        #expect(engine.lockedFields(of: pills.id).isEmpty)
    }

    /// Missed at 11:17:30 under Firm, then paused at noon. A slower strength would have still been
    /// open at the Pause, but the occurrence had already closed, so it stays Missed, not Skipped.
    @Test func anEditWhilePausedLeavesAnOccurrenceMissedBeforeThePauseMissed() throws {
        clock.now = NewYork.local(2026, 10, 15, 12)
        var engine = engine(for: pills)
        engine.pause(pills.id)
        var edited = pills
        edited.strength = .gentle
        try engine.edit(edited)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .missed(reason: .giveUpLimit))
    }

    /// Pause, edit, Resume (ADR 0002): Pause closes the occurrence as Skipped, which lifts the lock,
    /// so the strength Edit is accepted. Resume brings the reminder back tomorrow at 9:00, as
    /// Relentless.
    @Test func pauseEditAndResumeChangesALockedFieldAndReturnsAtTheNextFutureTime() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        var edited = pills
        edited.strength = .relentless
        #expect(throws: EditError.locked([.strength])) { try engine.edit(edited) }

        engine.pause(pills.id)
        #expect(engine.lockedFields(of: pills.id).isEmpty)
        try engine.edit(edited)
        try engine.resume(pills.id)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .skipped(reason: .paused))
        let items = try #require(scheduler.lastPlan).items
        #expect(items.first?.fireTime == NewYork.local(2026, 10, 16))
        #expect(items.first { $0.nudgeNumber == 2 }?.fireTime == NewYork.local(2026, 10, 16, 9, 10))
    }

    /// A Never reminder at 9:00: not yet due at 8:00, and finished (Missed) at noon.
    @Test(arguments: [NewYork.local(2026, 10, 15, 8), NewYork.local(2026, 10, 15, 12)])
    func aReminderWithNothingNudgingReportsNothingLocked(at now: Date) {
        let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        clock.now = now
        let engine = engine(for: call)

        #expect(engine.lockedFields(of: call.id).isEmpty)
    }

    /// Paused before its due time, it stays unlocked after the due time passes.
    @Test func aPausedReminderReportsNothingLocked() {
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: pills)
        engine.pause(pills.id)

        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        engine.update(reminders: [pills])

        #expect(engine.lockedFields(of: pills.id).isEmpty)
    }

    /// The lock lifts at Done, and Done is kept by due time (ticket 07). So moving today's due time
    /// from 9:00 to 9:20 after Done at 9:30 makes 9:20 a new occurrence, which nudges at once. The
    /// form isn't meant to offer a past time (ticket 24).
    @Test func anEditAfterDoneThatMovesTheDueTimeEarlierTodayOpensThatOccurrence() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        var engine = engine(for: pills)
        engine.markDone(pills.id)

        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var edited = pills
        edited.dueTime = NewYork.local(2026, 10, 15, 9, 20)
        try engine.edit(edited)

        #expect(engine.openOccurrence(for: pills.id)?.dueTime == NewYork.local(2026, 10, 15, 9, 20))
        #expect(engine.lockedFields(of: pills.id) == Set(LockedField.allCases))
    }

    /// Like Done, Resume and Delete, an event with nothing to act on is ignored, not reported.
    @Test func anEditOfAReminderTheEngineDoesNotHoldIsIgnored() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        let plansBefore = scheduler.appliedPlans.count

        try engine.edit(Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15), strength: .firm))

        #expect(scheduler.appliedPlans.count == plansBefore)
        #expect(engine.lockedFields(of: pills.id) == Set(LockedField.allCases))
    }
}
