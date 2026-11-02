import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Reminders tab through `RemindersScreen`, read from the real app model on ticket 16's
/// fixture (13:00 on Friday 16 October). The fixture adds its reminders at one moment, so they tie
/// on creation date and keep the order they were added in. Layout and VoiceOver are screenshot and
/// device checks.
@MainActor
struct RemindersScreenTests {
    let fixture = MyDayScreenTests()

    @Test func everyReminderIsARowInTheOrderTheyWereAddedWithItsStatus() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine)

        #expect(screen.rows.map(\.title) == [
            "Take the bins out", "Water the plants", "Call Grandma", "Send the status update", "Reply to Alex",
            "Stretch break", "Team stand-up", "Walk the dog", "Morning meds", "Dentist appointment",
        ])
        #expect(screen.rows.map(\.status) == [
            .comingUp, .comingUp, .paused, .comingUp, .nudging,
            .paused, .closed(.missed(reason: .giveUpLimit)), .comingUp, .comingUp, .comingUp,
        ])
        #expect(screen.emptyState == nil)
    }

    @Test func aRowShowsItsDueTimeAndDayAndItsTags() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine)
        func row(_ reminder: Reminder) throws -> RemindersScreen.Row {
            try #require(screen.rows.first { $0.id == reminder.id })
        }

        let alex = try row(day.alex)
        #expect((alex.time, alex.day, alex.tags) == ("12:30\u{202F}PM", "Today", []))
        // Done this morning, so tomorrow's is next.
        let dog = try row(day.dog)
        #expect((dog.time, dog.day, dog.tags) == ("7:00\u{202F}AM", "Tomorrow", ["#home"]))
        // Given up, so its latest occurrence's.
        let standUp = try row(day.standUp)
        #expect((standUp.time, standUp.day, standUp.tags) == ("9:30\u{202F}AM", "Today", ["#work"]))
        let stretch = try row(day.stretch)
        #expect(stretch.tags == ["#health", "#work"])
    }

    /// The trailing swipe's Done, and the row's Done VoiceOver action. Every row offers Delete.
    @Test func onlyANudgingRowOffersDone() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine)

        #expect(screen.rows.filter(\.offersDone).map(\.title) == ["Reply to Alex"])
    }

    @Test func doneChangesARowsStatusInPlace() async throws {
        let day = try await fixture.dayAtOnePM()
        let before = RemindersScreen(engine: day.model.engine).rows.map(\.id)

        day.model.markDone(day.alex.id)

        let after = RemindersScreen(engine: day.model.engine)
        #expect(after.rows.map(\.id) == before)
        #expect(after.rows.first { $0.id == day.alex.id }?.status == .closed(.done))
    }

    /// A Nudging row's Done is `AppModel.markDone(_:)`, as on Now, My Day and the details page.
    @Test func aNudgingRowsDoneCancelsItsNudgesAndLowersBothBadgesByOne() async throws {
        let day = try await fixture.dayAtOnePM()
        let center = fixture.center
        #expect(NowScreen.badgeCount(of: day.model.engine) == 1)
        #expect(center.badgeCounts.last == 1)
        #expect(center.pending.contains { $0.identifier.contains(day.alex.id.uuidString) })

        day.model.markDone(day.alex.id)
        await day.model.waitUntilApplied()

        #expect(NowScreen.badgeCount(of: day.model.engine) == 0)
        #expect(center.badgeCounts.last == 0)
        #expect(!center.pending.contains { $0.identifier.contains(day.alex.id.uuidString) })
    }

    /// A row's Delete, once confirmed, is `AppModel.delete(_:)`, as on the details page. Reply to
    /// Alex is Firm and Nudging, so it has alarms; the only ones before 8 PM today.
    @Test func deletingANudgingRowRemovesItAndCancelsItsNudgesAndAlarms() async throws {
        let day = try await fixture.dayAtOnePM()
        let center = fixture.center, manager = fixture.manager
        let beforeEight = NewYork.local(2026, 10, 16, 20)
        let before = RemindersScreen(engine: day.model.engine).rows.map(\.title)
        #expect(manager.scheduled.contains { $0.fireDate.map { $0 < beforeEight } ?? false })

        day.model.delete(day.alex.id)
        await day.model.waitUntilApplied()

        let after = RemindersScreen(engine: day.model.engine).rows.map(\.title)
        #expect(after.count == before.count - 1)
        #expect(after == before.filter { $0 != "Reply to Alex" })
        #expect(!center.pending.contains { $0.identifier.contains(day.alex.id.uuidString) })
        #expect(!manager.scheduled.contains { $0.fireDate.map { $0 < beforeEight } ?? false })
        #expect(NowScreen.badgeCount(of: day.model.engine) == 0)
    }

    @Test func aNewReminderShowsLastAsTheNewestCreated() async throws {
        let day = try await fixture.dayAtOnePM()

        day.model.add(Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))

        #expect(RemindersScreen(engine: day.model.engine).rows.last?.title == "Renew the passport")
    }

    @Test func theRowsFollowTheSort() async throws {
        let day = try await fixture.dayAtOnePM()

        let newest = RemindersScreen(engine: day.model.engine, sort: RemindersSort(field: .created, order: .descending))
        let earliest = RemindersScreen(engine: day.model.engine, sort: RemindersSort(field: .dueDate, order: .ascending))

        // The fixture adds its reminders at one moment, so Newest First keeps the order added.
        #expect(newest.rows.first?.title == "Take the bins out")
        // Given up at 9:30 today, the earliest due time a row shows.
        #expect(earliest.rows.first?.title == "Team stand-up")
        #expect(earliest.rows.last?.title == "Dentist appointment")
    }

    /// The header row's count: the rows shown out of every reminder, even with nothing narrowing
    /// the list, in one string with plural variants.
    @Test func theCountIsTheRowsShownOutOfEveryReminder() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine)

        #expect(screen.shownCount == screen.rows.count)
        #expect(screen.total == day.model.engine.reminders.count)
        #expect(String(localized: screen.countText) == "10 reminders out of 10")
        #expect(String(localized: RemindersScreen.countText(shown: 1, of: 14)) == "1 reminder out of 14")
    }

    @Test func deletingARowLowersTheCountByOne() async throws {
        let day = try await fixture.dayAtOnePM()

        day.model.delete(day.alex.id)

        #expect(String(localized: RemindersScreen(engine: day.model.engine).countText) == "9 reminders out of 9")
    }

    /// At 6:31 the next morning Morning meds is Nudging, due 6:30 today. Done moves its due time to
    /// tomorrow, which sorts it last, but the row keeps its place until the list's inputs change.
    @Test func sortedByDueDateARowKeepsItsPlaceAfterDoneUntilTheListSortsAgain() async throws {
        let day = try await fixture.dayAtOnePM()
        fixture.clock.now = NewYork.local(2026, 10, 17, 6, 31)
        let sort = RemindersSort(field: .dueDate, order: .ascending)
        let kept = RemindersScreen(engine: day.model.engine, sort: sort).rows.map(\.id)
        #expect(RemindersScreen(engine: day.model.engine, sort: sort).rows.first { $0.id == day.meds.id }?.status == .nudging)

        day.model.markDone(day.meds.id)

        let keptScreen = RemindersScreen(engine: day.model.engine, sort: sort, keptOrder: kept)
        #expect(keptScreen.rows.map(\.id) == kept)
        #expect(keptScreen.rows.first { $0.id == day.meds.id }?.day == "Tomorrow")
        let sortedAgain = RemindersScreen(engine: day.model.engine, sort: sort)
        #expect(sortedAgain.rows.last?.id == day.meds.id)
    }

    /// A reminder added since the order was kept goes where the sort puts it; a deleted one leaves.
    @Test func aKeptOrderTakesANewReminderWhereTheSortPutsItAndDropsADeletedOne() async throws {
        let day = try await fixture.dayAtOnePM()
        let sort = RemindersSort(field: .dueDate, order: .ascending)
        let kept = RemindersScreen(engine: day.model.engine, sort: sort).rows.map(\.id)

        day.model.delete(day.dentist.id)
        let passport = Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)
        day.model.add(passport)

        let screen = RemindersScreen(engine: day.model.engine, sort: sort, keptOrder: kept)
        #expect(screen.rows.map(\.id) == [passport.id] + kept.filter { $0 != day.dentist.id })
    }

    @Test func withNoRemindersTheEmptyStateSaysThereAreNoneYet() async throws {
        let model = try await fixture.launchedModel()

        let screen = RemindersScreen(engine: model.engine)

        #expect(screen.rows.isEmpty)
        #expect(screen.emptyState == .noReminders)
    }

    private func filter(_ chip: RemindersChip) -> RemindersFilter {
        var filter = RemindersFilter()
        filter.toggle(chip)
        return filter
    }

    @Test func theCountEqualsTheRowsShownWithAChipOn() async throws {
        let day = try await fixture.dayAtOnePM()

        let nudging = RemindersScreen(engine: day.model.engine, filter: filter(.nudging))
        let missed = RemindersScreen(engine: day.model.engine, filter: filter(.missed))

        #expect(nudging.rows.map(\.title) == ["Reply to Alex"])
        #expect(String(localized: nudging.countText) == "1 reminder out of 10")
        #expect(missed.rows.map(\.title) == ["Team stand-up"])
        #expect(String(localized: missed.countText) == "1 reminder out of 10")
    }

    /// Spec #104, Edge cases: the row leaves, the count reads 0 and the no-match empty state
    /// appears, never the one that says there are no reminders. The chip staying on is the filter's.
    @Test func theLastNudgingReminderMarkedDoneUnderTheChipLeavesTheNoMatchEmptyState() async throws {
        let day = try await fixture.dayAtOnePM()
        let nudging = filter(.nudging)
        #expect(RemindersScreen(engine: day.model.engine, filter: nudging).emptyState == nil)

        day.model.markDone(day.alex.id)

        let screen = RemindersScreen(engine: day.model.engine, filter: nudging)
        #expect(screen.rows.isEmpty)
        #expect(String(localized: screen.countText) == "0 reminders out of 10")
        #expect(screen.emptyState == .noMatch)
    }

    @Test func aRowTheChipNowExcludesDropsOutOfAKeptOrder() async throws {
        let day = try await fixture.dayAtOnePM()
        let nudging = filter(.nudging)
        let kept = RemindersScreen(engine: day.model.engine, filter: nudging).rows.map(\.id)

        day.model.markDone(day.alex.id)

        #expect(RemindersScreen(engine: day.model.engine, filter: nudging, keptOrder: kept).rows.isEmpty)
    }

    /// Spec #104, Decision 20: a reminder shows only if it passes what's narrowing the list, even
    /// one just made on this tab.
    @Test func aNewReminderTheChipWouldHideDoesntShow() async throws {
        let day = try await fixture.dayAtOnePM()

        day.model.add(Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))

        let shown = RemindersScreen(engine: day.model.engine, filter: filter(.nudging))
        #expect(shown.rows.map(\.title) == ["Reply to Alex"])
        #expect(String(localized: shown.countText) == "1 reminder out of 11")
    }

    @Test func theCountEqualsTheRowsShownUnderASearch() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine, filter: RemindersFilter(search: "alex"))

        #expect(screen.rows.map(\.title) == ["Reply to Alex"])
        #expect(String(localized: screen.countText) == "1 reminder out of 10")
        #expect(screen.emptyState == nil)
    }

    @Test func aSearchThatFindsNothingLeavesTheNoMatchEmptyState() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine, filter: RemindersFilter(search: "zebra"))

        #expect(screen.rows.isEmpty)
        #expect(String(localized: screen.countText) == "0 reminders out of 10")
        #expect(screen.emptyState == .noMatch)
    }

    @Test func aNewReminderTheSearchWouldHideDoesntShow() async throws {
        let day = try await fixture.dayAtOnePM()

        day.model.add(Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))

        let shown = RemindersScreen(engine: day.model.engine, filter: RemindersFilter(search: "alex"))
        #expect(shown.rows.map(\.title) == ["Reply to Alex"])
        #expect(String(localized: shown.countText) == "1 reminder out of 11")
    }

    @Test func aNewReminderThatMatchesTheSearchShows() async throws {
        let day = try await fixture.dayAtOnePM()

        day.model.add(Reminder(title: "Call Alex back", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))

        let shown = RemindersScreen(engine: day.model.engine, filter: RemindersFilter(search: "alex"))
        #expect(shown.rows.map(\.title) == ["Reply to Alex", "Call Alex back"])
    }

    /// Whole strings for each case, never built from pieces (CODING_STANDARDS.md). The mockup's
    /// `noMatch()` draws the same three.
    @Test func theNoMatchWordingFollowsTheSearchAndTheChip() {
        let chip = filter(.nudging)
        let search = RemindersFilter(search: "zebra")
        let both = RemindersFilter(statuses: [.missed], search: "zebra")

        #expect(String(localized: chip.noMatchTitle) == "No Matches")
        #expect(chip.noMatchText.map { String(localized: $0) } == "No Nudging reminders.")
        #expect(String(localized: chip.noMatchClearTitle) == "Clear Filters")

        #expect(String(localized: search.noMatchTitle) == "No Results for “zebra”")
        #expect(search.noMatchText.map { String(localized: $0) } == "Check the spelling or try a new search.")
        #expect(String(localized: search.noMatchClearTitle) == "Clear Search")

        #expect(String(localized: both.noMatchTitle) == "No Results for “zebra”")
        #expect(both.noMatchText.map { String(localized: $0) } == "No Missed reminders match this search.")
        #expect(String(localized: both.noMatchClearTitle) == "Clear Search and Filters")
    }

    @Test func theNoMatchTitleQuotesTheSearchTrimmed() {
        #expect(String(localized: RemindersFilter(search: "  zebra ").noMatchTitle) == "No Results for “zebra”")
    }
}
