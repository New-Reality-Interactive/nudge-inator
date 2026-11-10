import Foundation
import Testing
@testable import NudgeEngine

/// A sender's edit to a received reminder replaces its content even while the copy is Nudging
/// (ADR 0005), and says what changed. The recipient's own lock is unchanged (ADR 0002).
struct SendersRevisionTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    let connectionID = UUID()
    let sendersReminderID = UUID()

    /// Every day at 9:00 from Thursday 15 October 2026, Firm, revision 3.
    func received(state: ReminderOrigin.ReceivedState = .accepted) -> Reminder {
        Reminder(
            title: "Take the pills",
            notes: "With food",
            dueTime: NewYork.local(2026, 10, 15),
            repeatRule: .everyDay,
            strength: .firm,
            origin: .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 3, state: state)
        )
    }

    /// A one-off due at 9:00 on 15 October 2026.
    func receivedOneOff(state: ReminderOrigin.ReceivedState = .accepted) -> Reminder {
        var reminder = received(state: state)
        reminder.repeatRule = nil
        return reminder
    }

    /// The sender's next version of `reminder`: revision 4, with the change applied.
    func revision(of reminder: Reminder, _ change: (inout Reminder) -> Void) -> Reminder {
        var revised = reminder
        revised.origin = .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 4, state: .accepted)
        change(&revised)
        return revised
    }

    func engine(for reminders: Reminder...) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    // MARK: While Nudging

    @Test func aNewDueTimeWhileNudgingClosesTheOpenOccurrenceAsSkippedAndPlansFromTheNewTime() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)
        #expect(engine.openOccurrence(for: reminder.id) != nil)

        let note = engine.applySendersRevision(revision(of: reminder) { $0.dueTime = NewYork.local(2026, 10, 15, 10) })

        #expect(note == [.dueTime(from: NewYork.local(2026, 10, 15), to: NewYork.local(2026, 10, 15, 10))])
        #expect(engine.openOccurrence(for: reminder.id) == nil)
        #expect(engine.occurrence(of: reminder.id, dueAt: NewYork.local(2026, 10, 15))?.state == .skipped(reason: .paused))
        let first = try #require(scheduler.lastPlan?.items.min { $0.fireTime < $1.fireTime })
        #expect(first.fireTime == NewYork.local(2026, 10, 15, 10))
    }

    /// One revision per field the lock covers, each applied at 9:10, ten minutes into nudge 2.
    static let lockedRevisions: [LockedRevision] = [
        LockedRevision(field: .dueTime) { $0.dueTime = NewYork.local(2026, 10, 15, 10) },
        LockedRevision(field: .repeatRule) { $0.repeatRule = .everyWeekday },
        LockedRevision(field: .strength) { $0.strength = .gentle },
        LockedRevision(field: .pace) { $0.pace = .consistent(wait: 10 * 60) },
        LockedRevision(field: .breakThroughFocus) { $0.breakThroughFocus = false },
    ]

    struct LockedRevision: Sendable, CustomTestStringConvertible {
        let field: ReceivedContentField
        let change: @Sendable (inout Reminder) -> Void

        init(field: ReceivedContentField, change: @escaping @Sendable (inout Reminder) -> Void) {
            self.field = field
            self.change = change
        }

        var testDescription: String { "\(field)" }
    }

    @Test(arguments: lockedRevisions)
    func aChangeToAnyLockedFieldWhileNudgingClosesTheOpenOccurrenceAsSkipped(revision change: LockedRevision) {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)

        let note = engine.applySendersRevision(revision(of: reminder, change.change))

        #expect(note.map(\.field) == [change.field])
        #expect(engine.openOccurrence(for: reminder.id) == nil)
        #expect(engine.occurrence(of: reminder.id, dueAt: NewYork.local(2026, 10, 15))?.state == .skipped(reason: .paused))
        #expect(engine.lockedFields(of: reminder.id).isEmpty)
    }

    /// The same outcome as Pause, edit and Resume: the closed occurrence and the plan match.
    @Test func theOutcomeMatchesPauseEditAndResume() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var personal = reminder
        personal.origin = .mine
        var viaRevision = engine(for: reminder)
        viaRevision.applySendersRevision(revision(of: reminder) { $0.strength = .gentle; $0.dueTime = NewYork.local(2026, 10, 15, 8) })
        let revisionPlan = try #require(scheduler.lastPlan)

        let otherScheduler = FakeScheduler()
        var viaPause = Engine(clock: clock, scheduler: otherScheduler, timeZone: NewYork.timeZone)
        viaPause.update(reminders: [personal])
        viaPause.pause(reminder.id)
        var edited = personal
        edited.strength = .gentle
        edited.dueTime = NewYork.local(2026, 10, 15, 8)
        try viaPause.edit(edited)
        try viaPause.resume(reminder.id)

        #expect(revisionPlan.items == otherScheduler.lastPlan?.items)
        #expect(viaRevision.latestOccurrence(for: reminder.id) == viaPause.latestOccurrence(for: reminder.id))
    }

    @Test func theNewValuesNudgeFromTheNextOccurrence() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)

        engine.applySendersRevision(revision(of: reminder) { $0.strength = .relentless })

        let first = try #require(scheduler.lastPlan?.items.min { $0.fireTime < $1.fireTime })
        #expect(first.fireTime == NewYork.local(2026, 10, 16))
        #expect(first.deliveryKind == .alarm)
        clock.now = NewYork.local(2026, 10, 16, 9, 5)
        engine.update(reminders: engine.reminders)
        #expect(engine.openOccurrence(for: reminder.id)?.dueTime == NewYork.local(2026, 10, 16))
    }

    /// The pause that closes the open occurrence is lifted at once, so a new due time of right now
    /// nudges, which Pause and Resume at that instant would have skipped.
    @Test func aNewDueTimeOfRightNowStartsNudgingAtOnce() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)

        engine.applySendersRevision(revision(of: reminder) { $0.dueTime = NewYork.local(2026, 10, 15, 9, 10) })

        #expect(engine.occurrence(of: reminder.id, dueAt: NewYork.local(2026, 10, 15))?.state == .skipped(reason: .paused))
        #expect(engine.openOccurrence(for: reminder.id)?.dueTime == NewYork.local(2026, 10, 15, 9, 10))
    }

    // MARK: Title and notes

    @Test func aNewTitleAndNotesApplyAtOnceWithoutClosingTheNudgingOccurrence() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)
        let open = engine.openOccurrence(for: reminder.id)

        let note = engine.applySendersRevision(revision(of: reminder) { $0.title = "Take the vitamins"; $0.notes = "Without food" })

        #expect(note == [.title(from: "Take the pills", to: "Take the vitamins"), .notes(from: "With food", to: "Without food")])
        #expect(engine.reminders.first?.title == "Take the vitamins")
        #expect(engine.reminders.first?.notes == "Without food")
        #expect(engine.openOccurrence(for: reminder.id) == open)
    }

    // MARK: The change note

    @Test func theNoteCarriesTheOldAndNewValueOfEveryChangedField() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let reminder = received()
        var engine = engine(for: reminder)

        let note = engine.applySendersRevision(revision(of: reminder) {
            $0.repeatRule = .everyWeekday
            $0.strength = .relentless
            $0.pace = .consistent(wait: 600)
            $0.breakThroughFocus = false
        })

        #expect(note == [
            .repeatRule(from: .everyDay, to: .everyWeekday),
            .strength(from: .firm, to: .relentless),
            .pace(from: .escalating, to: .consistent(wait: 600)),
            .breakThroughFocus(from: true, to: false),
        ])
    }

    @Test func aRevisionThatChangesNothingGivesAnEmptyNoteAndClosesNothing() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)
        let plansBefore = scheduler.appliedPlans.count

        let note = engine.applySendersRevision(revision(of: reminder) { _ in })

        #expect(note.isEmpty)
        #expect(engine.openOccurrence(for: reminder.id) != nil)
        #expect(scheduler.appliedPlans.count == plansBefore)
    }

    @Test func theCopyKeepsItsOwnTagsAndCreationDateAndTakesTheNewRevision() {
        clock.now = NewYork.local(2026, 10, 15, 8)
        var reminder = received()
        reminder.tagIDs = [Tag.ID()]
        reminder.createdAt = NewYork.local(2026, 10, 14)
        var engine = engine(for: reminder)

        engine.applySendersRevision(revision(of: reminder) { $0.tagIDs = []; $0.createdAt = .distantPast; $0.title = "New" })

        #expect(engine.reminders.first?.tagIDs == reminder.tagIDs)
        #expect(engine.reminders.first?.createdAt == reminder.createdAt)
        #expect(engine.reminders.first?.origin == .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 4, state: .accepted))
    }

    // MARK: Waiting, paused and late copies

    @Test func aWaitingCopyTakesTheChangeInPlaceAndStaysWaitingPlanningNothing() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = receivedOneOff(state: .waiting)
        var engine = engine(for: reminder)

        let note = engine.applySendersRevision(revision(of: reminder) { $0.title = "Call back"; $0.dueTime = NewYork.local(2026, 10, 15, 11) })

        #expect(note.count == 2)
        #expect(engine.reminders.first?.isWaiting == true)
        #expect(engine.reminders.first?.dueTime == NewYork.local(2026, 10, 15, 11))
        #expect(try #require(scheduler.lastPlan).items.isEmpty)

        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        engine.accept(reminder.id)
        #expect(try #require(scheduler.lastPlan?.items.min { $0.fireTime < $1.fireTime }).fireTime == NewYork.local(2026, 10, 15, 11))
    }

    /// Due at 9:00 and still waiting at 14:00, a one-off takes a new title; accepted then, it nudges at once.
    @Test func aPastDueWaitingOneOffRevisedThenAcceptedNudgesAtOnce() {
        clock.now = NewYork.local(2026, 10, 15, 14)
        let reminder = receivedOneOff(state: .waiting)
        var engine = engine(for: reminder)

        engine.applySendersRevision(revision(of: reminder) { $0.title = "Call back" })
        #expect(engine.openOccurrence(for: reminder.id) == nil)
        engine.accept(reminder.id)

        #expect(engine.reminders.first?.title == "Call back")
        #expect(engine.openOccurrence(for: reminder.id)?.dueTime == NewYork.local(2026, 10, 15, 14))
    }

    @Test func aWaitingRepeatingCopyStartsFromTheNewScheduleOnceAccepted() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received(state: .waiting)
        var engine = engine(for: reminder)

        engine.applySendersRevision(revision(of: reminder) { $0.repeatRule = .everyWeekday })
        #expect(try #require(scheduler.lastPlan).items.isEmpty)

        engine.accept(reminder.id)
        #expect(engine.reminders.first?.repeatRule == .everyWeekday)
        #expect(try #require(scheduler.lastPlan?.items.min { $0.fireTime < $1.fireTime }).fireTime == NewYork.local(2026, 10, 16))
    }

    @Test func aPausedCopyTakesTheChangeInPlaceAndStaysPaused() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)
        engine.pause(reminder.id)

        engine.applySendersRevision(revision(of: reminder) { $0.strength = .gentle })

        #expect(engine.isPaused(reminder.id))
        #expect(engine.reminders.first?.strength == .gentle)
        #expect(engine.latestOccurrence(for: reminder.id)?.state == .skipped(reason: .paused))
    }

    /// Accepted at 14:00, a one-off due at 9:00 has its due time set to 14:00. The sender's revision
    /// carries the original 9:00, which is no change, and the copy isn't a long-overdue Missed.
    @Test func aLateAcceptedOneOffKeepsItsDueTimeWhenTheSenderChangesOnlyTheTitle() {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let reminder = receivedOneOff(state: .waiting)
        var engine = engine(for: reminder)
        clock.now = NewYork.local(2026, 10, 15, 14)
        engine.accept(reminder.id)
        let acceptedDueTime = NewYork.local(2026, 10, 15, 14)
        #expect(engine.reminders.first?.dueTime == acceptedDueTime)

        clock.now = NewYork.local(2026, 10, 15, 14, 5)
        let note = engine.applySendersRevision(revision(of: reminder) { $0.title = "Call back" })

        #expect(note == [.title(from: "Take the pills", to: "Call back")])
        #expect(engine.reminders.first?.dueTime == acceptedDueTime)
        #expect(engine.openOccurrence(for: reminder.id)?.dueTime == acceptedDueTime)
    }

    @Test func aLateAcceptedOneOffTakesANewFutureDueTimeFromTheSender() throws {
        clock.now = NewYork.local(2026, 10, 15, 14)
        let reminder = receivedOneOff(state: .waiting)
        var engine = engine(for: reminder)
        engine.accept(reminder.id)

        clock.now = NewYork.local(2026, 10, 15, 14, 5)
        let note = engine.applySendersRevision(revision(of: reminder) { $0.dueTime = NewYork.local(2026, 10, 15, 18) })

        #expect(note == [.dueTime(from: NewYork.local(2026, 10, 15, 14), to: NewYork.local(2026, 10, 15, 18))])
        #expect(engine.openOccurrence(for: reminder.id) == nil)
        #expect(try #require(scheduler.lastPlan?.items.min { $0.fireTime < $1.fireTime }).fireTime == NewYork.local(2026, 10, 15, 18))
    }

    // MARK: What stays as it was

    @Test(arguments: SendersRevisionTests.lockedRevisions)
    func theRecipientsOwnEditIsStillLockedWhileNudgingAndRejectedWhole(revision change: LockedRevision) {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)
        engine.applySendersRevision(revision(of: reminder) { _ in })

        var edited = reminder
        change.change(&edited)

        #expect(throws: EditError.receivedContent([change.field])) { try engine.edit(edited) }
        #expect(engine.reminders.first?.origin == .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 4, state: .accepted))
        #expect(engine.openOccurrence(for: reminder.id) != nil)
    }

    @Test func aPersonalReminderIsLeftAloneByTheCall() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        var mine = received()
        mine.origin = .mine
        var engine = engine(for: mine)
        let plansBefore = scheduler.appliedPlans.count

        var revised = mine
        revised.strength = .gentle
        let note = engine.applySendersRevision(revised)

        #expect(note.isEmpty)
        #expect(engine.reminders == [mine])
        #expect(engine.openOccurrence(for: mine.id) != nil)
        #expect(scheduler.appliedPlans.count == plansBefore)
    }

    // MARK: Stale revisions

    /// The copy holds revision 3. 4 is newer; 3 is the same revision again; 2 came late.
    @Test(arguments: [3, 2])
    func aRevisionThatIsNotNewerThanTheCopysIsIgnored(number: Int) {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)
        let plansBefore = scheduler.appliedPlans.count
        var stale = revision(of: reminder) { $0.strength = .gentle; $0.title = "Old news" }
        stale.origin = .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: number, state: .accepted)

        let note = engine.applySendersRevision(stale)

        #expect(note.isEmpty)
        #expect(engine.reminders == [reminder])
        #expect(engine.openOccurrence(for: reminder.id) != nil)
        #expect(scheduler.appliedPlans.count == plansBefore)
    }

    @Test func aLateRevisionAfterANewerOneDoesNotUndoIt() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let reminder = received()
        var engine = engine(for: reminder)
        var newer = revision(of: reminder) { $0.title = "Take the vitamins" }
        newer.origin = .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 5, state: .accepted)
        engine.applySendersRevision(newer)

        let note = engine.applySendersRevision(revision(of: reminder) { $0.title = "Take the minerals" })

        #expect(note.isEmpty)
        #expect(engine.reminders.first?.title == "Take the vitamins")
        #expect(engine.reminders.first?.origin == .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 5, state: .accepted))
    }

    @Test func aRevisionOfAReminderTheEngineDoesNotHoldIsIgnored() {
        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        var engine = engine(for: received())

        #expect(engine.applySendersRevision(received()).isEmpty)
    }
}
