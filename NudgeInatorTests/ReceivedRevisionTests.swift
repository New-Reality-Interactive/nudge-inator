import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The sender's edit reaching a received copy (ticket 204, spec #127 seam 1): Alex sends Riley a
/// reminder and revises it with `reviseSent`, and the tests read Riley's copy, details, notifications
/// and sharing store as Riley's app model builds them. Layout and VoiceOver are the phone check.
@MainActor
struct ReceivedRevisionTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm, with notes: the phones' clocks say 8:00 on 15 October.
    let pills = Reminder(
        title: "Take the pills",
        notes: "Two with water.",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm
    )

    /// Alex and Riley, connected, Riley's Delivery mode `rileysMode`, with Riley's own reminder none.
    func phones(rileysMode: DeliveryMode = .startRightAway) async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected, theirs: ConnectionChoices(deliveryMode: rileysMode)),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(deliveryMode: rileysMode)),
        ]))
        network.join(alex.adapter, riley.adapter, through: connectionID)
        for phone in [alex, riley] { await phone.launch() }
        return (alex, riley)
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    /// Alex sends `reminder` to Riley, and both phones settle.
    func send(_ reminder: Reminder, from alex: Phone, to riley: Phone) async throws {
        try alex.model.send(reminder, to: [connectionID])
        await settle(alex, riley)
    }

    /// Alex changes the sent reminder `reminder` with `change`, and both phones settle.
    func revise(_ reminder: Reminder, from alex: Phone, to riley: Phone, _ change: (inout Reminder) -> Void) async throws {
        var edited = reminder
        change(&edited)
        try alex.model.reviseSent(edited)
        await settle(alex, riley)
    }

    func copy(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    /// Riley's phone at `hour`:`minute` on 15 October.
    func open(_ riley: Phone, at hour: Int, _ minute: Int) async {
        riley.clock.now = NewYork.local(2026, 10, 15, hour, minute)
        await riley.model.appOpened()
        await riley.model.waitUntilApplied()
    }

    // MARK: Content

    @Test func aChangeToTheTitleAndNotesReachesTheCopyAtOnce() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        try await revise(pills, from: alex, to: riley) {
            $0.title = "Take the blue pills"
            $0.notes = "Three with water."
        }

        let held = try copy(on: riley)
        #expect(held.title == "Take the blue pills")
        #expect(held.notes == "Three with water.")
        #expect(riley.model.engine.reminders.count == 1)
    }

    // MARK: While Nudging

    /// Due at 8:30 once, Firm: nudging from 8:30, so it is Nudging at 8:35.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 15, 8, 30), strength: .firm)

    /// The milliseconds the nudges' identifiers carry for `dueTime`.
    func nudgeIdentifiers(on phone: Phone, dueAt dueTime: Date) -> [String] {
        let marker = ".\(Int64((dueTime.timeIntervalSince1970 * 1000).rounded()))."
        return phone.center.pending.map(\.identifier).filter { $0.contains(marker) }
    }

    @Test func aNewDueTimeWhileNudgingClosesTheOpenOccurrenceAsSkippedAndPlansFromTheNewOne() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        await open(riley, at: 8, 35)
        let held = try copy(on: riley)
        #expect(riley.model.engine.status(of: held.id) == .nudging)
        let ringing = try #require(riley.manager.scheduled.first)
        riley.manager.ring(ringing.id)
        let newDueTime = NewYork.local(2026, 10, 15, 9, 30)

        try await revise(call, from: alex, to: riley) { $0.dueTime = newDueTime }
        await riley.model.waitUntilApplied()

        let engine = riley.model.engine
        #expect(engine.status(of: held.id) == .comingUp)
        #expect(engine.occurrence(of: held.id, dueAt: NewYork.local(2026, 10, 15, 8, 30))?.state == .skipped(reason: .paused))
        #expect(try copy(on: riley).dueTime == newDueTime)
        #expect(nudgeIdentifiers(on: riley, dueAt: NewYork.local(2026, 10, 15, 8, 30)).isEmpty)
        #expect(!nudgeIdentifiers(on: riley, dueAt: newDueTime).isEmpty)
        #expect(riley.manager.scheduled.compactMap(\.fireDate).allSatisfy { $0 >= newDueTime })
        #expect(riley.manager.stoppedIDs.contains(ringing.id))
    }

    // MARK: While waiting

    @Test func aChangeWhileTheCopyWaitsUpdatesItInPlaceAndAcceptStartsFromTheNewValues() async throws {
        let (alex, riley) = try await phones(rileysMode: .askMeFirst)
        try await send(call, from: alex, to: riley)
        await open(riley, at: 8, 35)
        let waiting = try copy(on: riley)
        let newDueTime = NewYork.local(2026, 10, 15, 9, 30)

        try await revise(call, from: alex, to: riley) {
            $0.title = "Call the dentist"
            $0.dueTime = newDueTime
        }

        let held = try copy(on: riley)
        #expect(held.id == waiting.id)
        #expect(held.isWaiting)
        #expect(held.title == "Call the dentist")
        #expect(held.dueTime == newDueTime)
        #expect(riley.model.engine.status(of: held.id) == .waiting)
        #expect(riley.center.pending.isEmpty)
        #expect(riley.manager.scheduled.isEmpty)

        riley.model.accept(held.id)
        await riley.model.waitUntilApplied()

        #expect(riley.model.engine.status(of: held.id) == .comingUp)
        #expect(!nudgeIdentifiers(on: riley, dueAt: newDueTime).isEmpty)
        #expect(nudgeIdentifiers(on: riley, dueAt: NewYork.local(2026, 10, 15, 8, 30)).isEmpty)
    }

    // MARK: A revision that isn't newer

    @Test func aRevisionDeliveredAgainOrLateChangesNothing() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try await revise(pills, from: alex, to: riley) { $0.title = "Take the blue pills" }
        let first = try #require(alex.adapter.submitted.first { $0.kind == .revise })
        var newer = pills
        newer.title = "Take the green pills"
        try alex.model.reviseSent(newer)
        await settle(alex, riley)
        #expect(try copy(on: riley).title == "Take the green pills")

        try await riley.sharing.received(first)
        await settle(riley)

        #expect(try copy(on: riley).title == "Take the green pills")
    }

    // MARK: The change note

    func details(on riley: Phone) throws -> ReminderDetails {
        try #require(ReminderDetails(engine: riley.model.engine, id: copy(on: riley).id, sharing: riley.sharing.data))
    }

    func noteLines(on riley: Phone) throws -> [String] {
        try #require(details(on: riley).received?.changeNote).lines.map { String(localized: $0) }
    }

    /// Notifications that aren't nudges: arrivals and changes, as the center holds them.
    func notices(on phone: Phone) -> [(title: String, body: String)] {
        phone.center.added.filter { !$0.identifier.hasPrefix("nudge.") }.map { ($0.content.title, $0.content.body) }
    }

    @Test func aCopyNobodyChangedHasNoNote() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        #expect(try details(on: riley).received?.changeNote == nil)
    }

    @Test func theDetailsSayWhatChangedAndWhen() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        riley.clock.now = NewYork.local(2026, 10, 15, 8, 2)

        try await revise(pills, from: alex, to: riley) { $0.dueTime = NewYork.local(2026, 10, 15, 9, 0) }

        let note = try #require(details(on: riley).received?.changeNote)
        #expect(String(localized: note.heading) == "Alex Morgan changed this · Today at 8:02\u{202F}AM")
        #expect(note.lines.map { String(localized: $0) } == ["Due time changed from 8:30\u{202F}AM to 9:00\u{202F}AM"])
    }

    /// One line per changed field, in the engine's order, each with its old and new value.
    @Test func eachChangedFieldHasItsOwnLine() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        try await revise(pills, from: alex, to: riley) {
            $0.title = "Take the blue pills"
            $0.notes = "Three with water."
            $0.dueTime = NewYork.local(2026, 10, 16, 9, 0)
            $0.repeatRule = nil
            $0.strength = .gentle
            $0.pace = .consistent(wait: 30 * 60)
            $0.breakThroughFocus = false
        }

        let lines = try noteLines(on: riley)
        #expect(lines == [
            "Title changed from “Take the pills” to “Take the blue pills”",
            "Notes changed",
            "Due time changed from Today at 8:30\u{202F}AM to Tomorrow at 9:00\u{202F}AM",
            "Repeat changed from Every day at 8:30\u{202F}AM to Never",
            "Strength changed from Firm to Gentle",
            "Pace changed from Escalating to Consistent · 30 min",
            "Break Through Focus turned off",
        ])
    }

    @Test func aLaterChangeReplacesTheNote() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try await revise(pills, from: alex, to: riley) { $0.dueTime = NewYork.local(2026, 10, 15, 9, 0) }
        var changed = pills
        changed.dueTime = NewYork.local(2026, 10, 15, 9, 0)

        try await revise(changed, from: alex, to: riley) { $0.strength = .gentle }

        #expect(try noteLines(on: riley) == ["Strength changed from Firm to Gentle"])
    }

    @Test func theNoteSurvivesARelaunchAndRemoveForgetsIt() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try await revise(pills, from: alex, to: riley) { $0.strength = .gentle }

        riley.relaunch()
        await riley.launch()
        #expect(try noteLines(on: riley) == ["Strength changed from Firm to Gentle"])

        riley.model.delete(try copy(on: riley).id)
        #expect(riley.sharing.data.receivedSyncStates.isEmpty)
    }

    @Test func aWaitingCopyTakesTheNoteToo() async throws {
        let (alex, riley) = try await phones(rileysMode: .askMeFirst)
        try await send(call, from: alex, to: riley)

        try await revise(call, from: alex, to: riley) { $0.title = "Call the dentist" }

        #expect(try details(on: riley).isWaiting)
        #expect(try noteLines(on: riley) == ["Title changed from “Call the clinic” to “Call the dentist”"])
    }

    // MARK: The notification

    @Test func aChangePostsOneNotificationNamingTheSenderAndWhatChanged() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        try await revise(pills, from: alex, to: riley) { $0.dueTime = NewYork.local(2026, 10, 15, 9, 0) }

        let notices = notices(on: riley)
        #expect(notices.count == 2)
        #expect(notices.last?.title == "Take the pills")
        #expect(notices.last?.body == "Alex Morgan changed this: due time changed from 8:30\u{202F}AM to 9:00\u{202F}AM")
        #expect(self.notices(on: alex).isEmpty)
    }

    @Test func severalChangesAreOneNotificationListingThemAll() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        try await revise(pills, from: alex, to: riley) {
            $0.title = "Take the blue pills"
            $0.strength = .gentle
        }

        #expect(notices(on: riley).last?.title == "Take the blue pills")
        #expect(notices(on: riley).last?.body == "Alex Morgan changed this: title changed from “Take the pills” to “Take the blue pills” and strength changed from Firm to Gentle")
    }

    @Test func aRevisionThatChangesNothingPostsNothing() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let before = notices(on: riley).count
        let first = try #require(alex.adapter.submitted.first { $0.kind == .send })

        try await riley.sharing.received(first)
        await settle(riley)

        #expect(notices(on: riley).count == before)
        #expect(try details(on: riley).received?.changeNote == nil)
    }
}
