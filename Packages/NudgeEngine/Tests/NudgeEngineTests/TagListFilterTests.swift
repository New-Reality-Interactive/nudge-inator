import Foundation
import Testing
@testable import NudgeEngine

/// The Tags tab's filter (#142, spec #104, Decision 53): one condition about the tag itself, Has no
/// reminders. On `TagListTests`' fixture, where #zoo and #Bills are the tags no reminder uses.
struct TagListFilterTests {
    let fixture = TagListTests()

    func names(_ engine: Engine, _ filter: TagListFilter, sortedBy sort: TagSort = .nameAToZ) -> [String] {
        engine.tagList(sortedBy: sort, filteredBy: filter).rows.map(\.tag.name)
    }

    @Test func hasNoRemindersShowsOnlyTheTagsNoReminderUses() {
        #expect(names(fixture.engine(), TagListFilter(hasNoReminders: true)) == ["Bills", "zoo"])
    }

    @Test func offItNarrowsNothing() {
        #expect(names(fixture.engine(), TagListFilter(hasNoReminders: false)) == ["Art", "Bills", "Errands", "home", "zoo"])
    }

    func reminder(titled title: String, in engine: Engine) throws -> Reminder {
        try #require(engine.reminders.first { $0.title == title })
    }

    func tag(named name: String, in engine: Engine) throws -> Tag {
        try #require(engine.tags.first { $0.name == name })
    }

    /// "Sketch the bridge" is the only reminder with #Art.
    @Test func aTagWhoseLastReminderIsDeletedStartsToMatch() throws {
        var engine = fixture.engine()

        engine.delete(try reminder(titled: "Sketch the bridge", in: engine).id)

        #expect(names(engine, TagListFilter(hasNoReminders: true)) == ["Art", "Bills", "zoo"])
    }

    @Test func aTagTakenOffItsLastReminderStartsToMatch() throws {
        var engine = fixture.engine()
        var sketch = try reminder(titled: "Sketch the bridge", in: engine)

        sketch.tagIDs = []
        try engine.edit(sketch)

        #expect(names(engine, TagListFilter(hasNoReminders: true)) == ["Art", "Bills", "zoo"])
    }

    @Test func aTagGivenItsFirstUseStopsMatching() throws {
        var engine = fixture.engine()
        var sketch = try reminder(titled: "Sketch the bridge", in: engine)

        sketch.tagIDs.append(try tag(named: "zoo", in: engine).id)
        try engine.edit(sketch)

        #expect(names(engine, TagListFilter(hasNoReminders: true)) == ["Bills"])
    }

    @Test func aTagIsShownOnlyIfItPassesTheSearchAndTheCondition() {
        let engine = fixture.engine()

        #expect(names(engine, TagListFilter(search: "#zo", hasNoReminders: true)) == ["zoo"])
        // #home matches the search, and a reminder uses it.
        #expect(names(engine, TagListFilter(search: "o", hasNoReminders: true)) == ["zoo"])
    }

    @Test func theSortAppliesToTheTagsThatMatch() {
        #expect(names(fixture.engine(), TagListFilter(hasNoReminders: true), sortedBy: TagSort(field: .name, order: .descending)) == ["zoo", "Bills"])
    }

    @Test func theVisibleCountIsTheMatchesAndTheTotalIsEveryTag() {
        let list = fixture.engine().tagList(filteredBy: TagListFilter(hasNoReminders: true))

        #expect(list.visibleCount == 2)
        #expect(list.total == 5)
    }
}
