import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Tags filter sheet as values, before any view draws them (#142): what's applied, the draft,
/// and what the Filter button shows. On ticket 16's fixture, whose three tags each have reminders,
/// with #unused added.
@MainActor
struct TagsFilterSheetTests {
    let fixture = MyDayScreenTests()

    private func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en")
        return String(localized: resource)
    }

    private func engine() async throws -> Engine {
        let day = try await fixture.dayAtOnePM()
        try day.model.createTag(named: "unused")
        return day.model.engine
    }

    @Test func theBadgeIsOneWhileTheConditionIsOnAndNoneOtherwise() {
        #expect(TagsFilterChoices().sectionsInUse == 0)
        #expect(TagsFilterChoices(hasNoReminders: true).sectionsInUse == 1)
    }

    @Test func theListIsNarrowedByTheConditionAndTheSearchItIsGiven() {
        let filter = TagsFilterChoices(hasNoReminders: true).narrowing(search: " #ho ")

        #expect(filter == TagListFilter(search: "#ho", hasNoReminders: true))
    }

    @Test func aDraftLikeWhatsAppliedClosesWithoutAsking() async throws {
        let applied = TagsFilterChoices(hasNoReminders: true)

        let sheet = TagsFilterSheet(engine: try await engine(), draft: applied, applied: applied, search: "")

        #expect(!sheet.hasChanges)
    }

    @Test func aChangedDraftAsksFirst() async throws {
        let sheet = TagsFilterSheet(engine: try await engine(), draft: TagsFilterChoices(hasNoReminders: true), applied: TagsFilterChoices(), search: "")

        #expect(sheet.hasChanges)
    }

    @Test func resetClearsTheDraftAndOnlyApplyChangesWhatsApplied() async throws {
        let engine = try await engine()
        let applied = TagsFilterChoices(hasNoReminders: true)
        let before = TagsFilterSheet(engine: engine, draft: applied, applied: applied, search: "")
        #expect(before.canReset)

        let reset = TagsFilterSheet(engine: engine, draft: TagsFilterChoices(), applied: applied, search: "")

        #expect(!reset.canReset)
        // The reset draft differs from what's still applied, so closing without Apply asks first.
        #expect(reset.hasChanges)
    }

    @Test func applyWouldShowTheDraftsMatchesWithTheSearchAsItIs() async throws {
        let engine = try await engine()

        let all = TagsFilterSheet(engine: engine, draft: TagsFilterChoices(), applied: TagsFilterChoices(), search: "")
        let unused = TagsFilterSheet(engine: engine, draft: TagsFilterChoices(hasNoReminders: true), applied: TagsFilterChoices(), search: "")
        let searched = TagsFilterSheet(engine: engine, draft: TagsFilterChoices(hasNoReminders: true), applied: TagsFilterChoices(), search: "home")

        #expect(english(all.result) == "Apply shows 4 tags.")
        #expect(english(unused.result) == "Apply shows 1 tag.")
        #expect(english(searched.result) == "Apply shows 0 tags.")
    }
}
