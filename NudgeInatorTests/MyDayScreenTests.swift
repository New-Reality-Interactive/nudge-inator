import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The My Day tab through `MyDayScreen`, what it draws, read from the real app model (in-memory
/// store, real adapters over the fakes) on ticket 16's fixture. Tests assert on the counts, the
/// rows and their text. Layout, the swipe, VoiceOver, the filter sheet and Dynamic Type are
/// screenshot and device checks.
@MainActor
struct MyDayScreenTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 6))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()

    func launchedModel() async throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await model.launch()
        return model
    }

    /// Ticket 16's day, at 13:00 on Friday 16 October. Meds and the dog were Done in the morning,
    /// the stand-up gave up, the stretch break was paused while nudging, Alex is nudging, Grandma
    /// is paused before her due time, and three are still to come. The dentist is tomorrow.
    struct Day {
        let model: AppModel
        let home: Tag, health: Tag, work: Tag
        let meds: Reminder, dog: Reminder, standUp: Reminder, stretch: Reminder, alex: Reminder
        let status: Reminder, grandma: Reminder, plants: Reminder, bins: Reminder, dentist: Reminder
    }

    func dayAtOnePM() async throws -> Day {
        let model = try await launchedModel()
        let home = try #require(try model.createTag(named: "home"))
        let health = try #require(try model.createTag(named: "health"))
        let work = try #require(try model.createTag(named: "work"))
        func at(_ hour: Int, _ minute: Int = 0) -> Date { NewYork.local(2026, 10, 16, hour, minute) }
        let meds = Reminder(title: "Morning meds", tagIDs: [health.id], dueTime: NewYork.local(2026, 10, 1, 6, 30), repeatRule: .everyDay, strength: .gentle)
        let dog = Reminder(title: "Walk the dog", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 1, 7), repeatRule: .everyDay, strength: .gentle)
        let standUp = Reminder(title: "Team stand-up", tagIDs: [work.id], dueTime: at(9, 30), strength: .relentless)
        let stretch = Reminder(title: "Stretch break", tagIDs: [health.id, work.id], dueTime: NewYork.local(2026, 10, 1, 10), repeatRule: .everyDay, strength: .firm)
        let alex = Reminder(title: "Reply to Alex", dueTime: at(12, 30), strength: .firm)
        let status = Reminder(title: "Send the status update", tagIDs: [work.id], dueTime: at(16, 30), strength: .gentle)
        let grandma = Reminder(title: "Call Grandma", dueTime: NewYork.local(2026, 10, 2, 17), repeatRule: .everyDay, strength: .gentle)
        let plants = Reminder(title: "Water the plants", tagIDs: [home.id], dueTime: at(18), strength: .gentle)
        let bins = Reminder(title: "Take the bins out", tagIDs: [home.id], dueTime: at(20), strength: .firm)
        let dentist = Reminder(title: "Dentist appointment", tagIDs: [health.id], dueTime: NewYork.local(2026, 10, 17, 13, 15), strength: .firm)
        for reminder in [bins, plants, grandma, status, alex, stretch, standUp, dog, meds, dentist] { model.add(reminder) }
        clock.now = at(7, 4)
        model.markDone(meds.id)
        clock.now = at(7, 18)
        model.markDone(dog.id)
        clock.now = at(10, 10)
        model.pause(stretch.id)
        clock.now = at(13)
        model.pause(grandma.id)
        await model.appOpened()
        await model.waitUntilApplied()
        return Day(model: model, home: home, health: health, work: work, meds: meds, dog: dog, standUp: standUp,
                   stretch: stretch, alex: alex, status: status, grandma: grandma, plants: plants, bins: bins, dentist: dentist)
    }

    @Test func theCountsAreTicket16sAndSkippedAndPausedAreInNone() async throws {
        let day = try await dayAtOnePM()

        let screen = MyDayScreen(engine: day.model.engine, filter: MyDayFilter(), now: clock.now)

        #expect(screen.counts.map(\.number) == [2, 1, 1, 3])
    }

    @Test func theRowsAreTodaysOccurrencesInTimeOrderWithTheirTimes() async throws {
        let day = try await dayAtOnePM()

        let screen = MyDayScreen(engine: day.model.engine, filter: MyDayFilter(), now: clock.now)

        #expect(screen.items.map(\.title) == [
            "Morning meds", "Walk the dog", "Team stand-up", "Stretch break", "Reply to Alex",
            "Send the status update", "Call Grandma", "Water the plants", "Take the bins out",
        ])
        #expect(screen.items.map(\.time) == ["6:30\u{202F}AM", "7:00\u{202F}AM", "9:30\u{202F}AM", "10:00\u{202F}AM", "12:30\u{202F}PM", "4:30\u{202F}PM", "5:00\u{202F}PM", "6:00\u{202F}PM", "8:00\u{202F}PM"])
    }

    /// The mockup's `note`: how a closed occurrence closed, as Last 24 Hours words it, and for
    /// a Done one when and after how many nudges (ticket 16). The meds, due 6:30 and Gentle, sent
    /// one nudge before they were Done at 7:04.
    @Test func aClosedRowSaysHowItClosed() async throws {
        let day = try await dayAtOnePM()
        let screen = MyDayScreen(engine: day.model.engine, filter: MyDayFilter(), now: clock.now)

        func note(_ reminder: Reminder) throws -> String {
            plain(try #require(screen.items.first { $0.reminder.id == reminder.id }).note(at: clock.now))
        }

        let meds = try note(day.meds)
        #expect(meds == "Done at 7:04\u{202F}AM after 1 nudge")
        #expect(try note(day.standUp) == "Missed: gave up after the limit")
        #expect(try note(day.stretch) == "Skipped: the reminder was paused")
    }

    /// Alex is Firm, due 12:30: nudge 1 at 12:30 and 2 at 13:00 have gone, 3 is at 13:15.
    @Test func anOpenRowSaysWhatIsNudgingOrComingAndAPausedOneThatItWillBeSkipped() async throws {
        let day = try await dayAtOnePM()
        let screen = MyDayScreen(engine: day.model.engine, filter: MyDayFilter(), now: clock.now)

        func note(_ reminder: Reminder) throws -> String {
            plain(try #require(screen.items.first { $0.reminder.id == reminder.id }).note(at: clock.now))
        }

        #expect(try note(day.alex) == "Nudging · 2 nudges · next 1:15\u{202F}PM")
        #expect(try note(day.grandma) == "Paused: this one will be skipped")
        let status = try note(day.status)
        // 3 h 30 min away: Foundation's relative formatter drops the half hour where the mockup rounds.
        #expect(status == "in 3 hr.")
    }

    /// Only the stretch break has both #health and #work; four have one of them; Alex and Grandma
    /// have no tags. The counts follow the filter: Match Any #health #work has Done 1 (the meds),
    /// Missed 1 (the stand-up) and Left 1 (the status update).
    @Test func matchAllAnyAndNoTagsGiveDifferentRowsAndCounts() async throws {
        let day = try await dayAtOnePM()
        func titles(_ filter: MyDayFilter) -> [String] {
            MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now).items.map(\.title)
        }
        var all = MyDayFilter()
        all.toggle(day.health.id)
        all.toggle(day.work.id)
        var any = all
        any.match = .any
        var none = MyDayFilter()
        none.toggleNoTags()

        #expect(titles(all) == ["Stretch break"])
        #expect(titles(any) == ["Morning meds", "Team stand-up", "Stretch break", "Send the status update"])
        #expect(titles(none) == ["Reply to Alex", "Call Grandma"])
        #expect(MyDayScreen(engine: day.model.engine, filter: any, now: clock.now).counts.map(\.number) == [1, 0, 1, 1])
    }

    @Test func tappingMissedListsOnlyMissedRowsAndTappingItAgainListsAll() async throws {
        let day = try await dayAtOnePM()
        var filter = MyDayFilter()

        filter.tap(.missed)
        let missed = MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now)
        #expect(missed.items.map(\.title) == ["Team stand-up"])
        // The counts cover every item the tag filter lets through, not just the chosen count.
        #expect(missed.counts.map(\.number) == [2, 1, 1, 3])

        filter.tap(.missed)
        #expect(MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now).items.count == 9)
    }

    @Test func onlyANudgingRowOffersDoneAndDoneClosesItAsDone() async throws {
        let day = try await dayAtOnePM()
        let screen = MyDayScreen(engine: day.model.engine, filter: MyDayFilter(), now: clock.now)
        #expect(screen.items.filter(\.offersDone).map(\.title) == ["Reply to Alex"])

        let alex = try #require(screen.items.first(where: { $0.offersDone }))
        day.model.markDone(alex.reminder.id)
        await day.model.waitUntilApplied()

        let after = MyDayScreen(engine: day.model.engine, filter: MyDayFilter(), now: clock.now)
        #expect(after.items.filter(\.offersDone).isEmpty)
        #expect(after.counts.map(\.number) == [3, 0, 1, 3])
        #expect(day.model.engine.closedOccurrence(of: day.alex.id, dueAt: day.alex.dueTime)?.occurrence.state == .done)
        let doneRow = try #require(after.items.first(where: { $0.title == "Reply to Alex" }))
        let note = doneRow.note(at: clock.now)
        #expect(plain(note) == "Done at 1:00\u{202F}PM after 2 nudges")
    }

    /// The mockup's `tagLine`: the tags as "#health", the ones the filter chose in bold.
    @Test func aRowsTagsMarkTheOnesTheFilterChose() async throws {
        let day = try await dayAtOnePM()
        var filter = MyDayFilter()
        filter.toggle(day.health.id)
        let screen = MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now)

        let stretch = try #require(screen.items.first(where: { $0.title == "Stretch break" }))

        #expect(stretch.tags.map(\.text) == ["#health", "#work"])
        #expect(stretch.tags.map(\.isChosen) == [true, false])
        let unfiltered = MyDayScreen(engine: day.model.engine, filter: MyDayFilter(), now: clock.now)
        #expect(unfiltered.items.first(where: { $0.title == "Stretch break" })?.tags.map(\.isChosen) == [false, false])
        #expect(unfiltered.items.first(where: { $0.title == "Reply to Alex" })?.tags.isEmpty == true)
    }

    /// The mockup's "Now, 9:07" marker sits among the rows where the time is: after Alex, due
    /// 12:30, and before the status update at 16:30. With a count chosen it sits among those rows,
    /// and an empty list has none.
    @Test func aNowMarkerSitsAmongTheRowsWhereTheTimeIs() async throws {
        let day = try await dayAtOnePM()
        func lines(_ filter: MyDayFilter) -> [String] {
            MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now).rows.map {
                switch $0 {
                case .item(let item): item.title
                case .now(let time): "Now, \(time)"
                }
            }
        }

        #expect(lines(MyDayFilter()) == [
            "Morning meds", "Walk the dog", "Team stand-up", "Stretch break", "Reply to Alex",
            "Now, 1:00\u{202F}PM",
            "Send the status update", "Call Grandma", "Water the plants", "Take the bins out",
        ])
        var missed = MyDayFilter()
        missed.tap(.missed)
        #expect(lines(missed) == ["Team stand-up", "Now, 1:00\u{202F}PM"])
        var noTags = MyDayFilter()
        noTags.toggleNoTags()
        noTags.tap(.done)
        #expect(lines(noTags).isEmpty)
    }

    /// The mockup's `countButton`: a count of 0 can't be tapped, unless it's the chosen one, so it
    /// can be turned off again.
    @Test func aCountOfZeroCantBeTappedUnlessItIsTheChosenOne() async throws {
        let day = try await dayAtOnePM()
        var filter = MyDayFilter()
        filter.toggleNoTags()
        func cells() -> [String] {
            MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now).counts.map {
                "\($0.number) \($0.isEnabled ? "enabled" : "disabled") \($0.isChosen ? "chosen" : "")"
            }
        }

        // Reply to Alex is nudging and Call Grandma is paused, so only Nudging has any.
        #expect(cells() == ["0 disabled ", "1 enabled ", "0 disabled ", "0 disabled "])

        filter.tap(.done)
        #expect(cells() == ["0 enabled chosen", "1 enabled ", "0 disabled ", "0 disabled "])
    }

    /// The line under the counts while one is chosen, a whole sentence for each, so a translation
    /// can agree the name with the rest.
    @Test(arguments: [
        (MyDayCount.done, "Showing only Done"),
        (.nudging, "Showing only Nudging"),
        (.missed, "Showing only Missed"),
        (.left, "Showing only Left"),
    ])
    func theChosenCountIsNamedInItsOwnSentence(count: MyDayCount, expected: String) {
        #expect(plain(count.showingOnly) == expected)
    }

    /// The mockup's `DAY_STATUS.empty`, for when the list has no rows. The tag filter isn't in the
    /// sentence: its tokens and summary are on screen, and gluing a clause on would build a
    /// sentence from fragments.
    @Test(arguments: [
        (nil, "Nothing is due today."),
        (MyDayCount.done, "Nothing is done yet today."),
        (.nudging, "Nothing is nudging you."),
        (.missed, "Nothing was missed today."),
        (.left, "Nothing is left to do today."),
    ] as [(MyDayCount?, String)])
    func anEmptyListSaysWhatIsNotThere(count: MyDayCount?, expected: String) async throws {
        let day = try await dayAtOnePM()
        var filter = MyDayFilter()
        if let count { filter.tap(count) }

        let screen = MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now)

        #expect(plain(screen.emptyMessage) == expected)
    }

    /// The mockup's filter tokens, one per chosen tag or "No Tags", and the line under them that
    /// says how they combine without naming them (ticket 20): "the selected tag" for one, from two
    /// on all or any by the Match setting, and "no tags" for No Tags.
    @Test func theChosenTagsShowAsTokensWithASummaryLine() async throws {
        let day = try await dayAtOnePM()
        var filter = MyDayFilter()
        func screen() -> MyDayScreen { MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now) }
        #expect(screen().filterTokens.isEmpty)
        #expect(screen().filterSummary == nil)

        filter.toggle(day.health.id)
        #expect(screen().filterTokens.map(\.tagText) == ["#health"])
        #expect(screen().filterSummary.map(plain) == "Due today with the selected tag")

        filter.toggle(day.work.id)
        #expect(screen().filterTokens.map(\.tagText) == ["#health", "#work"])
        #expect(screen().filterSummary.map(plain) == "Due today with all selected tags")
        filter.match = .any
        #expect(screen().filterSummary.map(plain) == "Due today with any selected tags")

        filter.toggleNoTags()
        #expect(screen().filterTokens.map(\.kind) == [.noTags])
        #expect(screen().filterTokens.map(\.tagText) == [nil])
        #expect(screen().filterSummary.map(plain) == "Due today with no tags")
    }

    /// A tag deleted while it's chosen is no longer a filter. Left in, Match All would need a tag
    /// nothing has and show no rows.
    @Test func aChosenTagThatWasDeletedDropsOutOfTheFilter() async throws {
        let day = try await dayAtOnePM()
        var filter = MyDayFilter()
        filter.toggle(day.home.id)
        #expect(MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now).items.map(\.title) == ["Walk the dog", "Water the plants", "Take the bins out"])

        day.model.deleteTag(day.home.id)
        await day.model.waitUntilApplied()

        let screen = MyDayScreen(engine: day.model.engine, filter: filter, now: clock.now)
        #expect(screen.items.count == 9)
        #expect(screen.filterTokens.isEmpty)
    }

    /// The mockup's `dayFilterSheet`: every tag by name with a check, No Tags, and a line saying
    /// how many are due today with the filter on. The Match control appears from two tags.
    @Test func theFilterSheetListsTheTagsAndCountsWhatTheyLeave() async throws {
        let day = try await dayAtOnePM()
        var filter = MyDayFilter()
        func sheet() -> MyDayFilterSheet { MyDayFilterSheet(engine: day.model.engine, filter: filter) }

        #expect(sheet().tags.map(\.text) == ["#health", "#home", "#work"])
        #expect(sheet().tags.map(\.isChecked) == [false, false, false])
        #expect(!sheet().showsMatch)
        #expect(plain(sheet().result) == "Showing everything due today (9).")

        filter.toggle(day.health.id)
        #expect(sheet().tags.map(\.isChecked) == [true, false, false])
        #expect(!sheet().showsMatch)
        #expect(plain(sheet().result) == "2 due today with #health.")

        filter.toggle(day.work.id)
        #expect(sheet().showsMatch)
        #expect(plain(sheet().result) == "1 due today with #health and #work.")
        filter.match = .any
        #expect(plain(sheet().result) == "4 due today with #health or #work.")

        filter.toggleNoTags()
        #expect(sheet().isNoTagsChecked)
        #expect(sheet().tags.map(\.isChecked) == [false, false, false])
        #expect(!sheet().showsMatch)
        #expect(plain(sheet().result) == "2 due today without tags.")
    }

    /// The test host and previews have no engine: My Day then shows nothing is due.
    @Test func withoutAnEngineNothingIsDue() {
        let screen = MyDayScreen(filter: MyDayFilter(), now: clock.now)

        #expect(screen.counts.map(\.number) == [0, 0, 0, 0])
        #expect(screen.rows.isEmpty)
        #expect(plain(screen.emptyMessage) == "Nothing is due today.")
    }

    /// The text as it shows, without its Markdown.
    func plain(_ resource: LocalizedStringResource) -> String {
        String(AttributedString(localized: resource).characters)
    }
}
