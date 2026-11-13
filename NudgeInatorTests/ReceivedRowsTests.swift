import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Received reminders on Now, My Day and Reminders (ticket 199, spec #127 seam 1): Alex sends
/// Riley a reminder through the fake network, and the tests read Riley's screens as Riley's app
/// model and sharing store build them, beside a reminder of Riley's own. Layout, the label's look
/// and VoiceOver are the phone check.
@MainActor
struct ReceivedRowsTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm: the phones' clocks say 8:00.
    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm
    )
    /// Riley's own, due at 8:15 every day, Gentle.
    let walk = Reminder(title: "Walk the dog", dueTime: NewYork.local(2026, 10, 15, 8, 15), repeatRule: .everyDay, strength: .gentle)

    /// Riley's phone, holding the pills Alex sent and the walk of Riley's own, at `hour`:`minute`
    /// on 15 October.
    func rileysPhone(at hour: Int, _ minute: Int) async throws -> Phone {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected),
        ]))
        network.join(alex.adapter, riley.adapter, through: connectionID)
        for phone in [alex, riley] { await phone.launch() }
        try alex.model.send(pills, to: [connectionID])
        for phone in [alex, riley] { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in [alex, riley] { await phone.model.waitUntilApplied() }
        riley.model.add(walk)
        riley.clock.now = NewYork.local(2026, 10, 15, hour, minute)
        await riley.model.appOpened()
        await riley.model.waitUntilApplied()
        return riley
    }

    func received(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    // MARK: Now

    @Test func aReceivedNudgeCardSaysWhoSentItAndAnOwnOneDoesnt() async throws {
        let riley = try await rileysPhone(at: 8, 40)

        let screen = NowScreen(engine: riley.model.engine, senders: riley.model.senders)

        let pills = try #require(screen.nudging.first { $0.title == "Take the pills" })
        let walk = try #require(screen.nudging.first { $0.title == "Walk the dog" })
        #expect(pills.from.map { String(localized: $0.label) } == "From Alex Morgan")
        #expect(walk.from == nil)
    }

    @Test func aNudgingReceivedReminderCountsTowardTheNowBadgeAndTheIconBadge() async throws {
        let riley = try await rileysPhone(at: 8, 40)

        #expect(NowScreen.badgeCount(of: riley.model.engine) == 2)
        #expect(riley.center.badgeCounts.last == 2)
    }

    @Test func aReceivedReminderComingUpSaysWhoSentIt() async throws {
        let riley = try await rileysPhone(at: 8, 5)

        let screen = NowScreen(engine: riley.model.engine, senders: riley.model.senders)

        #expect(screen.comingUp.map(\.title) == ["Walk the dog", "Take the pills"])
        let labels: [String?] = screen.comingUp.map { $0.from.map { String(localized: $0.label) } }
        #expect(labels == [nil, "From Alex Morgan"])
    }

    @Test func aReceivedReminderThatClosedSaysWhoSentIt() async throws {
        let riley = try await rileysPhone(at: 8, 40)
        riley.model.markDone(try received(on: riley).id)
        riley.model.markDone(walk.id)
        await riley.model.waitUntilApplied()

        let screen = NowScreen(engine: riley.model.engine, senders: riley.model.senders)

        let pills = try #require(screen.lastDay.first { $0.title == "Take the pills" })
        let walk = try #require(screen.lastDay.first { $0.title == "Walk the dog" })
        #expect(pills.from.map { String(localized: $0.label) } == "From Alex Morgan")
        #expect(walk.from == nil)
    }

    /// Its connection isn't in the sharing store: the received seed set without the stand-in, or a
    /// store that won't open.
    @Test func aReceivedReminderWhoseConnectionIsUnknownSaysFromSomeone() async throws {
        let riley = try await rileysPhone(at: 8, 40)

        let screen = NowScreen(engine: riley.model.engine, senders: Senders())

        let pills = try #require(screen.nudging.first { $0.title == "Take the pills" })
        #expect(pills.from.map { String(localized: $0.label) } == "From Someone")
    }

    /// The other person ended the connection and this person hasn't chosen Remove or Keep yet
    /// (spec A8): the copy keeps its sender's name. Connection Ended's sheet hides this on the
    /// phone, so only here.
    @Test func aReceivedReminderKeepsItsSendersNameAfterTheyEndTheConnection() async throws {
        let riley = try await rileysPhone(at: 8, 40)
        let ended = Senders(connections: [SharingConnection(id: connectionID, name: "Alex Morgan", state: .ended)])

        let screen = NowScreen(engine: riley.model.engine, senders: ended)

        let pills = try #require(screen.nudging.first { $0.title == "Take the pills" })
        #expect(pills.from.map { String(localized: $0.label) } == "From Alex Morgan")
    }

    // MARK: My Day

    @Test func aReceivedItemOnMyDaySaysWhoSentItAndCountsAsAnyOther() async throws {
        let riley = try await rileysPhone(at: 8, 40)
        var nudging = MyDayFilter()
        nudging.tap(.nudging)

        let screen = MyDayScreen(engine: riley.model.engine, filter: MyDayFilter(), now: riley.clock.now, senders: riley.model.senders)
        let onlyNudging = MyDayScreen(engine: riley.model.engine, filter: nudging, now: riley.clock.now, senders: riley.model.senders)

        let pills = try #require(screen.items.first { $0.title == "Take the pills" })
        let walk = try #require(screen.items.first { $0.title == "Walk the dog" })
        #expect(pills.from.map { String(localized: $0.label) } == "From Alex Morgan")
        #expect(walk.from == nil)
        #expect(pills.offersDone)
        #expect(screen.counts.first { $0.kind == .nudging }?.number == 2)
        #expect(Set(onlyNudging.items.map(\.title)) == ["Take the pills", "Walk the dog"])
    }

    /// A tag of Riley's own on the received reminder (#185 lets an edit change only its tags).
    @Test func myDaysTagFilterTreatsAReceivedReminderAsAnyOther() async throws {
        let riley = try await rileysPhone(at: 8, 40)
        let tag = try #require(try riley.model.createTag(named: "health"))
        var pills = try received(on: riley)
        pills.tagIDs = [tag.id]
        try riley.model.edit(pills)
        await riley.model.waitUntilApplied()
        var health = MyDayFilter()
        health.toggle(tag.id)
        var noTags = MyDayFilter()
        noTags.toggleNoTags()

        let tagged = MyDayScreen(engine: riley.model.engine, filter: health, now: riley.clock.now, senders: riley.model.senders)
        let untagged = MyDayScreen(engine: riley.model.engine, filter: noTags, now: riley.clock.now, senders: riley.model.senders)

        #expect(tagged.items.map(\.title) == ["Take the pills"])
        #expect(tagged.items.first?.from.map { String(localized: $0.label) } == "From Alex Morgan")
        #expect(untagged.items.map(\.title) == ["Walk the dog"])
    }

    // MARK: Reminders

    func remindersScreen(on riley: Phone, sort: RemindersSort = .createdOldestFirst, filter: RemindersFilter = RemindersFilter()) -> RemindersScreen {
        RemindersScreen(engine: riley.model.engine, sort: sort, filter: filter, senders: riley.model.senders)
    }

    @Test func aReceivedRowSaysWhoSentItAndOffersDoneWhileNudging() async throws {
        let riley = try await rileysPhone(at: 8, 40)

        let screen = remindersScreen(on: riley)

        let pills = try #require(screen.rows.first { $0.title == "Take the pills" })
        let walk = try #require(screen.rows.first { $0.title == "Walk the dog" })
        #expect(pills.from.map { String(localized: $0.label) } == "From Alex Morgan")
        #expect(walk.from == nil)
        #expect(pills.offersDone)
    }

    /// The pills (Alex's, Firm, due 8:30) and the walk (Riley's own, Gentle, due 8:15), both Nudging.
    @Test(arguments: [
        (RemindersSort.createdOldestFirst, RemindersFilter(search: "pills"), ["Take the pills"]),
        (.createdOldestFirst, RemindersFilter(strengths: [.firm]), ["Take the pills"]),
        (.createdOldestFirst, RemindersFilter(statuses: [.nudging]), ["Take the pills", "Walk the dog"]),
        (RemindersSort(field: .dueDate, order: .ascending), RemindersFilter(), ["Walk the dog", "Take the pills"]),
        (RemindersSort(field: .created, order: .descending), RemindersFilter(), ["Walk the dog", "Take the pills"]),
    ])
    func searchFiltersAndSortTreatAReceivedReminderAsAnyOther(sort: RemindersSort, filter: RemindersFilter, titles: [String]) async throws {
        let riley = try await rileysPhone(at: 8, 40)

        #expect(remindersScreen(on: riley, sort: sort, filter: filter).rows.map(\.title) == titles)
    }

    /// The swipe's Done and Delete, as the row's VoiceOver actions send them.
    @Test func doneAndDeleteOnAReceivedRowActAsOnAnyOther() async throws {
        let riley = try await rileysPhone(at: 8, 40)
        let pills = try received(on: riley)

        riley.model.markDone(pills.id)
        await riley.model.waitUntilApplied()
        // It repeats daily, so tomorrow's is next, as for a reminder of Riley's own.
        #expect(remindersScreen(on: riley).rows.first { $0.id == pills.id }?.status == .comingUp)
        #expect(MyDayScreen(engine: riley.model.engine, filter: MyDayFilter(), now: riley.clock.now).items.first { $0.reminder.id == pills.id }?.status == .due(.done))

        riley.model.delete(pills.id)
        await riley.model.waitUntilApplied()
        #expect(remindersScreen(on: riley).rows.map(\.title) == ["Walk the dog"])
    }

    @Test func aReceivedRowReadsItsSenderWithItsTitleStatusDueTimeAndTags() async throws {
        let riley = try await rileysPhone(at: 8, 40)

        let rows = remindersScreen(on: riley).rows
        let pills = try #require(rows.first { $0.title == "Take the pills" })
        let walk = try #require(rows.first { $0.title == "Walk the dog" })

        #expect(String(localized: pills.voiceOverLabel) == "Take the pills, From Alex Morgan, Firm, Nudging, Today, 8:30\u{202F}AM")
        #expect(String(localized: walk.voiceOverLabel) == "Walk the dog, Nudging, Today, 8:15\u{202F}AM")
    }

    /// A recipient's own tags on a received reminder (#185 lets an edit change only those).
    @Test func aTaggedReceivedRowReadsItsTagsAfterItsSender() async throws {
        let riley = try await rileysPhone(at: 8, 40)
        let tag = try #require(try riley.model.createTag(named: "health"))
        var pills = try received(on: riley)
        pills.tagIDs = [tag.id]
        try riley.model.edit(pills)
        await riley.model.waitUntilApplied()

        let row = try #require(remindersScreen(on: riley).rows.first { $0.id == pills.id })

        #expect(String(localized: row.voiceOverLabel) == "Take the pills, From Alex Morgan, Firm, Nudging, Today, 8:30\u{202F}AM, tags: #health")
    }

    @Test func aReceivedNudgeCardReadsItsSender() async throws {
        let riley = try await rileysPhone(at: 8, 40)

        let screen = NowScreen(engine: riley.model.engine, senders: riley.model.senders)

        let pills = try #require(screen.nudging.first { $0.title == "Take the pills" })
        let walk = try #require(screen.nudging.first { $0.title == "Walk the dog" })
        #expect(pills.voiceOverLabel.map { String(localized: $0) } == "Take the pills, From Alex Morgan")
        #expect(walk.voiceOverLabel == nil)
    }
}
