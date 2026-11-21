import Foundation
import Testing
@testable import NudgeEngine

/// The Tags tab's name order is the person's locale's (ticket 335). Each test names the locale.
struct TagListNameOrderTests {
    let swedish = NameOrder(locale: Locale(identifier: "sv_SE"))
    let english = NameOrder(locale: Locale(identifier: "en_US"))

    /// `names` as tags, the first with two reminders and the rest with one each, so the count
    /// orders have a tie to break.
    func engine(_ names: [String]) -> Engine {
        let tags = names.map { Tag(name: $0) }
        var engine = Engine(clock: FakeClock(now: NewYork.local(2026, 10, 15, 20)), scheduler: FakeScheduler(), timeZone: NewYork.timeZone)
        engine.update(tags: tags)
        engine.update(reminders: tags.enumerated().flatMap { index, tag in
            (0..<(index == 0 ? 2 : 1)).map { _ in
                Reminder(title: "r", tagIDs: [tag.id], dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)
            }
        })
        return engine
    }

    func names(_ engine: Engine, _ sort: TagSort, _ order: NameOrder) -> [String] {
        engine.tagList(sortedBy: sort, nameOrder: order).rows.map(\.tag.name)
    }

    @Test func aToZFollowsTheLocalesOrderAndZToAIsItsExactReverse() {
        let engine = engine(["Östen", "zoo", "Anna", "Tag-10", "Tag-2"])

        #expect(names(engine, TagSort(field: .name, order: .ascending), swedish) == ["Anna", "Tag-2", "Tag-10", "zoo", "Östen"])
        #expect(names(engine, TagSort(field: .name, order: .descending), swedish) == ["Östen", "zoo", "Tag-10", "Tag-2", "Anna"])
        #expect(names(engine, TagSort(field: .name, order: .ascending), english) == ["Anna", "Östen", "Tag-2", "Tag-10", "zoo"])
    }

    @Test func tagsWithTheSameCountSortByNameInTheLocalesOrderUnderBothCountOrders() {
        // "Cy" has two reminders; the rest have one each.
        let engine = engine(["Cy", "Östen", "zoo", "Anna"])

        #expect(names(engine, TagSort(field: .reminderCount, order: .descending), swedish) == ["Cy", "Anna", "zoo", "Östen"])
        #expect(names(engine, TagSort(field: .reminderCount, order: .ascending), swedish) == ["Anna", "zoo", "Östen", "Cy"])
    }

    @Test func namesThatDifferOnlyByCaseFallBackToTheTagsID() {
        let low = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "ANNA")
        let middle = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "anna")
        let high = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Anna")
        var engine = Engine(clock: FakeClock(now: NewYork.local(2026, 10, 15, 20)), scheduler: FakeScheduler(), timeZone: NewYork.timeZone)
        engine.update(tags: [high, low, middle])

        #expect(engine.tagList(nameOrder: english).rows.map(\.tag.id) == [low.id, middle.id, high.id])
        #expect(engine.tagList(sortedBy: TagSort(field: .name, order: .descending), nameOrder: english).rows.map(\.tag.id) == [high.id, middle.id, low.id])
    }
}
