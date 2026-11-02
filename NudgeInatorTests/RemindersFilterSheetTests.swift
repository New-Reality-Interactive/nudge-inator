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
        var filter = RemindersFilterChoices()
        #expect(filter.sectionsInUse == 0)

        filter.toggle(RemindersFilter.Status.done)
        filter.toggle(RemindersFilter.Status.missed)
        #expect(filter.sectionsInUse == 1)

        filter.toggle(Strength.firm)
        #expect(filter.sectionsInUse == 2)

        filter.tags.toggle(home.id)
        filter.tags.toggle(money.id)
        #expect(filter.sectionsInUse == 3)
    }

    @Test func noTagsCountsAsTheTagsSection() {
        var filter = RemindersFilterChoices()

        filter.tags.toggleNoTags()

        #expect(filter.sectionsInUse == 1)
    }

    @Test func aChoiceTappedAgainComesOff() {
        var filter = RemindersFilterChoices()

        filter.toggle(Strength.firm)
        filter.toggle(RemindersFilter.Status.done)
        filter.toggle(Strength.firm)
        filter.toggle(RemindersFilter.Status.done)

        #expect(filter == RemindersFilterChoices())
    }

    @Test func theListIsNarrowedByEverySectionAndTheSearchItIsGiven() {
        var filter = RemindersFilterChoices()
        filter.tags.toggle(home.id)
        filter.toggle(RemindersFilter.Status.paused)
        filter.toggle(Strength.firm)

        #expect(filter.narrowing(search: " pill ") == RemindersFilter(
            tags: .matchAll([home.id]), statuses: [.paused], strengths: [.firm], search: "pill"
        ))
    }

    @Test func aDeletedTagDropsOutOfTheFilterAndTheBadge() {
        var filter = RemindersFilterChoices()
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
        draft: RemindersFilterChoices,
        applied: RemindersFilterChoices = RemindersFilterChoices(),
        search: String = ""
    ) -> RemindersFilterSheet {
        RemindersFilterSheet(engine: day.model.engine, draft: draft, applied: applied, search: search)
    }

    @Test func aDraftMatchingWhatsAppliedHasNoChanges() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersFilterChoices()
        applied.toggle(Strength.firm)

        #expect(!sheet(day, draft: applied, applied: applied).hasChanges)
    }

    @Test func aChangedDraftHasChangesUntilItsChangedBack() async throws {
        let day = try await fixture.dayAtOnePM()
        var draft = RemindersFilterChoices()

        draft.toggle(RemindersFilter.Status.done)
        #expect(sheet(day, draft: draft).hasChanges)

        draft.toggle(RemindersFilter.Status.done)
        #expect(!sheet(day, draft: draft).hasChanges)
    }

    @Test func tagsCheckedInAnotherOrderAreNoChange() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersFilterChoices()
        applied.tags.toggle(day.home.id)
        applied.tags.toggle(day.work.id)
        var draft = applied

        draft.tags.toggle(day.home.id)
        draft.tags.toggle(day.home.id)

        #expect(!sheet(day, draft: draft, applied: applied).hasChanges)
    }

    @Test func aTagDeletedWhileChosenIsNoChange() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersFilterChoices()
        applied.tags.toggle(day.home.id)
        applied.tags.toggle(UUID())
        let draft = applied.keeping(tagsIn: [day.home.id])

        #expect(!sheet(day, draft: draft, applied: applied).hasChanges)
    }

    /// Reset gives the draft an empty value, in the view; Apply passes the draft on. The screenshot
    /// walk taps both. What this seam holds is what the sheet says about the result.
    @Test func anEmptyDraftHasNothingToResetAndDiffersFromWhatsApplied() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersFilterChoices()
        applied.toggle(Strength.firm)
        #expect(sheet(day, draft: applied, applied: applied).canReset)

        let afterReset = sheet(day, draft: RemindersFilterChoices(), applied: applied)

        #expect(!afterReset.canReset)
        #expect(afterReset.hasChanges)
    }

    @Test func aLeftoverMatchAnyIsSomethingToReset() async throws {
        let day = try await fixture.dayAtOnePM()
        var draft = RemindersFilterChoices()
        draft.tags.match = .any

        #expect(sheet(day, draft: draft).canReset)
    }

    @Test func aMatchChoiceLeftOnOneTagIsNoChange() async throws {
        let day = try await fixture.dayAtOnePM()
        var applied = RemindersFilterChoices()
        applied.tags.toggle(day.home.id)
        var draft = applied

        draft.tags.toggle(day.work.id)
        draft.tags.match = .any
        draft.tags.toggle(day.work.id)

        #expect(!sheet(day, draft: draft, applied: applied).hasChanges)
    }

    @Test func theFooterCountsWhatApplyWouldShowWithTheSearchAsItIs() async throws {
        let day = try await fixture.dayAtOnePM()
        var draft = RemindersFilterChoices()
        #expect(String(localized: sheet(day, draft: draft).result) == "Apply shows 10 reminders.")

        draft.toggle(RemindersFilter.Status.nudging)
        #expect(String(localized: sheet(day, draft: draft).result) == "Apply shows 1 reminder.")

        #expect(String(localized: sheet(day, draft: draft, search: "zebra").result) == "Apply shows 0 reminders.")
    }

    @Test func theSheetChecksTheDraftsTags() async throws {
        let day = try await fixture.dayAtOnePM()
        var draft = RemindersFilterChoices()
        draft.tags.toggle(day.home.id)

        let rows = sheet(day, draft: draft).tags.tags

        #expect(rows.filter(\.isChecked).map(\.text) == ["#home"])
    }

    @Test func aNewReminderShowsOnlyIfItMatchesTheSheetsFilters() async throws {
        let day = try await fixture.dayAtOnePM()
        var filter = RemindersFilterChoices()
        filter.toggle(Strength.relentless)
        let narrowing = filter.narrowing(search: "")
        let before = RemindersScreen(engine: day.model.engine, filter: narrowing).rows.count

        day.model.add(Reminder(title: "Gentle one", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))
        #expect(RemindersScreen(engine: day.model.engine, filter: narrowing).rows.count == before)

        day.model.add(Reminder(title: "Hard one", dueTime: NewYork.local(2026, 10, 30), strength: .relentless))
        #expect(RemindersScreen(engine: day.model.engine, filter: narrowing).rows.last?.title == "Hard one")
    }
}
