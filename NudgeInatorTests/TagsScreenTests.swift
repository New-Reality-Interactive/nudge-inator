import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Tags tab through `TagsScreen`, what it draws, read from the real app model on ticket 16's
/// fixture. Layout, Edit mode, VoiceOver and Dynamic Type are screenshot and device checks.
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

    @Test func withNoTagsTheScreenIsEmpty() async throws {
        let model = try await fixture.launchedModel()

        #expect(TagsScreen(engine: model.engine).isEmpty)
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
