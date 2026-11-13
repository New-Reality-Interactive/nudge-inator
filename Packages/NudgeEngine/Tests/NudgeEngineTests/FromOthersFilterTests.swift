import Foundation
import Testing
@testable import NudgeEngine

/// The From others filter (spec #127, ticket 209): on, the Reminders tab and My Day show only
/// received reminders, together with search, sort and the 1.3.0 filters. Off, they show what they
/// did before. Ticket 16's day, 13:00 on Friday 16 October 2026 in New York, from
/// `RemindersListTests`, with two received copies beside the seven of the person's own.
struct FromOthersFilterTests {
    let fixture = RemindersListTests()
    let home = Tag(name: "home")
    /// Due at 15:00 today, Firm, tagged #home, made before every reminder of the fixture's.
    let pills: Reminder
    /// Due at 18:00 today, Gentle, with no tags, made after every reminder of the fixture's.
    let umbrella: Reminder

    init() {
        pills = Self.received(title: "Take the pills", dueTime: NewYork.local(2026, 10, 16, 15), strength: .firm, tagIDs: [home.id], createdAt: NewYork.local(2026, 9, 1))
        umbrella = Self.received(title: "Bring the umbrella", dueTime: NewYork.local(2026, 10, 16, 18), strength: .gentle, tagIDs: [], createdAt: NewYork.local(2026, 10, 2))
    }

    static func received(title: String, dueTime: Date, strength: Strength, tagIDs: [Tag.ID], createdAt: Date) -> Reminder {
        Reminder(
            title: title,
            notes: "From the pharmacy",
            tagIDs: tagIDs,
            dueTime: dueTime,
            strength: strength,
            createdAt: createdAt,
            origin: .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 1, state: .accepted)
        )
    }

    /// The fixture's seven, then the two received.
    func engine() -> Engine {
        var engine = fixture.oneOfEach().engine
        engine.update(tags: [home])
        engine.update(reminders: engine.reminders + [pills, umbrella])
        return engine
    }

    func titles(_ engine: Engine, _ filter: RemindersFilter, sortedBy sort: RemindersSort = .createdOldestFirst) -> [String] {
        engine.remindersList(sortedBy: sort, filteredBy: filter).items.map(\.reminder.title)
    }

    // MARK: Reminders

    @Test func onTheRemindersListShowsOnlyReceivedReminders() {
        #expect(titles(engine(), RemindersFilter(fromOthers: true)) == ["Take the pills", "Bring the umbrella"])
    }

    @Test func offTheRemindersListShowsEveryReminder() {
        let shown = engine().remindersList(filteredBy: RemindersFilter())

        #expect(shown.items.count == 9)
        #expect(shown.total == 9)
    }

    @Test func itNarrowsTogetherWithTheSearch() {
        let engine = engine()

        #expect(titles(engine, RemindersFilter(fromOthers: true, search: "umbrella")) == ["Bring the umbrella"])
        #expect(titles(engine, RemindersFilter(fromOthers: true, search: "dog")) == [])
        #expect(titles(engine, RemindersFilter(fromOthers: true, search: "pharmacy")) == ["Take the pills", "Bring the umbrella"])
    }

    @Test func itNarrowsTogetherWithTheOtherSections() {
        let engine = engine()

        #expect(titles(engine, RemindersFilter(tags: .matchAll([home.id]), fromOthers: true)) == ["Take the pills"])
        #expect(titles(engine, RemindersFilter(tags: .noTags, fromOthers: true)) == ["Bring the umbrella"])
        #expect(titles(engine, RemindersFilter(strengths: [.gentle], fromOthers: true)) == ["Bring the umbrella"])
        #expect(titles(engine, RemindersFilter(statuses: [.nudging], fromOthers: true)) == [])
        #expect(titles(engine, RemindersFilter(statuses: [.comingUp], fromOthers: true)) == ["Take the pills", "Bring the umbrella"])
        let today = CalendarDay(year: 2026, month: 10, day: 16)
        #expect(titles(engine, RemindersFilter(dueFrom: today, dueTo: today, fromOthers: true)) == ["Take the pills", "Bring the umbrella"])
    }

    @Test func theListKeepsTheSortMenusOrder() {
        let engine = engine()

        #expect(titles(engine, RemindersFilter(fromOthers: true), sortedBy: RemindersSort(field: .created, order: .descending)) == ["Bring the umbrella", "Take the pills"])
        #expect(titles(engine, RemindersFilter(fromOthers: true), sortedBy: RemindersSort(field: .dueDate, order: .descending)) == ["Bring the umbrella", "Take the pills"])
    }

    @Test func itIsASheetFilter() {
        #expect(RemindersFilter(fromOthers: true).hasSheetFilters)
        #expect(!RemindersFilter().hasSheetFilters)
    }

    @Test func aReceivedCopyKeptAsMyOwnIsNoLongerFromOthers() {
        var engine = engine()
        var kept = pills
        kept.origin = .mine
        engine.update(reminders: engine.reminders.map { $0.id == kept.id ? kept : $0 })

        #expect(titles(engine, RemindersFilter(fromOthers: true)) == ["Bring the umbrella"])
    }

    // MARK: My Day

    func myDayTitles(_ engine: Engine, tagFilter: TagFilter = .off, fromOthers: Bool) -> [String] {
        engine.myDay(tagFilter: tagFilter, fromOthers: fromOthers).items.compactMap { item in
            engine.reminders.first { $0.id == item.reminderID }?.title
        }
    }

    @Test func onMyDayShowsOnlyReceivedRemindersDueToday() {
        #expect(myDayTitles(engine(), fromOthers: true) == ["Take the pills", "Bring the umbrella"])
    }

    @Test func offMyDayShowsEverythingDueTodayAsBefore() {
        let engine = engine()

        #expect(myDayTitles(engine, fromOthers: false).count == engine.myDay().items.count)
        #expect(myDayTitles(engine, fromOthers: false).contains("Walk the dog"))
        #expect(myDayTitles(engine, fromOthers: false).contains("Take the pills"))
    }

    @Test func onMyDayItNarrowsTogetherWithTheTags() {
        let engine = engine()

        #expect(myDayTitles(engine, tagFilter: .matchAll([home.id]), fromOthers: true) == ["Take the pills"])
        #expect(myDayTitles(engine, tagFilter: .noTags, fromOthers: true) == ["Bring the umbrella"])
    }

    @Test func onMyDaysCountsCoverOnlyReceivedReminders() {
        let myDay = engine().myDay(fromOthers: true)

        #expect(myDay.count(of: .left) == 2)
        #expect(myDay.count(of: .done) == 0)
    }
}
