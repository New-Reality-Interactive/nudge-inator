import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Reminders tab through `RemindersScreen`, read from the real app model on ticket 16's
/// fixture (13:00 on Friday 16 October). The fixture adds its reminders at one moment, so they tie
/// on creation date and keep the order they were added in, or the reverse under Newest First.
/// Layout and VoiceOver are screenshot and device checks.
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
        #expect((alex.time, alex.day, alex.tags.map(\.text)) == ("12:30\u{202F}PM", "Today", []))
        // Done this morning, so tomorrow's is next.
        let dog = try row(day.dog)
        #expect((dog.time, dog.day, dog.tags.map(\.text)) == ("7:00\u{202F}AM", "Tomorrow", ["#home"]))
        // Given up, so its latest occurrence's.
        let standUp = try row(day.standUp)
        #expect((standUp.time, standUp.day, standUp.tags.map(\.text)) == ("9:30\u{202F}AM", "Today", ["#work"]))
        let stretch = try row(day.stretch)
        #expect(stretch.tags.map(\.text) == ["#health", "#work"])
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

        // The fixture adds its reminders at one moment, so Newest First lists them last-added first.
        #expect(newest.rows.first?.title == "Dentist appointment")
        #expect(newest.rows.last?.title == "Take the bins out")
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

    /// Sort change, then Done, then the tab chosen again, as the tab keeps the order (ticket 325):
    /// the order is kept under the new sort, Done leaves the row where it was, and keeping again
    /// sorts afresh. The sort that was kept before the change is no longer what's shown.
    @Test func aSortChangeKeepsTheNewOrderDoneLeavesItAndChoosingTheTabAgainSortsAgain() async throws {
        let day = try await fixture.dayAtOnePM()
        fixture.clock.now = NewYork.local(2026, 10, 17, 6, 31)
        let byCreation = RemindersSort.createdOldestFirst
        let byDueDate = RemindersSort(field: .dueDate, order: .ascending)
        let keptByCreation = RemindersScreen(engine: day.model.engine, sort: byCreation).rows.map(\.id)
        let keptByDueDate = RemindersScreen(engine: day.model.engine, sort: byDueDate).rows.map(\.id)
        #expect(keptByCreation != keptByDueDate)

        day.model.markDone(day.meds.id)

        #expect(RemindersScreen(engine: day.model.engine, sort: byDueDate, keptOrder: keptByDueDate).rows.map(\.id) == keptByDueDate)
        let chosenAgain = RemindersScreen(engine: day.model.engine, sort: byDueDate).rows.map(\.id)
        #expect(chosenAgain != keptByDueDate)
        #expect(chosenAgain.last == day.meds.id)
    }

    /// Done and a new reminder together, with the order kept: the row keeps its place and the new
    /// one goes where the sort puts it, and a delete after that leaves the rest as they were.
    @Test func addingAndDeletingWhileAnOrderIsKeptLeavesTheOtherRowsWhereTheyWere() async throws {
        let day = try await fixture.dayAtOnePM()
        fixture.clock.now = NewYork.local(2026, 10, 17, 6, 31)
        let sort = RemindersSort(field: .dueDate, order: .ascending)
        let kept = RemindersScreen(engine: day.model.engine, sort: sort).rows.map(\.id)

        day.model.markDone(day.meds.id)
        let passport = Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)
        day.model.add(passport)
        day.model.delete(day.dentist.id)

        let rows = RemindersScreen(engine: day.model.engine, sort: sort, keptOrder: kept).rows.map(\.id)
        #expect(rows == [passport.id] + kept.filter { $0 != day.dentist.id })
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

    /// With no reminders there's no search field or Filter button, but a search or filter left over
    /// from before the last reminder went must still read as no reminders, not as no match.
    @Test func withNoRemindersASearchAndAFilterAreStillNoReminders() async throws {
        let model = try await fixture.launchedModel()

        let screen = RemindersScreen(
            engine: model.engine,
            filter: RemindersFilter(statuses: [.nudging], search: "zebra")
        )

        #expect(screen.emptyState == .noReminders)
    }

    /// A leftover search and filter would hide the first reminder added after the last went, and the
    /// empty one shows it. That the tab clears them when the last reminder goes is `RemindersTab`'s
    /// `onChange`, which no unit test reaches: the screenshot walk `testRemindersAfterTheLastDelete`
    /// checks it.
    @Test func aLeftOverFilterHidesTheFirstReminderAddedAfterTheLastWentAndAnEmptyOneShowsIt() async throws {
        let model = try await fixture.launchedModel()
        let leftOver = RemindersFilter(statuses: [.missed], search: "zebra")

        model.add(Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))

        let hidden = RemindersScreen(engine: model.engine, filter: leftOver)
        #expect(hidden.emptyState == .noMatch)
        let shown = RemindersScreen(engine: model.engine, filter: RemindersFilter())
        #expect(shown.rows.map(\.title) == ["Renew the passport"])
        #expect(shown.emptyState == nil)
    }

    @Test func theCountEqualsTheRowsShownUnderAStatus() async throws {
        let day = try await fixture.dayAtOnePM()

        let nudging = RemindersScreen(engine: day.model.engine, filter: RemindersFilter(statuses: [.nudging]))
        let missed = RemindersScreen(engine: day.model.engine, filter: RemindersFilter(statuses: [.missed]))

        #expect(nudging.rows.map(\.title) == ["Reply to Alex"])
        #expect(String(localized: nudging.countText) == "1 reminder out of 10")
        #expect(missed.rows.map(\.title) == ["Team stand-up"])
        #expect(String(localized: missed.countText) == "1 reminder out of 10")
    }

    /// Spec #104, Edge cases: the row leaves, the count reads 0 and the no-match empty state
    /// appears, never the one that says there are no reminders. The Status staying on is the filter's.
    @Test func theLastNudgingReminderMarkedDoneUnderAStatusLeavesTheNoMatchEmptyState() async throws {
        let day = try await fixture.dayAtOnePM()
        let nudging = RemindersFilter(statuses: [.nudging])
        #expect(RemindersScreen(engine: day.model.engine, filter: nudging).emptyState == nil)

        day.model.markDone(day.alex.id)

        let screen = RemindersScreen(engine: day.model.engine, filter: nudging)
        #expect(screen.rows.isEmpty)
        #expect(String(localized: screen.countText) == "0 reminders out of 10")
        #expect(screen.emptyState == .noMatch)
    }

    @Test func aRowTheStatusNowExcludesDropsOutOfAKeptOrder() async throws {
        let day = try await fixture.dayAtOnePM()
        let nudging = RemindersFilter(statuses: [.nudging])
        let kept = RemindersScreen(engine: day.model.engine, filter: nudging).rows.map(\.id)

        day.model.markDone(day.alex.id)

        #expect(RemindersScreen(engine: day.model.engine, filter: nudging, keptOrder: kept).rows.isEmpty)
    }

    /// Spec #104, Decision 20: a reminder shows only if it passes what's narrowing the list, even
    /// one just made on this tab.
    @Test func aNewReminderTheStatusWouldHideDoesntShow() async throws {
        let day = try await fixture.dayAtOnePM()

        day.model.add(Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))

        let shown = RemindersScreen(engine: day.model.engine, filter: RemindersFilter(statuses: [.nudging]))
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

    @Test func theFiltersTagsAreBoldOnARow() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine, filter: RemindersFilter(tags: .matchAny([day.health.id])))

        let stretch = try #require(screen.rows.first { $0.id == day.stretch.id })
        #expect(stretch.tags.map(\.isChosen) == [true, false])
    }

    /// Whole strings for each case, never built from pieces (CODING_STANDARDS.md). The mock's
    /// `noMatch()` draws the same three.
    @Test func theNoMatchWordingFollowsTheSearchAndTheSheet() {
        let sheet = RemindersFilter(statuses: [.nudging, .paused])
        let search = RemindersFilter(search: "zebra")
        let both = RemindersFilter(strengths: [.firm], search: "zebra")

        #expect(String(localized: sheet.noMatchTitle) == "No Matches")
        #expect(sheet.noMatchText.map { String(localized: $0) } == "No reminders with these filters.")
        #expect(String(localized: sheet.noMatchClearTitle) == "Clear Filters")

        #expect(String(localized: search.noMatchTitle) == "No Results for “zebra”")
        #expect(search.noMatchText.map { String(localized: $0) } == "Check the spelling or try a new search.")
        #expect(String(localized: search.noMatchClearTitle) == "Clear Search")

        #expect(String(localized: both.noMatchTitle) == "No Results for “zebra”")
        #expect(both.noMatchText.map { String(localized: $0) } == "No reminders with these filters match this search.")
        #expect(String(localized: both.noMatchClearTitle) == "Clear Search and Filters")
    }

    @Test func theNoMatchTitleQuotesTheSearchTrimmed() {
        #expect(String(localized: RemindersFilter(search: "  zebra ").noMatchTitle) == "No Results for “zebra”")
    }

    // MARK: - Live refresh: what the list shows as time passes, and after a change made elsewhere

    // The tab re-reads the engine at the start of every minute (`TimelineView(.everyMinute)`) and
    // the engine reads the clock, so a screen read at each moment stands for that minute's redraw.
    // That the view re-reads is a screenshot and device check.

    /// A new `Engine` over the fake clock, in New York.
    func engine(holding reminders: [Reminder], giveUpLimit: GiveUpLimit = .shipped) -> Engine {
        var engine = Engine(clock: fixture.clock, scheduler: FakeScheduler(), giveUpLimit: giveUpLimit, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    /// Spec #104, Live refresh: a Nudging reminder whose next occurrence takes over updates its row
    /// within a minute. With the shipped limit a daily repeat gives up long before its next
    /// occurrence, so the give-up limit is widened, as `RepeatTakeOverTests` does. The row after the
    /// take-over is the new occurrence's: its due time is the day's, no longer yesterday's.
    @Test func theRowAfterATakeOverShowsTheNewOccurrencesDueTime() {
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .relentless)
        let engine = engine(holding: [pills], giveUpLimit: GiveUpLimit(nudgeCount: 10_000, span: 72 * 60 * 60))

        fixture.clock.now = NewYork.local(2026, 10, 16, 8, 59, 30)
        let before = RemindersScreen(engine: engine).rows.first
        fixture.clock.now = NewYork.local(2026, 10, 16, 9, 0, 30)
        let after = RemindersScreen(engine: engine).rows.first

        #expect((before?.status, before?.day) == (.nudging, "Yesterday"))
        #expect((after?.status, after?.day) == (.nudging, "Today"))
    }

    /// Spec #104, Live refresh: within a minute of midnight the rows and the count follow. A paused
    /// every-day-at-00:00 reminder's next due time is always the coming midnight, so it leaves
    /// Saturday's range at 00:00 and enters Sunday's; a one-off due Saturday morning goes from
    /// "Tomorrow" to "Today". Nothing in the engine changes at midnight: only the clock moves.
    @Test func theRowsTheCountAndTheEmptyStateFollowTheClockOverMidnight() {
        let walk = Reminder(title: "Midnight walk", dueTime: NewYork.local(2026, 10, 1, 0), repeatRule: .everyDay, strength: .gentle)
        let call = Reminder(title: "Early call", dueTime: NewYork.local(2026, 10, 17, 8), strength: .gentle)
        fixture.clock.now = NewYork.local(2026, 10, 16, 23)
        var engine = engine(holding: [walk, call])
        engine.pause(walk.id)
        let saturday = RemindersFilter(dueFrom: CalendarDay(year: 2026, month: 10, day: 17), dueTo: CalendarDay(year: 2026, month: 10, day: 17))
        let sunday = RemindersFilter(dueFrom: CalendarDay(year: 2026, month: 10, day: 18), dueTo: CalendarDay(year: 2026, month: 10, day: 18))

        fixture.clock.now = NewYork.local(2026, 10, 16, 23, 59)
        let saturdayBefore = RemindersScreen(engine: engine, filter: saturday)
        let sundayBefore = RemindersScreen(engine: engine, filter: sunday)
        fixture.clock.now = NewYork.local(2026, 10, 17, 0, 1)
        let saturdayAfter = RemindersScreen(engine: engine, filter: saturday)
        let sundayAfter = RemindersScreen(engine: engine, filter: sunday)

        #expect(saturdayBefore.rows.map(\.title) == ["Midnight walk", "Early call"])
        #expect(String(localized: saturdayBefore.countText) == "2 reminders out of 2")
        #expect(saturdayBefore.rows.map(\.day) == ["Tomorrow", "Tomorrow"])
        #expect(sundayBefore.rows.isEmpty)
        #expect(sundayBefore.emptyState == .noMatch)

        #expect(saturdayAfter.rows.map(\.title) == ["Early call"])
        #expect(String(localized: saturdayAfter.countText) == "1 reminder out of 2")
        #expect(saturdayAfter.rows.map(\.day) == ["Today"])
        #expect(sundayAfter.rows.map(\.title) == ["Midnight walk"])
        #expect(sundayAfter.emptyState == nil)
    }

    /// Spec #104, Decision 60: a reminder with no occurrence and nothing coming shows its Start and
    /// Coming up. The engine reaches it only from the store: an Edit's `editAppliesAfter` with no
    /// closing recorded (`RemindersListTests`).
    @Test func aReminderWithNoOccurrenceAndNothingComingShowsComingUpAndItsStart() throws {
        let start = NewYork.local(2026, 10, 14, 9)
        let reminder = Reminder(title: "Book the car service", dueTime: start, strength: .gentle)
        var engine = Engine(clock: fixture.clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone)
        engine.update(histories: [reminder.id: ReminderHistory(editAppliesAfter: start)])
        engine.update(reminders: [reminder])

        let screen = RemindersScreen(engine: engine)

        let row = try #require(screen.rows.first)
        #expect(row.status == .comingUp)
        #expect(row.time == "9:00\u{202F}AM")
        #expect(row.day == "Wed, Oct 14")
        #expect(row.offersDone == false)
        #expect(screen.emptyState == nil)
    }

    // MARK: - A change made elsewhere shows when the person returns to the list

    /// The tab holds no copy of the list: it reads the engine again, so a change made on another
    /// screen (details, an alarm's Open, a notification's Done) shows on return. That the view
    /// re-reads on return (`onChange(of: state)`, `TimelineView`) is a screenshot check.
    @Test func aDoneFromAnAlarmsOpenShowsOnReturningToTheList() async throws {
        let day = try await fixture.dayAtOnePM()
        let before = RemindersScreen(engine: day.model.engine).rows

        await day.model.open(alarmID: UUID(), reminderID: day.alex.id)
        #expect(day.model.takeRoute() == .reminderDetails(day.alex.id))
        day.model.markDone(day.alex.id)
        await day.model.waitUntilApplied()

        let after = RemindersScreen(engine: day.model.engine).rows
        #expect(after.map(\.id) == before.map(\.id))
        #expect(after.first { $0.id == day.alex.id }?.status == .closed(.done))
        #expect(after.first { $0.id == day.alex.id }?.offersDone == false)
    }

    @Test func aDoneFromANotificationShowsOnReturningToTheList() async throws {
        let day = try await fixture.dayAtOnePM()

        await day.model.markDone(DeliveredNudge(reminderID: day.alex.id, dueTime: NewYork.local(2026, 10, 16, 12, 30), fireTime: NewYork.local(2026, 10, 16, 13)))

        let alex = RemindersScreen(engine: day.model.engine).rows.first { $0.id == day.alex.id }
        #expect(alex?.status == .closed(.done))
    }

    @Test func anEditShowsOnReturningToTheListWithTheRowWhereItWas() async throws {
        let day = try await fixture.dayAtOnePM()
        let before = RemindersScreen(engine: day.model.engine).rows.map(\.id)
        var edited = day.bins
        edited.title = "Take the recycling out"
        edited.dueTime = NewYork.local(2026, 10, 16, 21)

        try day.model.edit(edited)
        await day.model.waitUntilApplied()

        let after = RemindersScreen(engine: day.model.engine).rows
        #expect(after.map(\.id) == before)
        let bins = try #require(after.first { $0.id == day.bins.id })
        #expect((bins.title, bins.time) == ("Take the recycling out", "9:00\u{202F}PM"))
    }

    @Test func aPauseShowsOnReturningToTheList() async throws {
        let day = try await fixture.dayAtOnePM()
        let before = RemindersScreen(engine: day.model.engine).rows.map(\.id)

        day.model.pause(day.plants.id)
        await day.model.waitUntilApplied()

        let after = RemindersScreen(engine: day.model.engine).rows
        #expect(after.map(\.id) == before)
        #expect(after.first { $0.id == day.plants.id }?.status == .paused)
    }
}
