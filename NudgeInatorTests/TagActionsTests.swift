import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Tags tab's actions through the real app model: add, rename and delete, and what each
/// leaves in the engine and the store.
@MainActor
struct TagActionsTests {
    let fixture = MyDayScreenTests()

    @Test func addingHomeWhenHomeExistsIsTurnedDownWithTheExistingTag() async throws {
        let model = try await fixture.launchedModel()
        let home = try #require(try model.createTag(named: "home"))

        #expect(throws: TagNameError.taken(by: home)) { try model.createTag(named: "Home") }
        #expect(model.engine.tags == [home])
    }

    @Test func anEmptyNameIsTurnedDown() async throws {
        let model = try await fixture.launchedModel()

        #expect(throws: TagNameError.empty) { try model.createTag(named: " # ") }
        #expect(model.engine.tags.isEmpty)
    }

    @Test func renamingToAnotherTagsNameIgnoringCaseIsTurnedDown() async throws {
        let model = try await fixture.launchedModel()
        let home = try #require(try model.createTag(named: "home"))
        let work = try #require(try model.createTag(named: "work"))

        #expect(throws: TagNameError.taken(by: home)) { try model.renameTag(work.id, to: "HOME") }
        #expect(model.engine.tag(withID: work.id)?.name == "work")
    }

    @Test func deletingATagUsedByThreeRemindersKeepsThemWithoutIt() async throws {
        let day = try await fixture.dayAtOnePM()
        let used = day.model.engine.tagSummaries().first { $0.tag.id == day.home.id }

        day.model.deleteTag(day.home.id)

        #expect(used?.reminderCount == 3)
        #expect(day.model.engine.tag(withID: day.home.id) == nil)
        let kept = day.model.engine.reminders.filter { [day.dog.id, day.plants.id, day.bins.id].contains($0.id) }
        #expect(kept.count == 3)
        #expect(kept.allSatisfy { !$0.tagIDs.contains(day.home.id) })
    }
}
