import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A tag's screen through `TagRemindersScreen`, read from the real app model on ticket 16's
/// fixture (13:00 on Friday 16 October). Layout and VoiceOver are screenshot and device checks.
@MainActor
struct TagRemindersScreenTests {
    let fixture = MyDayScreenTests()

    @Test func theSectionsAreTodayLaterPausedAndCompletedInTimeOrder() async throws {
        let day = try await fixture.dayAtOnePM()
        var alex = day.alex
        alex.tagIDs = [day.home.id]
        try day.model.edit(alex)

        let home = try #require(TagRemindersScreen(engine: day.model.engine, tagID: day.home.id))
        let work = try #require(TagRemindersScreen(engine: day.model.engine, tagID: day.work.id))

        #expect(home.sections.map(\.kind) == [.today, .later])
        #expect(home.sections.map { $0.rows.map(\.title) } == [["Reply to Alex", "Water the plants", "Take the bins out"], ["Walk the dog"]])
        #expect(work.sections.map(\.kind) == [.today, .paused, .completed])
        #expect(work.sections.map { $0.rows.map(\.title) } == [["Send the status update"], ["Stretch break"], ["Team stand-up"]])
    }

    @Test func aTagWithNoRemindersHasNoSections() async throws {
        let model = try await fixture.launchedModel()
        let tag = try #require(try model.createTag(named: "travel"))

        let screen = try #require(TagRemindersScreen(engine: model.engine, tagID: tag.id))

        #expect(screen.sections.isEmpty)
        #expect(screen.reminderCount == 0)
    }

    @Test func aDeletedTagHasNoScreen() async throws {
        let day = try await fixture.dayAtOnePM()
        day.model.deleteTag(day.home.id)

        #expect(TagRemindersScreen(engine: day.model.engine, tagID: day.home.id) == nil)
    }
}
