import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Tags tab through `TagsScreen`, what it draws, read from the real app model on ticket 16's
/// fixture. Layout, the swipe, VoiceOver and Dynamic Type are screenshot and device checks.
@MainActor
struct TagsScreenTests {
    let fixture = MyDayScreenTests()

    @Test func eachTagsCountsAreTicket16sReminderDueTodayAndNudging() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = TagsScreen(engine: day.model.engine)

        #expect(screen.rows.map(\.tag.name) == ["health", "home", "work"])
        #expect(screen.rows.map(\.reminderCount) == [3, 3, 3])
        #expect(screen.rows.map(\.dueTodayCount) == [2, 3, 3])
        #expect(screen.rows.map(\.nudgingCount) == [0, 0, 0])
    }

    @Test func withNoTagsTheEmptyStateIsNoTags() async throws {
        let model = try await fixture.launchedModel()

        #expect(TagsScreen(engine: model.engine).emptyState == .noTags)
    }

    @Test func aNudgingReminderCountsUnderEachOfItsTags() async throws {
        let day = try await fixture.dayAtOnePM()
        var alex = day.alex
        alex.tagIDs = [day.home.id, day.work.id]
        try day.model.edit(alex)

        let screen = TagsScreen(engine: day.model.engine)

        #expect(screen.rows.map(\.nudgingCount) == [0, 1, 1])
        #expect(screen.rows.map(\.reminderCount) == [3, 4, 4])
    }
}

/// The header row and the Sort menu's order (#140).
extension TagsScreenTests {
    private func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en")
        return String(localized: resource)
    }

    @Test func theRowsFollowTheSort() async throws {
        let day = try await fixture.dayAtOnePM()
        try day.model.createTag(named: "unused")

        let mostFirst = TagsScreen(engine: day.model.engine, sort: TagSort(field: .reminderCount, order: .descending))
        let zToA = TagsScreen(engine: day.model.engine, sort: TagSort(field: .name, order: .descending))

        #expect(mostFirst.rows.map(\.tag.name) == ["health", "home", "work", "unused"])
        #expect(zToA.rows.map(\.tag.name) == ["work", "unused", "home", "health"])
    }

    @Test func theHeaderCountsEveryRowOutOfEveryTag() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = TagsScreen(engine: day.model.engine)

        #expect(screen.shownCount == screen.rows.count)
        #expect(screen.total == 3)
        #expect(english(screen.countText) == "3 tags out of 3")
    }

    @Test func theHeaderSaysTagInTheSingular() {
        #expect(english(TagsScreen.countText(shown: 1, of: 8)) == "1 tag out of 8")
    }

    @Test func addingOrDeletingATagUpdatesTheCount() async throws {
        let day = try await fixture.dayAtOnePM()

        try day.model.createTag(named: "unused")
        #expect(english(TagsScreen(engine: day.model.engine).countText) == "4 tags out of 4")

        day.model.deleteTag(day.home.id)
        #expect(english(TagsScreen(engine: day.model.engine).countText) == "3 tags out of 3")
    }
}

/// The search (#141): the count follows it, and when nothing matches the screen says so.
extension TagsScreenTests {
    @Test func theRowsAndTheCountFollowTheSearch() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = TagsScreen(engine: day.model.engine, filter: TagListFilter(search: "#ho"))

        #expect(screen.rows.map(\.tag.name) == ["home"])
        #expect(english(screen.countText) == "1 tag out of 3")
        #expect(screen.emptyState == nil)
    }

    @Test func aSearchThatMatchesNothingIsNotNoTags() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = TagsScreen(engine: day.model.engine, filter: TagListFilter(search: "zebra"))

        #expect(screen.emptyState == .noMatch)
        #expect(english(screen.countText) == "0 tags out of 3")
    }

    /// With no tags there's no search field, but text left over from before the last tag went must
    /// still read as no tags.
    @Test func withNoTagsASearchIsStillNoTags() async throws {
        let model = try await fixture.launchedModel()

        let screen = TagsScreen(engine: model.engine, filter: TagListFilter(search: "zebra"))

        #expect(screen.emptyState == .noTags)
    }

    @Test func theNoMatchWordsNameTheSearchAsTypedAndOfferToClearIt() {
        let filter = TagListFilter(search: "  #zebra ")

        #expect(english(filter.noMatchTitle) == "No Results for “#zebra”")
        #expect(english(filter.noMatchText) == "Check the spelling or try a new search.")
        #expect(english(filter.noMatchClearTitle) == "Clear Search")
    }
}

