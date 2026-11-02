import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Reminders filter sheet as values, before any view draws them: what's applied, the draft, and
/// what the Filter button shows. On ticket 16's fixture, as `RemindersScreenTests` reads it: ten
/// reminders at 13:00 on Friday 16 October.
@MainActor
struct RemindersFilterSheetTests {
    let fixture = MyDayScreenTests()
    let home = Tag(name: "home")
    let money = Tag(name: "money")

    @Test func theBadgeCountsTheSectionsInUseNotTheChoices() {
        var filter = RemindersSheetFilter()
        #expect(filter.sectionsInUse == 0)
        #expect(!filter.isOn)

        filter.toggle(RemindersFilter.Status.done)
        filter.toggle(RemindersFilter.Status.missed)
        #expect(filter.sectionsInUse == 1)
        #expect(filter.isOn)

        filter.toggle(Strength.firm)
        #expect(filter.sectionsInUse == 2)

        filter.tags.toggle(home.id)
        filter.tags.toggle(money.id)
        #expect(filter.sectionsInUse == 3)
    }

    @Test func noTagsCountsAsTheTagsSection() {
        var filter = RemindersSheetFilter()

        filter.tags.toggleNoTags()

        #expect(filter.sectionsInUse == 1)
    }

    @Test func aChoiceTappedAgainComesOff() {
        var filter = RemindersSheetFilter()

        filter.toggle(Strength.firm)
        filter.toggle(RemindersFilter.Status.done)
        filter.toggle(Strength.firm)
        filter.toggle(RemindersFilter.Status.done)

        #expect(filter == RemindersSheetFilter())
    }

    @Test func theListIsNarrowedByEverySectionAndTheSearchItIsGiven() {
        var filter = RemindersSheetFilter()
        filter.tags.toggle(home.id)
        filter.toggle(RemindersFilter.Status.paused)
        filter.toggle(Strength.firm)

        #expect(filter.narrowing(search: " pill ") == RemindersFilter(
            tags: .matchAll([home.id]), statuses: [.paused], strengths: [.firm], search: "pill"
        ))
    }

    @Test func searchIsNotPartOfWhatTheSheetHoldsSoClearingLeavesIt() {
        var filter = RemindersSheetFilter()
        filter.toggle(Strength.firm)

        filter = RemindersSheetFilter()

        #expect(filter.narrowing(search: "pill") == RemindersFilter(search: "pill"))
    }

    @Test func aDeletedTagDropsOutOfTheFilterAndTheBadge() {
        var filter = RemindersSheetFilter()
        filter.tags.toggle(home.id)
        filter.tags.toggle(money.id)

        let kept = filter.keeping(tagsIn: [money.id])
        #expect(kept.narrowing(search: "").tags == .matchAll([money.id]))

        let none = filter.keeping(tagsIn: [])
        #expect(none.narrowing(search: "").tags == .off)
        #expect(none.sectionsInUse == 0)
    }

    private func sheet(
        _ day: MyDayScreenTests.Day,
        draft: RemindersSheetFilter,
        applied: RemindersSheetFilter = RemindersSheetFilter(),
        search: String = ""
    ) -> RemindersFilterSheet {
        RemindersFilterSheet(engine: day.model.engine, draft: draft, applied: applied, search: search)
    }

    @Test func aDraftMatchingWhatsAppliedHasNoChanges() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersSheetFilter()
        applied.toggle(Strength.firm)

        #expect(!sheet(day, draft: applied, applied: applied).hasChanges)
    }

    @Test func aChangedDraftHasChangesUntilItsChangedBack() async throws {
        let day = try await fixture.dayAtOnePM()
        var draft = RemindersSheetFilter()

        draft.toggle(RemindersFilter.Status.done)
        #expect(sheet(day, draft: draft).hasChanges)

        draft.toggle(RemindersFilter.Status.done)
        #expect(!sheet(day, draft: draft).hasChanges)
    }

    @Test func tagsCheckedInAnotherOrderAreNoChange() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersSheetFilter()
        applied.tags.toggle(day.home.id)
        applied.tags.toggle(day.work.id)
        var draft = applied

        draft.tags.toggle(day.home.id)
        draft.tags.toggle(day.home.id)

        #expect(!sheet(day, draft: draft, applied: applied).hasChanges)
    }

    @Test func aTagDeletedWhileChosenIsNoChange() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersSheetFilter()
        applied.tags.toggle(day.home.id)
        applied.tags.toggle(UUID())
        let draft = applied.keeping(tagsIn: [day.home.id])

        #expect(!sheet(day, draft: draft, applied: applied).hasChanges)
    }

    @Test func resetClearsTheDraftNotWhatsApplied() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersSheetFilter()
        applied.toggle(Strength.firm)
        var draft = applied
        #expect(sheet(day, draft: draft, applied: applied).canReset)

        draft = RemindersSheetFilter()

        let afterReset = sheet(day, draft: draft, applied: applied)
        #expect(!afterReset.canReset)
        #expect(afterReset.hasChanges)
        #expect(applied.sectionsInUse == 1)
    }

    @Test func theFooterCountsWhatApplyWouldShowWithTheSearchAsItIs() async throws {
        let day = try await fixture.dayAtOnePM()
        var draft = RemindersSheetFilter()
        #expect(String(localized: sheet(day, draft: draft).result) == "Apply shows 10 reminders.")

        draft.toggle(RemindersFilter.Status.nudging)
        #expect(String(localized: sheet(day, draft: draft).result) == "Apply shows 1 reminder.")

        #expect(String(localized: sheet(day, draft: draft, search: "zebra").result) == "Apply shows 0 reminders.")
    }

    @Test func theSheetChecksTheDraftsTags() async throws {
        let day = try await fixture.dayAtOnePM()
        var draft = RemindersSheetFilter()
        draft.tags.toggle(day.home.id)

        let rows = sheet(day, draft: draft).tags.rows

        #expect(rows.filter(\.isChecked).map(\.text) == ["#home"])
    }

    @Test func aNewReminderShowsOnlyIfItMatchesTheSheetsFilters() async throws {
        let day = try await fixture.dayAtOnePM()
        var filter = RemindersSheetFilter()
        filter.toggle(Strength.relentless)
        let narrowing = filter.narrowing(search: "")
        let before = RemindersScreen(engine: day.model.engine, filter: narrowing).rows.count

        day.model.add(Reminder(title: "Gentle one", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))
        #expect(RemindersScreen(engine: day.model.engine, filter: narrowing).rows.count == before)

        day.model.add(Reminder(title: "Hard one", dueTime: NewYork.local(2026, 10, 30), strength: .relentless))
        #expect(RemindersScreen(engine: day.model.engine, filter: narrowing).rows.last?.title == "Hard one")
    }
}
