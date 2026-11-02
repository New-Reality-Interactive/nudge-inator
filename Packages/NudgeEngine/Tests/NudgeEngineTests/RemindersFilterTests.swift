import Foundation
import Testing
@testable import NudgeEngine

/// The Reminders tab's filter: the sheet's Status, Strength and Tags, narrowing together with
/// search (spec #104, How search and the sheet combine). One reminder in each status at 13:00 on
/// Friday 16 October 2026 in New York, from `RemindersListTests`.
struct RemindersFilterTests {
    let fixture = RemindersListTests()

    func titles(_ engine: Engine, _ filter: RemindersFilter = RemindersFilter()) -> [String] {
        engine.remindersList(filteredBy: filter).items.map(\.reminder.title)
    }

    @Test func aStatusOfNudgingShowsOnlyNudgingReminders() {
        #expect(titles(fixture.oneOfEach().engine, RemindersFilter(statuses: [.nudging])) == ["Reply to Alex"])
    }

    @Test func aStatusOfMissedShowsOnlyRemindersWhoseStatusLabelIsMissed() {
        #expect(titles(fixture.oneOfEach().engine, RemindersFilter(statuses: [.missed])) == ["Book the car service"])
    }

    /// Decision 27: My Day shows today's miss, and its status label says Coming up.
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
        #expect(titles(engine, RemindersFilter(statuses: [.missed])) == [])
    }

    @Test func noFilterShowsEveryReminder() {
        #expect(titles(fixture.oneOfEach().engine).count == 7)
    }

    @Test func theTotalStaysEveryReminderUnderAFilter() {
        let shown = fixture.oneOfEach().engine.remindersList(filteredBy: RemindersFilter(statuses: [.nudging]))

        #expect(shown.items.count == 1)
        #expect(shown.total == 7)
    }

    @Test func severalStatusesMatchAnyChosen() {
        let shown = titles(fixture.oneOfEach().engine, RemindersFilter(statuses: [.nudging, .missed]))

        #expect(Set(shown) == ["Reply to Alex", "Book the car service"])
    }

    @Test func theSheetListsSixStatusesInTheMockupsOrder() {
        #expect(RemindersFilter.Status.allCases == [.nudging, .comingUp, .paused, .done, .missed, .skipped])
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

    @Test func aNudgingReminderMarkedDoneLeavesUnderAStatusOfNudgingAndStaysWithoutIt() {
        var day = fixture.oneOfEach()

        day.engine.markDone(day.alex.id)

        #expect(titles(day.engine, RemindersFilter(statuses: [.nudging])) == [])
        #expect(titles(day.engine).contains("Reply to Alex"))
    }

    private func engine(_ reminders: Reminder...) -> Engine {
        var engine = Engine(clock: fixture.clock, scheduler: fixture.scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    private func reminder(_ title: String, _ strength: Strength = .gentle, tags: [Tag] = [], notes: String = "") -> Reminder {
        var reminder = Reminder(title: title, dueTime: NewYork.local(2026, 10, 30, 9), strength: strength)
        reminder.tagIDs = tags.map(\.id)
        reminder.notes = notes
        return reminder
    }

    @Test func severalStrengthsMatchAnyChosen() {
        let engine = engine(reminder("Soft"), reminder("Middle", .firm), reminder("Hard", .relentless))

        #expect(titles(engine, RemindersFilter(strengths: [.relentless])) == ["Hard"])
        #expect(titles(engine, RemindersFilter(strengths: [.gentle, .relentless])) == ["Soft", "Hard"])
    }

    @Test func tagsMatchAllAnyOrNone() {
        let (home, money) = (Tag(name: "home"), Tag(name: "money"))
        var engine = engine(reminder("Both", tags: [home, money]), reminder("Home", tags: [home]), reminder("Neither"))
        engine.update(tags: [home, money])

        #expect(titles(engine, RemindersFilter(tags: .matchAll([home.id, money.id]))) == ["Both"])
        #expect(titles(engine, RemindersFilter(tags: .matchAny([home.id, money.id]))) == ["Both", "Home"])
        #expect(titles(engine, RemindersFilter(tags: .noTags)) == ["Neither"])
        #expect(titles(engine, RemindersFilter(tags: .off)) == ["Both", "Home", "Neither"])
    }

    @Test func searchAndEverySectionNarrowTogether() {
        let home = Tag(name: "home")
        var engine = engine(
            reminder("Pay rent", .firm, tags: [home]),
            reminder("Pay tax", .gentle, tags: [home]),
            reminder("Pay fine", .firm),
            reminder("Mow lawn", .firm, tags: [home])
        )
        engine.update(tags: [home])

        let filter = RemindersFilter(tags: .matchAll([home.id]), statuses: [.comingUp], strengths: [.firm], search: "pay")
        #expect(titles(engine, filter) == ["Pay rent"])
        var noneComingUp = filter
        noneComingUp.statuses = [.paused]
        #expect(titles(engine, noneComingUp) == [])
    }

    @Test func onlyTheSheetsSectionsCountAsItsFilters() {
        #expect(!RemindersFilter(search: "pay").hasSheetFilters)
        #expect(RemindersFilter(statuses: [.done]).hasSheetFilters)
        #expect(RemindersFilter(strengths: [.firm]).hasSheetFilters)
        #expect(RemindersFilter(tags: .noTags).hasSheetFilters)
    }
}
