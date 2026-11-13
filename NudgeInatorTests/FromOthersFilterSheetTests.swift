import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The From others filter in the Reminders tab's and My Day's filter sheets (ticket 209), as values
/// before any view draws them. On ticket 16's day (`MyDayScreenTests`), 13:00 on Friday 16 October,
/// with two received copies due later today beside the person's own ten. The sheets' layout against
/// the mockup, the token and VoiceOver are the phone check.
@MainActor
struct FromOthersFilterSheetTests {
    let fixture = MyDayScreenTests()

    /// Due at 15:00 today, Firm, with no tags.
    let pills = Self.received("Take the pills", hour: 15, strength: .firm)
    /// Due at 19:00 today, Gentle, with no tags.
    let umbrella = Self.received("Bring the umbrella", hour: 19, strength: .gentle)

    static func received(_ title: String, hour: Int, strength: Strength) -> Reminder {
        Reminder(
            title: title,
            dueTime: NewYork.local(2026, 10, 16, hour),
            strength: strength,
            origin: .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 1, state: .accepted)
        )
    }

    /// Ticket 16's day with the two received copies.
    func dayWithReceived() async throws -> MyDayScreenTests.Day {
        let day = try await fixture.dayAtOnePM()
        day.model.add(pills)
        day.model.add(umbrella)
        await day.model.waitUntilApplied()
        return day
    }

    // MARK: Reminders

    @Test func fromOthersCountsAsASectionInTheBadge() {
        var filter = RemindersFilterChoices()

        filter.toggleFromOthers()
        #expect(filter.sectionsInUse == 1)

        filter.toggle(Strength.firm)
        #expect(filter.sectionsInUse == 2)
    }

    @Test func fromOthersTappedAgainComesOff() {
        var filter = RemindersFilterChoices()

        filter.toggleFromOthers()
        #expect(filter.fromOthers)
        filter.toggleFromOthers()

        #expect(filter == RemindersFilterChoices())
    }

    @Test func theListIsNarrowedByFromOthersAndTheSearch() {
        var filter = RemindersFilterChoices()
        filter.toggleFromOthers()
        filter.toggle(Strength.gentle)

        #expect(filter.narrowing(search: " umbrella ") == RemindersFilter(strengths: [.gentle], fromOthers: true, search: "umbrella"))
    }

    func fromOthers() -> RemindersFilterChoices {
        var filter = RemindersFilterChoices()
        filter.toggleFromOthers()
        return filter
    }

    @Test func theSheetOffersFromOthersOnlyWhenSomeoneHasSentAReminder() async throws {
        let day = try await fixture.dayAtOnePM()
        let none = RemindersFilterChoices()
        #expect(!RemindersFilterSheet(engine: day.model.engine, draft: none, applied: none, search: "").offersFromOthers)

        day.model.add(pills)
        await day.model.waitUntilApplied()

        #expect(RemindersFilterSheet(engine: day.model.engine, draft: none, applied: none, search: "").offersFromOthers)
    }

    /// The last received reminder removed while From others is on: the section stays, so it can be
    /// turned off where it was turned on.
    @Test func theSheetKeepsFromOthersWhileItsOnWithNothingReceived() async throws {
        let day = try await fixture.dayAtOnePM()

        let sheet = RemindersFilterSheet(engine: day.model.engine, draft: fromOthers(), applied: fromOthers(), search: "")

        #expect(sheet.offersFromOthers)
    }

    @Test func applyCountsOnlyReceivedRemindersWithTheSearchAsItIs() async throws {
        let day = try await dayWithReceived()
        let none = RemindersFilterChoices()

        let all = RemindersFilterSheet(engine: day.model.engine, draft: fromOthers(), applied: none, search: "")
        let searched = RemindersFilterSheet(engine: day.model.engine, draft: fromOthers(), applied: none, search: "pills")

        #expect(String(localized: all.result) == "Apply shows 2 reminders.")
        #expect(String(localized: searched.result) == "Apply shows 1 reminder.")
    }

    @Test func fromOthersInTheDraftIsAChangeAndSomethingToReset() async throws {
        let day = try await dayWithReceived()
        let none = RemindersFilterChoices()

        let turnedOn = RemindersFilterSheet(engine: day.model.engine, draft: fromOthers(), applied: none, search: "")
        let asApplied = RemindersFilterSheet(engine: day.model.engine, draft: fromOthers(), applied: fromOthers(), search: "")

        #expect(turnedOn.hasChanges)
        #expect(turnedOn.canReset)
        #expect(!asApplied.hasChanges)
    }

    @Test func theRemindersListShowsOnlyReceivedRemindersWithFromOthersOn() async throws {
        let day = try await dayWithReceived()

        let screen = RemindersScreen(engine: day.model.engine, filter: fromOthers().narrowing(search: ""))

        #expect(Set(screen.rows.map(\.title)) == ["Take the pills", "Bring the umbrella"])
        #expect(String(localized: screen.countText) == "2 reminders out of 12")
    }

    // MARK: My Day

    func myDayFromOthers() -> MyDayFilter {
        var filter = MyDayFilter()
        filter.toggleFromOthers()
        return filter
    }

    /// The mockup's badge: the checked tags (No Tags as one) and one more for From others.
    @Test func myDaysBadgeCountsFromOthersAsOneMore() {
        var filter = myDayFromOthers()
        #expect(filter.checkedCount == 1)
        #expect(filter.isOn)

        filter.tags.toggleNoTags()
        #expect(filter.checkedCount == 2)

        filter.toggleFromOthers()
        #expect(filter.checkedCount == 1)
    }

    /// The mockup's Clear starts the filter afresh, From others included, and leaves the chosen count.
    @Test func myDaysClearTurnsFromOthersOffAndLeavesTheChosenCount() {
        var filter = myDayFromOthers()
        filter.tap(.left)

        filter.clear()

        #expect(!filter.isOn)
        #expect(!filter.fromOthers)
        #expect(filter.count == .left)
    }

    @Test func myDaysFromOthersGoesWithTheFilterButton() {
        var filter = myDayFromOthers()

        filter.update(offersFilter: false)

        #expect(!filter.fromOthers)
    }

    @Test func myDayShowsOnlyReceivedRemindersWithFromOthersOn() async throws {
        let day = try await dayWithReceived()

        let screen = MyDayScreen(engine: day.model.engine, filter: myDayFromOthers(), now: fixture.clock.now)

        #expect(screen.items.map(\.reminder.title) == ["Take the pills", "Bring the umbrella"])
        #expect(screen.counts.map(\.number) == [0, 0, 0, 2])
    }

    @Test func myDaysFromOthersTokenFollowsTheTagsTokens() async throws {
        let day = try await dayWithReceived()
        var filter = myDayFromOthers()
        filter.toggle(day.home.id)

        let screen = MyDayScreen(engine: day.model.engine, filter: filter, now: fixture.clock.now)

        #expect(screen.filterTokens.map(\.kind) == [.tag(day.home.id), .fromOthers])
    }

    @Test func myDayHasNoFromOthersTokenWithItOff() async throws {
        let day = try await dayWithReceived()

        let screen = MyDayScreen(engine: day.model.engine, filter: MyDayFilter(), now: fixture.clock.now)

        #expect(screen.filterTokens.isEmpty)
    }

    /// With no tags yet, a received reminder due today is something to filter by.
    @Test func myDayOffersTheFilterWithNoTagsOnceAReceivedReminderIsDueToday() async throws {
        let model = try await fixture.launchedModel()
        model.add(Reminder(title: "Walk the dog", dueTime: NewYork.local(2026, 10, 16, 18), strength: .gentle))
        await model.waitUntilApplied()
        #expect(!MyDayScreen(engine: model.engine, filter: MyDayFilter(), now: fixture.clock.now).offersFilter)

        model.add(pills)
        await model.waitUntilApplied()

        #expect(MyDayScreen(engine: model.engine, filter: MyDayFilter(), now: fixture.clock.now).offersFilter)
    }

    @Test func myDaysSheetOffersFromOthersOnlyWhenSomeoneHasSentAReminder() async throws {
        let day = try await fixture.dayAtOnePM()
        #expect(!MyDayFilterSheet(engine: day.model.engine, filter: MyDayFilter()).offersFromOthers)
        #expect(MyDayFilterSheet(engine: day.model.engine, filter: myDayFromOthers()).offersFromOthers)

        day.model.add(pills)
        await day.model.waitUntilApplied()

        #expect(MyDayFilterSheet(engine: day.model.engine, filter: MyDayFilter()).offersFromOthers)
    }

    @Test func myDaysSheetCountsWhatsDueTodayFromOthers() async throws {
        let day = try await dayWithReceived()
        var tagged = myDayFromOthers()
        tagged.toggle(day.home.id)
        var noTags = myDayFromOthers()
        noTags.tags.toggleNoTags()

        func result(_ filter: MyDayFilter) -> String {
            String(localized: MyDayFilterSheet(engine: day.model.engine, filter: filter).result)
        }

        #expect(result(myDayFromOthers()) == "2 due today from others.")
        #expect(result(noTags) == "2 due today without tags from others.")
        #expect(result(tagged) == "0 due today with #home from others.")
    }
}
