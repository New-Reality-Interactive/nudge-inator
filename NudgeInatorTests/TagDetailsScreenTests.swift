import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A tag's details page through `TagDetailsScreen`, read from the real app model on ticket 16's
/// fixture (13:00 on Friday 16 October). Layout, Back and VoiceOver are phone checks.
@MainActor
struct TagDetailsScreenTests {
    let fixture = MyDayScreenTests()

    @Test func thePageShowsTheCountsItsRowOnTheListShows() async throws {
        let day = try await fixture.dayAtOnePM()
        let list = TagsScreen(engine: day.model.engine)

        for row in list.rows {
            let page = try #require(TagDetailsScreen(engine: day.model.engine, tagID: row.tag.id))
            #expect(page.summary == row)
        }
    }

    @Test func aDeletedTagHasNoPage() async throws {
        let day = try await fixture.dayAtOnePM()
        day.model.deleteTag(day.home.id)

        #expect(TagDetailsScreen(engine: day.model.engine, tagID: day.home.id) == nil)
    }

    /// After Edit's Done, the page shows the new name in place, with the counts it had.
    @Test func aRenamedTagShowsItsNewNameWithTheSameCounts() async throws {
        let day = try await fixture.dayAtOnePM()
        let before = try #require(TagDetailsScreen(engine: day.model.engine, tagID: day.home.id))

        try day.model.renameTag(day.home.id, to: "house")

        let after = try #require(TagDetailsScreen(engine: day.model.engine, tagID: day.home.id))
        #expect(after.tag.name == "house")
        #expect(after.summary.reminderCount == before.summary.reminderCount)
    }
}