extension TagsScreenTests {
    @Test func theDeleteQuestionSaysHowManyRemindersUseTheTag() async throws {
        let day = try await fixture.dayAtOnePM()
        let home = try #require(TagsScreen(engine: day.model.engine).rows.first { $0.tag.id == day.home.id })

        // The count is the plural variant's argument, so the words are the catalog's to vary.
        var resource = home.deleteMessage
        resource.locale = Locale(identifier: "en")
        let message = String(localized: resource)

        #expect(home.reminderCount == 3)
        #expect(message.contains("3 reminders use this tag"))
    }

    @Test func theDeleteQuestionSaysSoWhenNoRemindersUseTheTag() async throws {
        let day = try await fixture.dayAtOnePM()
        try day.model.createTag(named: "unused")
        let unused = try #require(TagsScreen(engine: day.model.engine).rows.first { $0.tag.name == "unused" })

        var resource = unused.deleteMessage
        resource.locale = Locale(identifier: "en")

        #expect(String(localized: resource) == "No reminders use this tag.")
    }

    @Test func aDeletedTagsRowLeavesTheListAndItsNeighborsStay() async throws {
        let day = try await fixture.dayAtOnePM()

        day.model.deleteTag(day.home.id)

        #expect(TagsScreen(engine: day.model.engine).rows.map(\.tag.name) == ["health", "work"])
    }

    /// The catalog varies these by the first number only (a substitution), so the other two
    /// counts must not change the reminder/reminders choice.
    @Test func theCountsLineSaysReminderOrRemindersByTheReminderCountAlone() async throws {
        let day = try await fixture.dayAtOnePM()
        try day.model.createTag(named: "solo")
        var alex = day.alex
        alex.tagIDs = [day.home.id, try #require(day.model.engine.tags.first { $0.name == "solo" }).id]
        try day.model.edit(alex)

        let rows = TagsScreen(engine: day.model.engine).rows
        let solo = try #require(rows.first { $0.tag.name == "solo" })
        let home = try #require(rows.first { $0.tag.id == day.home.id })

        func text(_ summary: TagSummary) -> String {
            var resource = summary.counts
            resource.locale = Locale(identifier: "en")
            return String(localized: resource)
        }

        #expect(solo.reminderCount == 1 && solo.nudgingCount == 1)
        #expect(text(solo).hasPrefix("1 reminder · "))
        #expect(text(solo).contains("1 nudging"))
        #expect(home.reminderCount == 4 && home.nudgingCount == 1)
        #expect(text(home).hasPrefix("4 reminders · "))
        #expect(text(rows.first { $0.tag.name == "work" }!).hasPrefix("3 reminders · 3 today"))
    }
}

/// The filter (#142): Has no reminders narrows with the search, and the no-match state names both.
extension TagsScreenTests {
    @Test func theFilterLeavesOnlyUnusedTagsAndTheCountFollows() async throws {
        let day = try await fixture.dayAtOnePM()
        try day.model.createTag(named: "unused")

        let screen = TagsScreen(engine: day.model.engine, filter: TagListFilter(hasNoReminders: true))

        #expect(screen.rows.map(\.tag.name) == ["unused"])
        #expect(english(screen.countText) == "1 tag out of 4")
    }

    @Test func aFilterThatMatchesNothingIsNotNoTags() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = TagsScreen(engine: day.model.engine, filter: TagListFilter(hasNoReminders: true))

        #expect(screen.emptyState == .noMatch)
        #expect(english(screen.countText) == "0 tags out of 3")
    }

    @Test func theNoMatchWordsNameTheFilter() {
        let filter = TagListFilter(hasNoReminders: true)

        #expect(english(filter.noMatchTitle) == "No Matches")
        #expect(english(filter.noMatchText) == "No tags with this filter.")
        #expect(english(filter.noMatchClearTitle) == "Clear Filter")
        #expect(filter.noMatchSystemImage == "line.3.horizontal.decrease")
    }

    @Test func theNoMatchWordsNameTheSearchAndTheFilter() {
        let filter = TagListFilter(search: "zebra", hasNoReminders: true)

        #expect(english(filter.noMatchTitle) == "No Results for “zebra”")
        #expect(english(filter.noMatchText) == "No tags with this filter match this search.")
        #expect(english(filter.noMatchClearTitle) == "Clear Search and Filter")
        #expect(filter.noMatchSystemImage == "magnifyingglass")
    }
}
