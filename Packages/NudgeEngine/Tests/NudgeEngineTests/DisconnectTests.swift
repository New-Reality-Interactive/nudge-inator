import Foundation
import Testing
@testable import NudgeEngine

/// Ending a connection (spec #127, Disconnect): the reminders received through it are removed, or
/// kept as the person's own. Either way a copy still waiting to be accepted goes, and nothing from
/// another connection, nor any personal reminder, changes.
struct DisconnectTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 9, 10))
    let scheduler = FakeScheduler()
    let connectionID = UUID()
    let otherConnectionID = UUID()
    let tag = Tag.ID()

    /// Every day at 9:00 from Thursday 15 October 2026, received through `connection`.
    func received(through connection: UUID? = nil, state: ReminderOrigin.ReceivedState = .accepted, title: String = "Take the pills") -> Reminder {
        Reminder(
            title: title,
            notes: "With food",
            tagIDs: [tag],
            dueTime: NewYork.local(2026, 10, 15),
            repeatRule: .everyDay,
            strength: .relentless,
            origin: .received(connectionID: connection ?? connectionID, sendersReminderID: UUID(), revision: 2, state: state)
        )
    }

    func mine() -> Reminder {
        Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 8), repeatRule: .everyDay, strength: .firm)
    }

    func engine(for reminders: Reminder...) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    /// The reminder's planned nudges, without the Icon badge count each predicts, which counts every
    /// reminder and so falls when another goes.
    func plannedItems(of reminderID: Reminder.ID) throws -> [SchedulePlan.Item] {
        try #require(scheduler.lastPlan).items.filter { $0.reminderID == reminderID }.map { item in
            var item = item
            item.predictedBadgeCount = 0
            return item
        }
    }

    // MARK: Remove

    @Test func removeDeletesEveryReminderReceivedThroughTheConnectionAndCancelsItsNudges() throws {
        let nudging = received()
        let waiting = received(state: .waiting, title: "Call Mum")
        var engine = engine(for: nudging, waiting)
        #expect(try !plannedItems(of: nudging.id).isEmpty)

        let removed = engine.disconnect(connectionID, choosing: .remove)

        #expect(Set(removed) == [nudging.id, waiting.id])
        #expect(engine.reminders.isEmpty)
        #expect(engine.openOccurrence(for: nudging.id) == nil)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    // MARK: Keep as My Own Reminders

    @Test func keepTurnsAnAcceptedCopyIntoAPersonalReminderWithTheSameContentScheduleAndTags() throws {
        let copy = received()
        var engine = engine(for: copy)

        let removed = engine.disconnect(connectionID, choosing: .keepAsMyOwnReminders)

        #expect(removed.isEmpty)
        var kept = copy
        kept.origin = .mine
        #expect(engine.reminders == [kept])
    }

    /// Nothing re-plans: the nudges already pending, alarms included, keep their identifiers and
    /// fire as before.
    @Test func keepLeavesTheKeptRemindersPlannedNudgesAsTheyWere() throws {
        let copy = received()
        var engine = engine(for: copy)
        let before = try plannedItems(of: copy.id)
        #expect(!before.isEmpty)

        engine.disconnect(connectionID, choosing: .keepAsMyOwnReminders)

        #expect(try plannedItems(of: copy.id) == before)
    }

    @Test func keepKeepsTheHistory() throws {
        clock.now = NewYork.local(2026, 10, 16, 9, 10)
        let copy = received()
        var engine = engine(for: copy)
        engine.markDone(copy.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 20)

        engine.disconnect(connectionID, choosing: .keepAsMyOwnReminders)

        #expect(engine.occurrence(of: copy.id, dueAt: NewYork.local(2026, 10, 16))?.state == .done)
    }

    /// A waiting copy was never accepted, so Keep deletes it as Remove does (Brian's decision,
    /// 2026-11-10, on #197).
    @Test func keepDeletesACopyStillWaitingToBeAccepted() throws {
        let accepted = received()
        let waiting = received(state: .waiting, title: "Call Mum")
        var engine = engine(for: accepted, waiting)

        let removed = engine.disconnect(connectionID, choosing: .keepAsMyOwnReminders)

        #expect(removed == [waiting.id])
        #expect(engine.reminders.map(\.id) == [accepted.id])
    }

    /// What Disconnect's sheet counts: only what Keep would keep.
    @Test func theCountKeepWouldKeepLeavesOutWaitingCopiesAndOtherConnections() {
        let engine = engine(for: received(), received(), received(state: .waiting), received(through: otherConnectionID), mine())

        #expect(engine.keptOnDisconnect(from: connectionID) == 2)
        #expect(engine.keptOnDisconnect(from: UUID()) == 0)
    }

    // MARK: Untouched

    @Test(arguments: [DisconnectChoice.remove, .keepAsMyOwnReminders])
    func remindersFromAnotherConnectionAndPersonalOnesAreUntouched(choice: DisconnectChoice) throws {
        let fromOther = received(through: otherConnectionID)
        let own = mine()
        var engine = engine(for: received(), fromOther, own)
        let otherItems = try plannedItems(of: fromOther.id)
        let ownItems = try plannedItems(of: own.id)

        engine.disconnect(connectionID, choosing: choice)

        #expect(engine.reminder(fromOther.id) == fromOther)
        #expect(engine.reminder(own.id) == own)
        #expect(try plannedItems(of: fromOther.id) == otherItems)
        #expect(try plannedItems(of: own.id) == ownItems)
    }
}
