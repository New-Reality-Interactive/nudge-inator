import Foundation
import Testing
@testable import NudgeEngine

/// A reminder can be received from someone: the engine plans it exactly as the recipient's own, and
/// the recipient can change only its tags (spec #127, Receiving). Whether a copy is waiting to be
/// accepted is held but not acted on yet (#186).
struct ReceivedReminderTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    let connectionID = UUID()
    let sendersReminderID = UUID()
    let tag = Tag.ID()
    let otherTag = Tag.ID()

    /// Every day at 9:00 from Thursday 15 October 2026, `strength` and `pace` as given.
    func received(
        strength: Strength = .firm,
        pace: Pace = .escalating,
        breakThroughFocus: Bool = true,
        state: ReminderOrigin.ReceivedState = .accepted
    ) -> Reminder {
        Reminder(
            title: "Take the pills",
            notes: "With food",
            dueTime: NewYork.local(2026, 10, 15),
            repeatRule: .everyDay,
            strength: strength,
            pace: pace,
            breakThroughFocus: breakThroughFocus,
            origin: .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 3, state: state)
        )
    }

    /// The same reminder as a person's own.
    func mine(strength: Strength = .firm, pace: Pace = .escalating, breakThroughFocus: Bool = true) -> Reminder {
        var reminder = received(strength: strength, pace: pace, breakThroughFocus: breakThroughFocus)
        reminder.origin = .mine
        return reminder
    }

    func engine(for reminders: Reminder...) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    // MARK: Origin

    @Test func aReminderBuiltWithNoOriginIsMine() {
        let reminder = Reminder(title: "Call the plumber", dueTime: NewYork.local(2026, 10, 15), strength: .gentle)
        #expect(reminder.origin == .mine)
        #expect(!reminder.isReceived)
    }

    @Test func aReceivedReminderKeepsWhereItCameFrom() {
        let reminder = received(state: .waiting)
        #expect(reminder.origin == .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 3, state: .waiting))
        #expect(reminder.isReceived)
    }

    // MARK: Planned as the recipient's own

    @Test(arguments: [Strength.gentle, .firm, .relentless], [Pace.escalating, .consistent(wait: 10 * 60)])
    func aReceivedReminderPlansExactlyAsAPersonalOneWouldWithTheSameFields(strength: Strength, pace: Pace) throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 20)
        let receivedPlan = try plan(of: received(strength: strength, pace: pace))
        let minePlan = try plan(of: mine(strength: strength, pace: pace))

        #expect(!receivedPlan.items.isEmpty)
        #expect(receivedPlan == minePlan)
    }

    @Test func aReceivedRelentlessReminderBreaksThroughFocusWhateverItsSwitchSays() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let reminder = received(strength: .relentless, breakThroughFocus: false)
        #expect(reminder.breaksThroughFocus)

        let items = try plan(of: reminder).items
        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.deliveryKind == .alarm })
    }

    @Test func aReceivedReminderCountsTowardTheBadgeAndNowWhileNudging() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        let engine = engine(for: reminder)

        #expect(engine.openOccurrence(for: reminder.id) != nil)
        #expect(scheduler.lastPlan?.currentBadgeCount == 1)
    }

    @Test func aReceivedReminderIsLockedWhileNudgingLikeAPersonalOne() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        let engine = engine(for: reminder)
        #expect(engine.lockedFields(of: reminder.id) == Set(LockedField.allCases))
    }

    private func plan(of reminder: Reminder) throws -> SchedulePlan {
        _ = engine(for: reminder)
        return try #require(scheduler.lastPlan.map { plan in
            // Every item carries the reminder's own ID, which differs between the two reminders
            // compared; the rest is what must match.
            var plan = plan
            plan.items = plan.items.map { item in
                var item = item
                item.reminderID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
                return item
            }
            return plan
        })
    }

    // MARK: Editing

    @Test func editingOnlyTheTagsOfAReceivedReminderIsAccepted() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let reminder = received()
        var engine = engine(for: reminder)

        var edited = reminder
        edited.tagIDs = [tag, otherTag]
        try engine.edit(edited)

        #expect(engine.reminders.first?.tagIDs == [tag, otherTag])
        #expect(engine.reminders.first?.isReceived == true)
    }

    @Test func editingTagsWhileAReceivedReminderIsNudgingIsAccepted() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)

        var edited = reminder
        edited.tagIDs = [tag]
        try engine.edit(edited)

        #expect(engine.reminders.first?.tagIDs == [tag])
        #expect(engine.openOccurrence(for: reminder.id) != nil)
    }

    /// One edit per content field, each a value the form could save, with the clock idle and
    /// Nudging for each.
    static let contentEdits: [ContentEdit] = {
        let edits: [(ReceivedContentField, @Sendable (inout Reminder) -> Void)] = [
            (.title, { $0.title = "Take the vitamins" }),
            (.notes, { $0.notes = "Without food" }),
            (.dueTime, { $0.dueTime = NewYork.local(2026, 10, 15, 10) }),
            (.repeatRule, { $0.repeatRule = .everyWeekday }),
            (.strength, { $0.strength = .gentle }),
            (.pace, { $0.pace = .consistent(wait: 10 * 60) }),
            (.breakThroughFocus, { $0.breakThroughFocus = false }),
        ]
        return [NewYork.local(2026, 10, 15, 8), NewYork.local(2026, 10, 15, 9, 10)].flatMap { now in
            edits.map { ContentEdit(field: $0.0, now: now, change: $0.1) }
        }
    }()

    struct ContentEdit: Sendable, CustomTestStringConvertible {
        let field: ReceivedContentField
        let now: Date
        let change: @Sendable (inout Reminder) -> Void

        var testDescription: String { "\(field) at \(now)" }
    }

    @Test(arguments: contentEdits)
    func anEditThatChangesAContentFieldIsRejectedNamingThatFieldNudgingOrNot(edit: ContentEdit) {
        clock.now = edit.now
        let reminder = received()
        var engine = engine(for: reminder)
        let plansBefore = scheduler.appliedPlans.count

        var edited = reminder
        edit.change(&edited)

        #expect(throws: EditError.receivedContent([edit.field])) { try engine.edit(edited) }
        #expect(engine.reminders == [reminder])
        #expect(scheduler.appliedPlans.count == plansBefore)
    }

    @Test func anEditChangingContentAndTagsTogetherIsRejectedWholeWithNoTagApplied() {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let reminder = received()
        var engine = engine(for: reminder)

        var edited = reminder
        edited.tagIDs = [tag]
        edited.title = "Take the vitamins"
        edited.dueTime = NewYork.local(2026, 10, 15, 10)

        #expect(throws: EditError.receivedContent([.title, .dueTime])) { try engine.edit(edited) }
        #expect(engine.reminders == [reminder])
    }

    @Test func anEditCanNotTurnAReceivedReminderIntoOneOfMineOrChangeItsOrigin() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let reminder = received()
        var engine = engine(for: reminder)

        var edited = reminder
        edited.origin = .mine
        edited.tagIDs = [tag]
        try engine.edit(edited)

        #expect(engine.reminders.first?.origin == reminder.origin)
        #expect(engine.reminders.first?.tagIDs == [tag])
    }

    @Test func anEditCanNotTurnAPersonalReminderIntoAReceivedOne() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let reminder = mine()
        var engine = engine(for: reminder)

        var edited = reminder
        edited.origin = received().origin
        edited.tagIDs = [tag]
        try engine.edit(edited)

        #expect(engine.reminders.first?.origin == .mine)
        #expect(engine.reminders.first?.tagIDs == [tag])
    }

    @Test func aPersonalReminderStillEditsItsContentAsBefore() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let reminder = mine()
        var engine = engine(for: reminder)

        var edited = reminder
        edited.title = "Take the vitamins"
        edited.strength = .gentle
        try engine.edit(edited)

        #expect(engine.reminders.first?.title == "Take the vitamins")
        #expect(engine.reminders.first?.strength == .gentle)
    }

    // MARK: Done, Pause and Resume

    @Test func doneClosesAReceivedRemindersOpenOccurrenceAndCancelsItsNudges() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)

        engine.markDone(reminder.id)

        #expect(engine.latestOccurrence(for: reminder.id)?.state == .done)
        #expect(engine.openOccurrence(for: reminder.id) == nil)
        let items = try #require(scheduler.lastPlan).items
        #expect(items.allSatisfy { $0.dueTime > NewYork.local(2026, 10, 15) })
    }

    @Test func pauseAndResumeWorkOnAReceivedReminder() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)

        engine.pause(reminder.id)
        #expect(engine.isPaused(reminder.id))
        #expect(engine.latestOccurrence(for: reminder.id)?.state == .skipped(reason: .paused))
        #expect(try #require(scheduler.lastPlan).items.isEmpty)

        try engine.resume(reminder.id)
        #expect(!engine.isPaused(reminder.id))
        #expect(try #require(scheduler.lastPlan).items.first?.dueTime == NewYork.local(2026, 10, 16))
    }

    @Test func deletingAReceivedReminderCancelsItsNudges() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)

        engine.delete(reminder.id)

        #expect(engine.reminders.isEmpty)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }
}
