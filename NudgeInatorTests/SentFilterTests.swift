import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Sent's Filter (ticket 329, spec #127 seam 1): Alex sends reminders to Riley and Sam through the
/// fake network, and the tests read Alex's Sent with a filter applied. The sheet's layout, the
/// Filter button and its menu are the phone check.
@MainActor
struct SentFilterTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let rileyID = UUID()
    let samID = UUID()

    /// Due at 8:30 every day, Firm: the phones' clocks say 8:00 on 15 October.
    let pills = Reminder(title: "Take the pills", notes: "Two with water", dueTime: NewYork.local(2026, 10, 15, 8, 30), repeatRule: .everyDay, strength: .firm)
    /// Due at 9:00 tomorrow, once, Gentle.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 16, 9, 0), strength: .gentle)
    /// Due at 7:00 on 20 October, once, Relentless.
    let walk = Reminder(title: "Walk the dog", notes: "Bring water", dueTime: NewYork.local(2026, 10, 20, 7, 0), strength: .relentless)

    struct Phones {
        let alex: Phone
        let riley: Phone
        let sam: Phone
    }

    /// Alex, connected to Riley and Sam, both sharing status, having sent the pills to both, then the
    /// call to Sam, then the walk to Riley and Sam, a minute apart.
    func alexHavingSent() async throws -> Phones {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: rileyID, name: "Riley Park", state: .connected),
            SharingConnection(id: samID, name: "Sam Rivera", state: .connected),
        ]))
        let riley = try Phone(seed: SharingData(connections: [SharingConnection(id: rileyID, name: "Alex Morgan", state: .connected)]))
        let sam = try Phone(seed: SharingData(connections: [SharingConnection(id: samID, name: "Alex Morgan", state: .connected)]))
        network.join(alex.adapter, riley.adapter, through: rileyID)
        network.join(alex.adapter, sam.adapter, through: samID)
        for phone in [alex, riley, sam] { await phone.launch() }
        try alex.model.send(pills, to: [rileyID, samID])
        alex.clock.now += 60
        try alex.model.send(call, to: [samID])
        alex.clock.now += 60
        try alex.model.send(walk, to: [rileyID, samID])
        let phones = Phones(alex: alex, riley: riley, sam: sam)
        await settle(phones)
        return phones
    }

    func settle(_ phones: Phones) async {
        let all = [phones.alex, phones.riley, phones.sam]
        for phone in all { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in all { await phone.model.waitUntilApplied() }
    }

    func sent(on alex: Phone, filter: SentFilterChoices = SentFilterChoices(), search: String = "") -> SentScreen {
        SentScreen(engine: alex.model.engine, sharing: alex.model.sharing?.data ?? SharingData(), tools: SentTools(search: search, filter: filter))
    }

    func titles(_ screen: SentScreen) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: screen.people.map { ($0.name, $0.rows.map(\.title)) })
    }

    // MARK: People

    @Test func peopleKeepsOnlyTheCheckedPeoplesGroups() async throws {
        let phones = try await alexHavingSent()
        var filter = SentFilterChoices()
        filter.toggle(person: samID)

        let screen = sent(on: phones.alex, filter: filter)

        #expect(titles(screen) == ["Sam Rivera": ["Take the pills", "Call the clinic", "Walk the dog"]])
        #expect(String(localized: screen.countText) == "3 reminders out of 3")
    }

    // MARK: Status

    /// At 8:35 Riley marks the pills Done, so Riley's copy reads Coming up (tomorrow's), while Sam's
    /// is still Nudging. Each person's copy is matched by its own status, so one person's doesn't
    /// hide or show another's row of the same reminder.
    @Test func statusMatchesEachPersonsCopyOnItsOwn() async throws {
        let phones = try await alexHavingSent()
        for phone in [phones.riley, phones.sam] {
            phone.clock.now = NewYork.local(2026, 10, 15, 8, 35)
            await phone.model.appOpened()
        }
        let rileysPills = try #require(phones.riley.model.engine.reminders.first { $0.isReceived && $0.title == pills.title })
        phones.riley.model.markDone(rileysPills.id)
        await settle(phones)

        var nudging = SentFilterChoices()
        nudging.toggle(.reported(.nudging))
        #expect(titles(sent(on: phones.alex, filter: nudging)) == ["Sam Rivera": ["Take the pills"]])

        var comingUp = SentFilterChoices()
        comingUp.toggle(.reported(.comingUp))
        #expect(titles(sent(on: phones.alex, filter: comingUp)) == [
            "Riley Park": ["Take the pills", "Walk the dog"],
            "Sam Rivera": ["Call the clinic", "Walk the dog"],
        ])

        var either = nudging
        either.toggle(.reported(.comingUp))
        #expect(titles(sent(on: phones.alex, filter: either)) == titles(sent(on: phones.alex)))
    }

    /// Copies in the states a row shows, each with the one Status choice it matches. Waiting to
    /// sync, Waiting to accept and Not sharing are what the row shows in place of a status.
    nonisolated static let copiesAndTheirStatus: [(copy: SentCopyState, status: SentFilterChoices.Status)] = [
        (SentCopyState(delivery: .delivered, status: .reported(.paused, history: []), waitingToSync: true), .waitingToSync),
        (SentCopyState(delivery: .notDelivered, status: .notReportedYet, waitingToSync: true), .waitingToSync),
        (SentCopyState(delivery: .waitingForAcceptance, status: .notReportedYet), .waitingToAccept),
        (SentCopyState(delivery: .waitingForAcceptance, status: .notSharingStatus), .waitingToAccept),
        (SentCopyState(delivery: .delivered, status: .notSharingStatus), .notSharing),
        (SentCopyState(delivery: .delivered, status: .notSharingThisOne), .notSharing),
        (SentCopyState(delivery: .delivered, status: .reported(.removed, history: [])), .reported(.removed)),
        (SentCopyState(delivery: .delivered, status: .reported(.missed, history: [])), .reported(.missed)),
        (SentCopyState(delivery: .delivered, status: .reported(.nudging, history: [])), .reported(.nudging)),
    ]

    /// Each copy against every choice: only its own matches.
    @Test(arguments: copiesAndTheirStatus.indices, SentFilterChoices.Status.allCases)
    func aCopyMatchesOnlyTheStatusItsRowShows(copy index: Int, choice: SentFilterChoices.Status) {
        let (copy, status) = Self.copiesAndTheirStatus[index]
        var filter = SentFilterChoices()
        filter.toggle(choice)
        #expect(filter.matches(copy) == (choice == status))
    }

    @Test(arguments: [
        SentCopyState(delivery: .notDelivered, status: .notReportedYet),
        SentCopyState(delivery: .delivered, status: .notReportedYet),
    ])
    func aCopyWithNoStatusYetMatchesNoStatusChoice(state: SentCopyState) {
        let every = SentFilterChoices.Status.allCases.reduce(into: SentFilterChoices()) { $0.toggle($1) }
        #expect(!every.matches(state))
        #expect(SentFilterChoices().matches(state))
    }

    // MARK: Strength and Due Date

    @Test func strengthKeepsTheRemindersWithAnyCheckedStrength() async throws {
        let phones = try await alexHavingSent()
        var filter = SentFilterChoices()
        filter.toggle(.relentless)
        filter.toggle(.gentle)

        #expect(titles(sent(on: phones.alex, filter: filter)) == [
            "Riley Park": ["Walk the dog"],
            "Sam Rivera": ["Call the clinic", "Walk the dog"],
        ])
    }

    /// By the day of the due time each row shows, both days included: the pills' next is 8:30 today,
    /// the call's tomorrow, the walk's on 20 October.
    @Test func dueDateKeepsTheRowsDueFromTheFirstDayToTheLastBothIncluded() async throws {
        let phones = try await alexHavingSent()
        var tomorrow = SentFilterChoices()
        tomorrow.setDueFrom(CalendarDay(year: 2026, month: 10, day: 16))
        tomorrow.setDueTo(CalendarDay(year: 2026, month: 10, day: 16))
        #expect(titles(sent(on: phones.alex, filter: tomorrow)) == ["Sam Rivera": ["Call the clinic"]])

        var fromTomorrow = SentFilterChoices()
        fromTomorrow.setDueFrom(CalendarDay(year: 2026, month: 10, day: 16))
        #expect(titles(sent(on: phones.alex, filter: fromTomorrow)) == [
            "Riley Park": ["Walk the dog"],
            "Sam Rivera": ["Call the clinic", "Walk the dog"],
        ])

        var untilToday = SentFilterChoices()
        untilToday.setDueTo(CalendarDay(year: 2026, month: 10, day: 15))
        #expect(titles(sent(on: phones.alex, filter: untilToday)) == ["Riley Park": ["Take the pills"], "Sam Rivera": ["Take the pills"]])
    }

    @Test func theFirstDayCantPassTheLastNorTheLastTheFirst() {
        var filter = SentFilterChoices()
        filter.setDueTo(CalendarDay(year: 2026, month: 10, day: 16))
        filter.setDueFrom(CalendarDay(year: 2026, month: 10, day: 20))
        #expect(filter.dueFrom == CalendarDay(year: 2026, month: 10, day: 16))
        filter.setDueTo(CalendarDay(year: 2026, month: 10, day: 10))
        #expect(filter.dueTo == CalendarDay(year: 2026, month: 10, day: 16))
    }

    // MARK: Together

    /// Sections narrow together; the count's "out of" stays every reminder sent.
    @Test func theSectionsNarrowTogetherAndOnlyTheFirstNumberOfTheCountFollows() async throws {
        let phones = try await alexHavingSent()
        var filter = SentFilterChoices()
        filter.toggle(person: rileyID)
        filter.toggle(.firm)
        filter.toggle(.relentless)
        filter.setDueFrom(CalendarDay(year: 2026, month: 10, day: 16))

        let screen = sent(on: phones.alex, filter: filter)

        #expect(titles(screen) == ["Riley Park": ["Walk the dog"]])
        #expect(String(localized: screen.countText) == "1 reminder out of 3")
    }

    // MARK: No match

    /// The mockup's `sentNoMatch`: a search alone has Mine's words, and filters their own.
    @Test(arguments: [
        ("", true, "No Matches", "No sent reminders with these filters.", "Clear Filters", "line.3.horizontal.decrease"),
        ("zebra", true, "No Results for “zebra”", "No sent reminders with these filters match this search.", "Clear Search and Filters", "magnifyingglass"),
        ("zebra", false, "No Results for “zebra”", "Check the spelling or try a new search.", "Clear Search", "magnifyingglass"),
    ])
    func filtersAndSearchMatchingNothingAreNoMatchWithItsWords(search: String, filtered: Bool, title: String, text: String, clear: String, image: String) async throws {
        let phones = try await alexHavingSent()
        var filter = SentFilterChoices()
        if filtered {
            filter.toggle(person: rileyID)
            filter.toggle(.gentle)
        }

        let screen = sent(on: phones.alex, filter: filter, search: search)

        #expect(screen.emptyState == .noMatch)
        #expect(screen.people.isEmpty)
        #expect(String(localized: screen.noMatch.noMatchTitle) == title)
        #expect(screen.noMatch.noMatchText.map { String(localized: $0) } == text)
        #expect(String(localized: screen.noMatch.noMatchClearTitle) == clear)
        #expect(screen.noMatch.noMatchSystemImage == image)
        #expect(String(localized: screen.countText) == "0 reminders out of 3")
    }

    /// A filter left over can't turn Sent's two empty states into No Matches.
    @Test func aFilterLeavesSentsEmptyStatesAsTheyAre() async throws {
        let alone = try Phone(seed: SharingData())
        await alone.launch()
        let connected = try Phone(seed: SharingData(connections: [SharingConnection(id: rileyID, name: "Riley Park", state: .connected)]))
        await connected.launch()
        var filter = SentFilterChoices()
        filter.toggle(.reported(.done))

        #expect(sent(on: alone, filter: filter).emptyState == .noOneToSendTo)
        #expect(sent(on: connected, filter: filter).emptyState == .nothingSent)
    }

    // MARK: The sheet

    func sheet(on alex: Phone, draft: SentFilterChoices, applied: SentFilterChoices = SentFilterChoices(), search: String = "") -> SentFilterSheet {
        SentFilterSheet(engine: alex.model.engine, sharing: alex.model.sharing?.data ?? SharingData(), draft: draft, applied: applied, search: search)
    }

    /// Everyone connected, in the groups' order, whether or not anything went to them. An invite not
    /// yet accepted isn't anyone to filter by.
    @Test func peopleListsEveryoneConnectedInTheGroupsOrder() async throws {
        let avaID = UUID()
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: samID, name: "Sam Rivera", state: .connected),
            SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited),
            SharingConnection(id: avaID, name: "ava Chen", state: .connected),
            SharingConnection(id: rileyID, name: "Riley Park", state: .connected),
        ]))
        await alex.launch()
        var draft = SentFilterChoices()
        draft.toggle(person: rileyID)

        let people = sheet(on: alex, draft: draft).people

        #expect(people.map(\.name) == ["ava Chen", "Riley Park", "Sam Rivera"])
        #expect(people.map(\.id) == [avaID, rileyID, samID])
        #expect(people.map(\.isChosen) == [false, true, false])
    }

    /// The footer counts reminders, each once, with the search as it is.
    @Test func applyShowsHowManyRemindersTheDraftWouldShowWithTheSearch() async throws {
        let phones = try await alexHavingSent()
        var draft = SentFilterChoices()
        draft.toggle(.gentle)
        draft.toggle(.relentless)

        #expect(String(localized: sheet(on: phones.alex, draft: SentFilterChoices()).result) == "Apply shows 3 reminders.")
        #expect(String(localized: sheet(on: phones.alex, draft: draft).result) == "Apply shows 2 reminders.")
        #expect(String(localized: sheet(on: phones.alex, draft: draft, search: "water").result) == "Apply shows 1 reminder.")
    }

    @Test func cancelAsksAndResetIsOnOnlyWhenTheyHaveSomethingToDo() async throws {
        let phones = try await alexHavingSent()
        var applied = SentFilterChoices()
        applied.toggle(.firm)

        let unchanged = sheet(on: phones.alex, draft: applied, applied: applied)
        #expect(!unchanged.hasChanges)
        #expect(unchanged.canReset)

        let reset = sheet(on: phones.alex, draft: SentFilterChoices(), applied: applied)
        #expect(reset.hasChanges)
        #expect(!reset.canReset)

        var toggledBack = applied
        toggledBack.toggle(.reported(.done))
        toggledBack.toggle(.reported(.done))
        #expect(!sheet(on: phones.alex, draft: toggledBack, applied: applied).hasChanges)
    }

    @Test func theBadgeCountsTheSectionsInUseNotTheChoices() {
        var filter = SentFilterChoices()
        #expect(filter.sectionsInUse == 0)
        filter.toggle(person: rileyID)
        filter.toggle(person: samID)
        #expect(filter.sectionsInUse == 1)
        filter.toggle(.reported(.done))
        filter.toggle(.notSharing)
        #expect(filter.sectionsInUse == 2)
        filter.toggle(.firm)
        #expect(filter.sectionsInUse == 3)
        filter.setDueTo(CalendarDay(year: 2026, month: 10, day: 16))
        #expect(filter.sectionsInUse == 4)
    }

    /// As a deleted tag leaves Mine's: a person no longer connected can't keep Sent narrowed to no one.
    @Test func aPersonNoLongerConnectedLeavesTheFilter() {
        var filter = SentFilterChoices()
        filter.toggle(person: rileyID)
        filter.toggle(person: samID)
        let sharing = SharingData(connections: [
            SharingConnection(id: rileyID, name: "Riley Park", state: .ended),
            SharingConnection(id: samID, name: "Sam Rivera", state: .connected),
        ])

        let kept = filter.keepingConnectedPeople(in: sharing)

        #expect(!kept.isChosen(person: rileyID))
        #expect(kept.isChosen(person: samID))
        #expect(kept.sectionsInUse == 1)
    }
}
