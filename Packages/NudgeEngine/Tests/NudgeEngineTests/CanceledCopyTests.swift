import Foundation
import Testing
@testable import NudgeEngine

/// A copy whose sender deleted the reminder is Canceled (spec #127, Sender's changes; ticket 205):
/// it nudges no more, counts toward no badge, and stays until the recipient removes it, or its
/// connection ends, whichever of Remove or Keep as My Own Reminders is chosen.
struct CanceledCopyTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 9, 10))
    let scheduler = FakeScheduler()
    let connectionID = UUID()
    let sendersReminderID = UUID()

    /// Every day at 9:00 from Thursday 15 October 2026, Firm.
    func received(state: ReminderOrigin.ReceivedState = .accepted, title: String = "Take the pills") -> Reminder {
        Reminder(
            title: title,
            notes: "With food",
            dueTime: NewYork.local(2026, 10, 15),
            repeatRule: .everyDay,
            strength: .firm,
            origin: .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 3, state: state)
        )
    }

    func engine(for reminders: Reminder...) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    // MARK: Canceling

    @Test func cancelingANudgingCopyPlansNothingAndClosesItsOpenOccurrenceAsSkipped() throws {
        let copy = received()
        var engine = engine(for: copy)
        #expect(engine.openOccurrence(for: copy.id) != nil)
        #expect(!(try #require(scheduler.lastPlan).items.isEmpty))

        engine.cancel(copy.id)

        #expect(engine.reminder(copy.id)?.isCanceled == true)
        #expect(engine.openOccurrence(for: copy.id) == nil)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
        #expect(engine.occurrence(of: copy.id, dueAt: NewYork.local(2026, 10, 15))?.state == .skipped(reason: .paused))
    }

    @Test func cancelingAComingUpCopyPlansNothing() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        let copy = received()
        var engine = engine(for: copy)

        engine.cancel(copy.id)

        #expect(try #require(scheduler.lastPlan).items.isEmpty)
        #expect(engine.comingUp().isEmpty)
    }

    @Test func cancelingAWaitingCopyCancelsIt() throws {
        let copy = received(state: .waiting)
        var engine = engine(for: copy)

        engine.cancel(copy.id)

        #expect(engine.reminder(copy.id)?.isCanceled == true)
        #expect(engine.reminder(copy.id)?.isWaiting == false)
        #expect(engine.waitingForAcceptance().isEmpty)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    @Test func aCanceledCopyShowsAsCanceledOnTheRemindersListAndMyDay() throws {
        let copy = received()
        var engine = engine(for: copy)

        engine.cancel(copy.id)

        #expect(engine.remindersList().items.map(\.status) == [.canceled])
        let day = engine.myDay()
        #expect(!day.items.isEmpty)
        #expect(day.items.allSatisfy { $0.status == .canceled })
        #expect(day.items.allSatisfy { $0.countedIn == nil })
    }

    /// Today's 9:00 was Done before the cancel and yesterday's closed unanswered: the cancel rewrites neither.
    @Test func cancelingKeepsTheHistoryItHad() throws {
        clock.now = NewYork.local(2026, 10, 17, 9, 10)
        let copy = received()
        var engine = engine(for: copy)
        engine.markDone(copy.id)
        clock.now = NewYork.local(2026, 10, 17, 9, 20)
        let yesterday = engine.occurrence(of: copy.id, dueAt: NewYork.local(2026, 10, 16))?.state
        #expect(yesterday != nil && yesterday != .skipped(reason: .paused))

        engine.cancel(copy.id)

        #expect(engine.occurrence(of: copy.id, dueAt: NewYork.local(2026, 10, 17))?.state == .done)
        #expect(engine.occurrence(of: copy.id, dueAt: NewYork.local(2026, 10, 16))?.state == yesterday)
    }

    /// The open occurrence closes as Skipped only to stop it nudging: it wasn't paused, so Last 24
    /// Hours doesn't list it as "the reminder was paused" (phone check).
    @Test func aCanceledCopyHasNoRowInTheLast24Hours() {
        let canceled = received()
        let other = received(title: "Call Mum")
        var engine = engine(for: canceled, other)
        engine.cancel(canceled.id)

        #expect(engine.closedInLast24Hours().filter { $0.reminderID == canceled.id }.isEmpty)
    }

    @Test func aCanceledCopyCountsTowardNeitherBadge() throws {
        let other = received(title: "Call Mum")
        let copy = received()
        var engine = engine(for: copy, other)
        #expect(engine.badgeCount == 2)

        engine.cancel(copy.id)

        #expect(engine.badgeCount == 1)
        #expect(try #require(scheduler.lastPlan).currentBadgeCount == 1)
        #expect(engine.nudgingOccurrences().map(\.reminderID) == [other.id])
    }

    @Test func cancelingTwiceOrAReminderThatIsntACopyChangesNothing() throws {
        let copy = received()
        let own = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)
        var engine = engine(for: copy, own)
        engine.cancel(copy.id)
        let after = engine.reminders

        engine.cancel(copy.id)
        engine.cancel(own.id)
        engine.cancel(UUID())

        #expect(engine.reminders == after)
        #expect(engine.openOccurrence(for: own.id) != nil)
    }

    // MARK: A canceled copy stays canceled

    @Test func aLateRevisionOfACanceledCopyChangesNothing() {
        let copy = received()
        var engine = engine(for: copy)
        engine.cancel(copy.id)
        var revised = copy
        revised.title = "Take the blue pills"
        revised.origin = .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 4, state: .accepted)

        let changes = engine.applySendersRevision(revised)

        #expect(changes.isEmpty)
        #expect(engine.reminder(copy.id)?.title == "Take the pills")
        #expect(engine.reminder(copy.id)?.isCanceled == true)
    }

    @Test func acceptAndPauseIgnoreACanceledCopy() throws {
        let copy = received()
        var engine = engine(for: copy)
        engine.cancel(copy.id)

        engine.accept(copy.id)
        engine.pause(copy.id)

        #expect(engine.reminder(copy.id)?.isCanceled == true)
        #expect(!engine.isPaused(copy.id))
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    // MARK: Remove

    @Test func theRecipientRemovesACanceledCopyAsAnyOther() throws {
        let copy = received()
        var engine = engine(for: copy)
        engine.cancel(copy.id)

        engine.remove(copy.id)

        #expect(engine.reminders.isEmpty)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    // MARK: Disconnect

    @Test(arguments: [DisconnectChoice.remove, .keepAsMyOwnReminders])
    func aCanceledCopyGoesWhicheverIsChosenWithNothingPending(choice: DisconnectChoice) throws {
        let kept = received(title: "Call Mum")
        let canceled = received()
        var engine = engine(for: kept, canceled)
        engine.cancel(canceled.id)

        let removed = engine.disconnect(connectionID, choosing: choice)

        #expect(removed.contains(canceled.id))
        #expect(engine.reminder(canceled.id) == nil)
        #expect(try #require(scheduler.lastPlan).items.allSatisfy { $0.reminderID != canceled.id })
    }

    @Test func theCountKeepWouldKeepLeavesOutCanceledCopies() {
        var engine = engine(for: received(), received(), received(title: "Call Mum"))
        engine.cancel(engine.reminders[2].id)

        #expect(engine.keptOnDisconnect(from: connectionID) == 2)
    }
}
