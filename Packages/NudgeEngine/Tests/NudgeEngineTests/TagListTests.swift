import Foundation
import Testing
@testable import NudgeEngine

/// The Tags tab's list: every tag's row in the Sort menu's order, with the header row's numbers.
struct TagListTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 20))
    let scheduler = FakeScheduler()

    /// Three reminders use #Errands, one uses #home and one #Art; #zoo and #Bills have none.
    /// The mixed case is what shows the names sort ignoring it.
    func engine() -> Engine {
        let errands = Tag(name: "Errands"), home = Tag(name: "home"), art = Tag(name: "Art")
        let zoo = Tag(name: "zoo"), bills = Tag(name: "Bills")
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(tags: [zoo, errands, home, bills, art])
        engine.update(reminders: [
            Reminder(title: "Post the parcel", tagIDs: [errands.id], dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle),
            Reminder(title: "Buy stamps", tagIDs: [errands.id], dueTime: NewYork.local(2026, 10, 16, 10), strength: .gentle),
            Reminder(title: "Collect the suit", tagIDs: [errands.id], dueTime: NewYork.local(2026, 10, 16, 11), strength: .gentle),
            Reminder(title: "Water the plants", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 16, 12), strength: .gentle),
            Reminder(title: "Sketch the bridge", tagIDs: [art.id], dueTime: NewYork.local(2026, 10, 16, 13), strength: .gentle),
        ])
        return engine
    }

    @Test(arguments: [
        (TagSort(field: .name, order: .ascending), ["Art", "Bills", "Errands", "home", "zoo"]),
        (TagSort(field: .name, order: .descending), ["zoo", "home", "Errands", "Bills", "Art"]),
        // Ties on the count sort by name, A to Z, either way round.
        (TagSort(field: .reminderCount, order: .descending), ["Errands", "Art", "home", "Bills", "zoo"]),
        (TagSort(field: .reminderCount, order: .ascending), ["Bills", "zoo", "Art", "home", "Errands"]),
    ])
    func theRowsFollowTheSort(sort: TagSort, names: [String]) {
        #expect(engine().tagList(sortedBy: sort).rows.map(\.tag.name) == names)
    }

    @Test func withNoSortChosenItIsNameAToZ() {
        #expect(engine().tagList().rows.map(\.tag.name) == ["Art", "Bills", "Errands", "home", "zoo"])
    }

    @Test func eachRowCarriesItsTagsCounts() {
        let list = engine().tagList(sortedBy: TagSort(field: .reminderCount, order: .descending))

        #expect(list.rows.map(\.reminderCount) == [3, 1, 1, 0, 0])
    }

    @Test func theVisibleCountIsTheRowsAndTheTotalIsEveryTag() {
        let list = engine().tagList()

        #expect(list.visibleCount == 5)
        #expect(list.total == 5)
    }

    @Test func withNoTagsTheListIsEmpty() {
        let list = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone).tagList()

        #expect(list.rows.isEmpty)
        #expect(list.visibleCount == 0)
        #expect(list.total == 0)
    }
}
