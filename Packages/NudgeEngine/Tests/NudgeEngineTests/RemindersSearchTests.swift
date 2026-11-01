import Foundation
import Testing
@testable import NudgeEngine

/// The Reminders tab's search (spec #104, Search). One reminder in each status at 13:00 on Friday
/// 16 October 2026 in New York, from `RemindersListTests`.
struct RemindersSearchTests {
    let fixture = RemindersListTests()

    func titles(_ engine: Engine, searching search: String) -> [String] {
        engine.remindersList(filteredBy: RemindersFilter(search: search)).items.map(\.reminder.title)
    }

    @Test func aSearchFindsPartOfATitle() {
        #expect(titles(fixture.oneOfEach().engine, searching: "dent") == ["Dentist appointment"])
    }

    /// An engine holding just these, as they'd be made at 13:00.
    func engine(holding reminders: [Reminder]) -> Engine {
        var engine = Engine(clock: fixture.clock, scheduler: fixture.scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    func reminder(_ title: String, notes: String = "", tagIDs: [Tag.ID] = []) -> Reminder {
        Reminder(title: title, notes: notes, tagIDs: tagIDs, dueTime: NewYork.local(2026, 10, 30, 9), strength: .gentle)
    }

    @Test(arguments: [
        ("pill", "Take Pills"),
        ("TAKE", "Take Pills"),
        ("cafe", "Café run"),
        ("CAFÉ", "Café run"),
        ("café", "Cafe run"),
    ])
    func aSearchIgnoresCaseAndDiacritics(search: String, title: String) {
        #expect(titles(engine(holding: [reminder(title)]), searching: search) == [title])
    }

    @Test func aSearchFindsTheNotes() {
        let meds = reminder("Morning meds", notes: "Blue pill + vitamin D")

        #expect(titles(engine(holding: [meds, reminder("Pay rent")]), searching: "vitamin") == ["Morning meds"])
    }

    @Test func aTagsNameAloneDoesntMatch() {
        let tag = Tag(name: "home")
        let tagged = reminder("Pay rent", tagIDs: [tag.id])
        var engine = engine(holding: [tagged])
        engine.update(tags: [tag])

        #expect(titles(engine, searching: "home") == [])
    }

    @Test(arguments: ["buy milk", "  buy milk", "buy milk  ", "\tbuy milk\n"])
    func aSearchIsTheTrimmedTextAsOnePhrase(search: String) {
        let engine = engine(holding: [reminder("Buy milk today"), reminder("Milk: buy")])

        #expect(titles(engine, searching: search) == ["Buy milk today"])
    }

    @Test func spacesInsideThePhraseCount() {
        #expect(titles(engine(holding: [reminder("Buy milk today")]), searching: "buy  milk") == [])
    }

    @Test(arguments: ["", " ", "    "])
    func textOfOnlySpacesLeavesTheListAsItWas(search: String) {
        #expect(titles(fixture.oneOfEach().engine, searching: search).count == 7)
    }

    /// The tab sets the search as it's typed, so a space after a word mustn't change the filter:
    /// a change sorts the list again and ends a new reminder's showing.
    @Test func aSpaceTypedAfterAWordLeavesTheFilterAsItWas() {
        var filter = RemindersFilter(search: "pill")

        filter.search = "pill "

        #expect(filter == RemindersFilter(search: "pill"))
        #expect(filter.search == "pill")
    }

    @Test func clearingTheSearchReturnsTheListAsItWas() {
        let engine = fixture.oneOfEach().engine
        var filter = RemindersFilter()
        filter.toggle(.nudging)
        let before = engine.remindersList(filteredBy: filter)

        filter.search = "dentist"
        #expect(engine.remindersList(filteredBy: filter).items.isEmpty)
        filter.search = ""

        #expect(engine.remindersList(filteredBy: filter) == before)
    }

    @Test func aChipAppliesToTheResults() {
        let day = fixture.oneOfEach()
        var filter = RemindersFilter(search: "e")
        #expect(day.engine.remindersList(filteredBy: filter).items.count > 1)

        filter.toggle(.nudging)

        #expect(day.engine.remindersList(filteredBy: filter).items.map(\.reminder.title) == ["Reply to Alex"])
        #expect(filter.search == "e")
        filter.toggle(.nudging)
        #expect(filter.search == "e")
    }

    @Test func aChipAndASearchThatShareNothingShowNothing() {
        var filter = RemindersFilter(search: "dentist")
        filter.toggle(.nudging)

        #expect(fixture.oneOfEach().engine.remindersList(filteredBy: filter).items.isEmpty)
    }

    @Test func theSortAppliesToTheResults() {
        let engine = fixture.oneOfEach().engine
        let filter = RemindersFilter(search: "al")
        func titles(_ sort: RemindersSort) -> [String] {
            engine.remindersList(sortedBy: sort, filteredBy: filter).items.map(\.reminder.title)
        }

        #expect(titles(.createdOldestFirst) == ["Reply to Alex", "Walk the dog"])
        #expect(titles(RemindersSort(field: .created, order: .descending)) == ["Walk the dog", "Reply to Alex"])
    }

    @Test func theTotalStaysEveryReminderUnderASearch() {
        let shown = fixture.oneOfEach().engine.remindersList(filteredBy: RemindersFilter(search: "dentist"))

        #expect(shown.items.count == 1)
        #expect(shown.total == 7)
    }

    /// Decision 20: a reminder just made shows until the search next changes.
    @Test func aReminderBeingShownPassesWhateverTheSearchSays() {
        let day = fixture.oneOfEach()

        let shown = day.engine.remindersList(filteredBy: RemindersFilter(search: "dentist"), alwaysShowing: [day.alex.id])

        #expect(shown.items.map(\.reminder.title) == ["Reply to Alex", "Dentist appointment"])
    }
}
