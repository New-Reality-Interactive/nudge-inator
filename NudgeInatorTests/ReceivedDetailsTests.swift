import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A received reminder's arrival and details (ticket 200, spec #127 seam 1): Alex sends Riley a
/// reminder through the fake network, and the tests read Riley's notification, details and form as
/// Riley's app model and sharing store build them. Layout and VoiceOver are the phone check.
@MainActor
struct ReceivedDetailsTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm, with notes: the phones' clocks say 8:00.
    let pills = Reminder(
        title: "Take the pills",
        notes: "Two with water.",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm
    )

    /// Alex's and Riley's phones, connected, with Riley's Status sharing as `sharesStatus`, before
    /// anything is sent.
    func phones(sharesStatus: Bool = true) async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(sharesStatus: sharesStatus)),
        ]))
        network.join(alex.adapter, riley.adapter, through: connectionID)
        for phone in [alex, riley] { await phone.launch() }
        return (alex, riley)
    }

    /// Alex sends `reminder` to Riley, and both phones settle.
    func send(_ reminder: Reminder, from alex: Phone, to riley: Phone) async throws {
        try alex.model.send(reminder, to: [connectionID])
        await settle(alex, riley)
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    func received(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    /// The notifications that aren't nudges: the arrivals.
    func arrivals(on phone: Phone) -> [(title: String, body: String)] {
        phone.center.added.filter { !$0.identifier.hasPrefix("nudge.") }.map { ($0.content.title, $0.content.body) }
    }

    // MARK: Arrival

    @Test func anArrivalPostsANotificationNamingTheSenderAndTheStrength() async throws {
        let (alex, riley) = try await phones()

        try await send(pills, from: alex, to: riley)

        let arrivals = arrivals(on: riley)
        #expect(arrivals.map(\.title) == ["Take the pills"])
        #expect(arrivals.map(\.body) == ["From Alex Morgan · Firm: rings as an alarm from nudge 4"])
        #expect(self.arrivals(on: alex).isEmpty)
    }

    @Test func aRelentlessArrivalSaysItRingsUntilMarkedDone() async throws {
        let (alex, riley) = try await phones()
        var relentless = pills
        relentless.strength = .relentless

        try await send(relentless, from: alex, to: riley)

        #expect(arrivals(on: riley).map(\.body) == ["From Alex Morgan · Relentless: rings an alarm until you mark it done"])
    }

    @Test func aSendDeliveredTwicePostsOneArrival() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        let send = try #require(alex.adapter.submitted.first)
        try await riley.sharing.received(send)
        await settle(riley)

        #expect(arrivals(on: riley).count == 1)
    }

    // MARK: Details

    func details(of reminderID: Reminder.ID, on phone: Phone) throws -> ReminderDetails {
        try #require(ReminderDetails(engine: phone.model.engine, id: reminderID, sharing: phone.sharing.data))
    }

    @Test func detailsSayWhoSentItItsStrengthInWordsAndItsNotes() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        let details = try details(of: received(on: riley).id, on: riley)

        let received = try #require(details.received)
        #expect(String(localized: received.from) == "From Alex Morgan")
        #expect(received.senderName == "Alex Morgan")
        #expect(String(localized: received.strengthLine.text) == "Firm: rings as an alarm from nudge 4")
        #expect(details.notes == "Two with water.")
    }

    @Test func detailsOfAnOwnReminderAreAsBefore() async throws {
        let (_, riley) = try await phones()
        riley.model.add(pills)
        await settle(riley)

        let details = try details(of: pills.id, on: riley)

        #expect(details.received == nil)
        #expect(details.notes == "Two with water.")
    }

    @Test(arguments: [true, false])
    func detailsOfferDontShareThisOneOnlyWhileStatusSharingIsOn(sharesStatus: Bool) async throws {
        let (alex, riley) = try await phones(sharesStatus: sharesStatus)
        try await send(pills, from: alex, to: riley)

        let details = try details(of: received(on: riley).id, on: riley)

        #expect(details.received?.notSharingThisOne == (sharesStatus ? false : nil))
    }

    @Test func dontShareThisOneIsKeptAndOutlivesARelaunch() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let copy = try received(on: riley)
        let outbox = riley.sharing.data.outbox.count

        try riley.model.setNotSharing(true, for: copy.id)
        riley.relaunch()
        await riley.launch()

        #expect(try details(of: copy.id, on: riley).received?.notSharingThisOne == true)
        // Its effect on what Alex sees is the status tickets': nothing is sent yet.
        #expect(riley.sharing.data.outbox.count == outbox)

        try riley.model.setNotSharing(false, for: copy.id)
        #expect(try details(of: copy.id, on: riley).received?.notSharingThisOne == false)
    }

    // MARK: Remove

    @Test func removeDeletesTheCopyItsNudgesAndItsSyncState() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        riley.clock.now = NewYork.local(2026, 10, 15, 8, 40)
        await riley.model.appOpened()
        await settle(riley)
        let copy = try received(on: riley)
        #expect(!riley.center.pending.isEmpty)
        #expect(riley.center.delivered == ["arrival.\(copy.id.uuidString)"])

        riley.model.delete(copy.id)
        await settle(riley)

        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.center.pending.isEmpty)
        #expect(riley.center.delivered.isEmpty)
        #expect(riley.manager.scheduled.isEmpty)
        #expect(riley.sharing.data.receivedSyncStates.isEmpty)
    }

    // MARK: Form

    func editForm(of reminderID: Reminder.ID, on phone: Phone) throws -> ReminderForm {
        let model = phone.model!
        return try #require(ReminderForm(engine: { model.engine }, editing: reminderID, now: { phone.clock.now }, senders: model.senders))
    }

    @Test func theFormOfACopyLetsOnlyItsTagsChangeAndNamesTheSenderAsOwner() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let copy = try received(on: riley)

        let form = try editForm(of: copy.id, on: riley)

        #expect(form.senderName == "Alex Morgan")
        #expect(form.isContentLocked)
        #expect(form.lockedFields == Set(LockedField.allCases))
    }

    @Test func aTagChangeOnACopySavesAndNothingElseDoes() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let copy = try received(on: riley)
        let form = try editForm(of: copy.id, on: riley)

        form.addTag(named: "health")
        form.title = "Skip the pills"
        form.notes = ""

        #expect(form.save(to: riley.model))
        let saved = try received(on: riley)
        #expect(riley.model.engine.tagLabels(for: saved.tagIDs) == ["#health"])
        #expect(saved.title == "Take the pills")
        #expect(saved.notes == "Two with water.")
    }

    @Test func theFormOfAnOwnReminderIsAsBefore() async throws {
        let (_, riley) = try await phones()
        riley.model.add(pills)
        await settle(riley)

        let form = try editForm(of: pills.id, on: riley)

        #expect(form.senderName == nil)
        #expect(!form.isContentLocked)
        #expect(form.lockedFields.isEmpty)
    }
}
