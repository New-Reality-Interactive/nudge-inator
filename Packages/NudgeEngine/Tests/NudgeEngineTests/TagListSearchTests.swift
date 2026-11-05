import Foundation
import Testing
@testable import NudgeEngine

/// The Tags tab's search (#141, spec #104, Decision 44): the tag's name only, with a leading `#` ignored.
struct TagListSearchTests {
    let fixture = TagListTests()

    func names(_ engine: Engine, searching search: String, sortedBy sort: TagSort = .nameAToZ) -> [String] {
        engine.tagList(sortedBy: sort, filteredBy: TagListFilter(search: search)).rows.map(\.tag.name)
    }

    func engine(holding names: String...) -> Engine {
        var engine = Engine(clock: fixture.clock, scheduler: fixture.scheduler, timeZone: NewYork.timeZone)
        engine.update(tags: names.map { Tag(name: $0) })
        return engine
    }

    @Test func aSearchFindsPartOfAName() {
        #expect(names(fixture.engine(), searching: "rand") == ["Errands"])
    }

    @Test(arguments: [
        ("HOME", "home"),
        ("home", "HOME"),
        ("cafe", "café"),
        ("CAFÉ", "cafe"),
    ])
    func aSearchIgnoresCaseAndDiacritics(search: String, name: String) {
        #expect(names(engine(holding: name), searching: search) == [name])
    }

    @Test(arguments: ["home-office", "  home-office", "home-office  ", "\thome-office\n"])
    func aSearchIsTheTrimmedTextAsOnePhrase(search: String) {
        let engine = engine(holding: "home-office-desk", "office-home")

        #expect(names(engine, searching: search) == ["home-office-desk"])
    }

    @Test(arguments: ["", " ", "   ", "\t\n"])
    func textOfOnlySpacesSearchesNothing(search: String) {
        #expect(names(fixture.engine(), searching: search) == ["Art", "Bills", "Errands", "home", "zoo"])
    }

    @Test(arguments: ["home", "#home", " #home ", "# home"])
    func aLeadingHashIsIgnored(search: String) {
        #expect(names(fixture.engine(), searching: search) == ["home"])
    }

    @Test func aHashAloneSearchesNothing() {
        #expect(names(fixture.engine(), searching: "#") == ["Art", "Bills", "Errands", "home", "zoo"])
    }

    @Test func onlyOneLeadingHashIsIgnored() {
        #expect(names(fixture.engine(), searching: "##home") == [])
    }

    /// "Post the parcel" has #Errands, and only a name is searched.
    @Test func aRemindersTitleDoesntMatch() {
        #expect(names(fixture.engine(), searching: "parcel") == [])
    }

    @Test func theSortAppliesToTheResults() {
        let engine = engine(holding: "home-a", "home-b", "zoo")

        #expect(names(engine, searching: "home", sortedBy: TagSort(field: .name, order: .descending)) == ["home-b", "home-a"])
    }

    @Test func aReminderCountSortAppliesToTheResults() {
        // #Errands has three reminders and #Art one, and both have an "r".
        let mostFirst = TagSort(field: .reminderCount, order: .descending)
        let fewestFirst = TagSort(field: .reminderCount, order: .ascending)

        #expect(names(fixture.engine(), searching: "r", sortedBy: mostFirst) == ["Errands", "Art"])
        #expect(names(fixture.engine(), searching: "r", sortedBy: fewestFirst) == ["Art", "Errands"])
    }

    @Test func theVisibleCountFollowsTheSearchAndTheTotalIsEveryTag() {
        let list = fixture.engine().tagList(filteredBy: TagListFilter(search: "r"))

        #expect(list.visibleCount == 2)
        #expect(list.total == 5)
    }

    @Test func whenNothingMatchesTheTotalStillCountsEveryTag() {
        let list = fixture.engine().tagList(filteredBy: TagListFilter(search: "zebra"))

        #expect(list.rows.isEmpty)
        #expect(list.visibleCount == 0)
        #expect(list.total == 5)
    }

    /// The no-match state names the search as it was typed, `#` included, without the spaces.
    @Test func theFilterKeepsTheTextTrimmedWithItsHash() {
        var filter = TagListFilter(search: "  #home ")
        #expect(filter.search == "#home")

        filter.search = " zebra  "
        #expect(filter.search == "zebra")
    }

    @Test func aSpaceTypedAfterAWordDoesntChangeTheFilter() {
        #expect(TagListFilter(search: "home ") == TagListFilter(search: "home"))
    }
}
