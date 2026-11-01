import Foundation
import Testing
@testable import NudgeEngine

/// The Reminders tab's filter: the Nudging and Missed chips, which are its Status shown on screen
/// (spec #104, How search, chips and the sheet combine). One reminder in each status at 13:00 on
/// Friday 16 October 2026 in New York, from `RemindersListTests`.
struct RemindersFilterTests {
    let fixture = RemindersListTests()

    func titles(_ engine: Engine, _ chip: RemindersChip?, alwaysShowing new: Set<Reminder.ID> = []) -> [String] {
        var filter = RemindersFilter()
        if let chip { filter.toggle(chip) }
        return engine.remindersList(filteredBy: filter, alwaysShowing: new).items.map(\.reminder.title)
    }

    @Test func theNudgingChipShowsOnlyNudgingReminders() {
        #expect(titles(fixture.oneOfEach().engine, .nudging) == ["Reply to Alex"])
    }

    @Test func theMissedChipShowsOnlyRemindersWhoseStatusLabelIsMissed() {
        #expect(titles(fixture.oneOfEach().engine, .missed) == ["Book the car service"])
    }

    /// Decision 27: Due Today (#116) finds this one, since its status label says Coming up.
    @Test func aRepeatingReminderThatMissedTodayButComesDueAgainIsNotUnderMissed() {
        // Due yesterday at 9:00 and given up this morning, a day later; next week's is ahead.
        let walk = Reminder(title: "Long walk", dueTime: NewYork.local(2026, 10, 15, 9), repeatRule: .everyWeek, strength: .gentle)
        let clock = fixture.clock
        clock.now = NewYork.local(2026, 10, 15, 9)
        var engine = Engine(clock: clock, scheduler: fixture.scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [walk])

        clock.now = NewYork.local(2026, 10, 16, 13)

        #expect(engine.latestOccurrence(for: walk.id)?.state == .missed(reason: .giveUpLimit))
        #expect(engine.status(of: walk.id) == .comingUp)
        #expect(titles(engine, .missed) == [])
    }

    @Test func noFilterShowsEveryReminder() {
        #expect(titles(fixture.oneOfEach().engine, nil).count == 7)
    }

    @Test func theTotalStaysEveryReminderUnderAChip() {
        var filter = RemindersFilter()
        filter.toggle(.nudging)

        let shown = fixture.oneOfEach().engine.remindersList(filteredBy: filter)

        #expect(shown.items.count == 1)
        #expect(shown.total == 7)
    }

    @Test(arguments: [(RemindersChip.nudging, RemindersFilter.Status.nudging), (.missed, .missed)])
    func turningAChipOnSetsStatusToItAndTurningItOffClearsStatus(chip: RemindersChip, status: RemindersFilter.Status) {
        var filter = RemindersFilter()

        filter.toggle(chip)
        #expect(filter.chip == chip)
        #expect(filter.statuses == [status])

        filter.toggle(chip)
        #expect(filter.chip == nil)
        #expect(filter.statuses.isEmpty)
    }

    @Test func oneChipIsOnAtATime() {
        var filter = RemindersFilter()

        filter.toggle(.nudging)
        filter.toggle(.missed)

        #expect(filter.chip == .missed)
        #expect(filter.statuses == [.missed])
    }

    /// The sheet's side of the link is #113; this is the filter's.
    @Test(arguments: [
        Set<RemindersFilter.Status>(),
        [.comingUp],
        [.nudging, .missed],
        [.nudging, .paused],
    ])
    func aChipIsLitOnlyWhenStatusIsExactlyThatOneStatus(statuses: Set<RemindersFilter.Status>) {
        #expect(RemindersFilter(statuses: statuses).chip == nil)
    }

    @Test func aChipTappedWhileStatusHoldsMoreThanItSetsStatusToJustIt() {
        var filter = RemindersFilter(statuses: [.nudging, .paused])

        filter.toggle(.nudging)

        #expect(filter.statuses == [.nudging])
        #expect(filter.chip == .nudging)
    }

    @Test(arguments: [
        (RemindersFilter.Status.nudging, "Reply to Alex"),
        (.paused, "Stretch break"),
        (.done, "Morning meds"),
        (.missed, "Book the car service"),
        (.skipped, "Physio exercises"),
    ])
    func eachStatusFindsTheRemindersWithThatStatusLabel(status: RemindersFilter.Status, title: String) {
        let shown = fixture.oneOfEach().engine.remindersList(filteredBy: RemindersFilter(statuses: [status]))

        #expect(shown.items.map(\.reminder.title) == [title])
    }

    @Test func comingUpFindsEveryReminderWithADueTimeAhead() {
        let shown = fixture.oneOfEach().engine.remindersList(filteredBy: RemindersFilter(statuses: [.comingUp]))

        #expect(shown.items.map(\.reminder.title) == ["Dentist appointment", "Walk the dog"])
    }

    @Test func aNudgingReminderMarkedDoneLeavesUnderTheNudgingChipAndStaysWithoutIt() {
        var day = fixture.oneOfEach()

        day.engine.markDone(day.alex.id)

        #expect(titles(day.engine, .nudging) == [])
        #expect(titles(day.engine, nil).contains("Reply to Alex"))
    }

    /// Decision 20: a reminder just made shows until the chip next changes.
    @Test func aReminderBeingShownPassesWhateverTheFilterSays() {
        let day = fixture.oneOfEach()

        #expect(titles(day.engine, .nudging, alwaysShowing: [day.dentist.id]) == ["Reply to Alex", "Dentist appointment"])
    }
}
