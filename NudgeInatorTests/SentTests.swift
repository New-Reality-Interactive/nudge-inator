import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Reminders tab's Sent view and a sent reminder's details (ticket 201, spec #127 seam 1): Alex
/// sends reminders to Riley and Sam through the fake network, and the tests read Alex's side as
/// Alex's app model and sharing store build it. Layout, the segmented control and VoiceOver are the
/// phone check.
@MainActor
struct SentTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let rileyID = UUID()
    let samID = UUID()

    /// Alex, connected to Riley and Sam, and both of them, launched and joined by the network, at
    /// 8:00 on 15 October. `rileySharesStatus` is Riley's Status sharing with Alex.
    func phones(rileySharesStatus: Bool = true) async throws -> (alex: Phone, riley: Phone, sam: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: rileyID, name: "Riley Park", state: .connected, theirs: ConnectionChoices(sharesStatus: rileySharesStatus)),
            SharingConnection(id: samID, name: "Sam Rivera", state: .connected),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: rileyID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(sharesStatus: rileySharesStatus)),
        ]))
        let sam = try Phone(seed: SharingData(connections: [
            SharingConnection(id: samID, name: "Alex Morgan", state: .connected),
        ]))
        network.join(alex.adapter, riley.adapter, through: rileyID)
        network.join(alex.adapter, sam.adapter, through: samID)
        for phone in [alex, riley, sam] { await phone.launch() }
        return (alex, riley, sam)
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    func sent(on alex: Phone) -> SentScreen {
        SentScreen(engine: alex.model.engine, sharing: alex.model.sharing?.data ?? SharingData())
    }

    /// Due at 8:30 every day, Firm: the phones' clocks say 8:00.
    let pills = Reminder(
        title: "Take the pills",
        notes: "Two with water",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm,
        pace: .consistent(wait: 10 * 60)
    )
    /// Due at 9:00 today, once, Gentle.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 15, 9, 0), strength: .gentle)

    // MARK: Sent

    @Test func aReminderSentToTwoPeopleShowsUnderEachDeliveredOnceTheirCopiesArrive() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID, samID])
        await settle(alex, riley, sam)

        let screen = sent(on: alex)

        #expect(screen.people.map(\.name) == ["Riley Park", "Sam Rivera"])
        for person in screen.people {
            #expect(person.rows.map(\.title) == ["Take the pills"])
            #expect(person.rows.map(\.isDelivered) == [true])
            #expect(person.rows.map(\.time) == ["8:30\u{202F}AM"])
            #expect(person.rows.map(\.day) == ["Today"])
        }
    }

    @Test func aCopyThatHasntArrivedIsNotDeliveredYet() async throws {
        let (alex, riley, sam) = try await phones()
        network.holdsDeliveries = true
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)

        let row = try #require(sent(on: alex).people.first?.rows.first)

        #expect(!row.isDelivered)
        #expect(String(localized: row.voiceOverLabel) == "Riley Park, Take the pills, Not delivered yet, Today, 8:30\u{202F}AM")
    }

    @Test func aCopyIsDeliveredWhateverTheRecipientsStatusSharing() async throws {
        let (alex, riley, sam) = try await phones(rileySharesStatus: false)
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)

        let row = try #require(sent(on: alex).people.first?.rows.first)

        #expect(row.isDelivered)
        #expect(String(localized: row.voiceOverLabel) == "Riley Park, Take the pills, Delivered, Today, 8:30\u{202F}AM")
    }

    /// Each person's reminders in the order they were sent, the read-out's.
    @Test func eachPersonsRowsAreTheirsInTheOrderSent() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID, samID])
        alex.clock.now += 60
        try alex.model.send(call, to: [samID])
        await settle(alex, riley, sam)

        let screen = sent(on: alex)

        #expect(screen.people.map { $0.rows.map(\.title) } == [["Take the pills"], ["Take the pills", "Call the clinic"]])
    }

    @Test func aRepeatingRowShowsItsNextDueTimeAndAOneOffThatCameDueItsStart() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID])
        alex.clock.now += 60
        try alex.model.send(call, to: [rileyID])
        await settle(alex, riley, sam)
        alex.clock.now = NewYork.local(2026, 10, 15, 10, 0)

        let rows = try #require(sent(on: alex).people.first?.rows)

        #expect(rows.map(\.day) == ["Tomorrow", "Today"])
        #expect(rows.map(\.time) == ["8:30\u{202F}AM", "9:00\u{202F}AM"])
    }

    @Test func sentHoldsNothingOfTheSendersOwnAndMineHoldsNothingSent() async throws {
        let (alex, riley, sam) = try await phones()
        alex.model.add(call)
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)

        let mine = RemindersScreen(engine: alex.model.engine, senders: alex.model.senders)

        #expect(sent(on: alex).people.flatMap(\.rows).map(\.title) == ["Take the pills"])
        #expect(mine.rows.map(\.title) == ["Call the clinic"])
    }

    /// Someone the sender is no longer connected with, or only invited, has no group.
    @Test func onlyConnectedPeopleHaveAGroup() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID, samID])
        await settle(alex, riley, sam)
        var data = try #require(alex.model.sharing?.data)
        data.connections = data.connections.map { connection in
            var connection = connection
            if connection.id == samID { connection.state = .ended }
            return connection
        }

        let screen = SentScreen(engine: alex.model.engine, sharing: data)

        #expect(screen.people.map(\.name) == ["Riley Park"])
    }

    // MARK: Empty states (ticket 202)

    /// With no one connected, Sent offers an invite: someone only invited can't be sent anything yet.
    @Test func withNoOneConnectedSentHasNoOneToSendTo() async throws {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: rileyID, name: "Riley Park", state: .invited),
        ]))
        await alex.launch()

        #expect(sent(on: alex).emptyState == .noOneToSendTo)
    }

    /// Connected, with nothing sent to anyone still connected: Sent offers New Reminder. What went
    /// to someone since ended doesn't count.
    @Test func withSomeoneConnectedAndNothingSentToThemSentHasNothingSent() async throws {
        let (alex, riley, sam) = try await phones()
        #expect(sent(on: alex).emptyState == .nothingSent)

        try alex.model.send(pills, to: [samID])
        await settle(alex, riley, sam)
        var data = try #require(alex.model.sharing?.data)
        data.connections = data.connections.map { connection in
            var connection = connection
            if connection.id == samID { connection.state = .ended }
            return connection
        }

        #expect(SentScreen(engine: alex.model.engine, sharing: data).emptyState == .nothingSent)
    }

    @Test func anythingSentToSomeoneConnectedHasNoEmptyState() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)

        #expect(sent(on: alex).emptyState == nil)
    }

    // MARK: Details

    func details(of reminderID: Reminder.ID, on alex: Phone) -> SentReminderDetails? {
        SentReminderDetails(engine: alex.model.engine, sharing: alex.model.sharing?.data ?? SharingData(), id: reminderID)
    }

    @Test func theDetailsShowTheReminderEachRecipientWithDeliveredAndTheSchedule() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [samID, rileyID])
        await settle(alex, riley, sam)

        let details = try #require(details(of: pills.id, on: alex))

        #expect(details.title == "Take the pills")
        #expect(details.notes == "Two with water")
        #expect(details.strength == .firm)
        #expect(details.recipients.map(\.name) == ["Riley Park", "Sam Rivera"])
        #expect(details.repeats == "Every day at 8:30\u{202F}AM")
        #expect(details.next == .at(day: "Today", time: "8:30\u{202F}AM"))
        #expect(details.pace == .consistent(wait: 10 * 60))
        #expect(details.breaksThroughFocus)
    }

    @Test func theDetailsSayWhichCopiesHaveArrived() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)
        network.holdsDeliveries = true
        try alex.model.send(call, to: [rileyID, samID])
        await settle(alex, riley, sam)

        let delivered = try #require(details(of: pills.id, on: alex))
        let onTheirWay = try #require(details(of: call.id, on: alex))

        #expect(delivered.recipients.map(\.isDelivered) == [true])
        #expect(onTheirWay.recipients.map(\.isDelivered) == [false, false])
    }

    @Test func aOneOffThatCameDueHasNoNextTime() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(call, to: [rileyID])
        await settle(alex, riley, sam)
        alex.clock.now = NewYork.local(2026, 10, 15, 10, 0)

        let details = try #require(details(of: call.id, on: alex))

        #expect(details.next == .none)
        #expect(details.repeats == "Once, Today at 9:00\u{202F}AM")
    }

    @Test func aReminderTheSenderOwnsOrNeverSentHasNoSentDetails() async throws {
        let (alex, _, _) = try await phones()
        alex.model.add(call)

        #expect(details(of: call.id, on: alex) == nil)
        #expect(details(of: UUID(), on: alex) == nil)
    }
}

extension SentTests {
    // MARK: Delete

    @Test func deletingASentReminderTakesItOffSentAndCancelsEachCopy() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID, samID])
        try alex.model.send(call, to: [rileyID])
        await settle(alex, riley, sam)

        try alex.model.deleteSent(pills.id)
        await settle(alex, riley, sam)

        #expect(sent(on: alex).people.map { $0.rows.map(\.title) } == [["Call the clinic"]])
        #expect(details(of: pills.id, on: alex) == nil)
        let cancels = alex.adapter.submitted.filter { $0.kind == .cancel }
        #expect(Set(cancels.map(\.connectionID)) == [rileyID, samID])
        #expect(cancels.allSatisfy { $0.reminderID == pills.id })
        #expect(alex.sharing.data.sentCopies.allSatisfy { $0.reminderID != pills.id })
    }

    @Test func aDeleteTheStoreWontKeepChangesAndSendsNothing() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)
        let submitted = alex.adapter.submitted.count
        alex.sharingStoreOpens = false
        alex.relaunch()

        #expect(throws: (any Error).self) { try alex.model.deleteSent(pills.id) }

        #expect(alex.adapter.submitted.count == submitted)
        alex.sharingStoreOpens = true
        alex.relaunch()
        await alex.launch()
        #expect(details(of: pills.id, on: alex) != nil)
    }
}

extension SentTests {
    // MARK: Edit

    func editForm(of reminderID: Reminder.ID, on alex: Phone) throws -> ReminderForm {
        let sent = try #require(alex.sharing.data.sentReminders.first { $0.reminder.id == reminderID })
        return ReminderForm(engine: { alex.model.engine }, editingSent: sent.reminder, now: { alex.clock.now })
    }

    /// A sent reminder has no tags, goes to the people it went to, and isn't nudging the sender,
    /// so nothing on its form is locked: a sender's change passes the copies' lock (ADR 0005).
    @Test func aSentRemindersFormHasNoTagsNoSendToAndNoLock() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)
        alex.clock.now = NewYork.local(2026, 10, 15, 8, 40)

        let form = try editForm(of: pills.id, on: alex)

        #expect(form.isEditing)
        #expect(!form.showsTags)
        #expect(!form.offersSendTo)
        #expect(form.lockedFields.isEmpty)
        #expect(!form.isContentLocked)
        #expect(form.title == "Take the pills")
        #expect(form.repeatRule == .everyDay)
        #expect(!form.hasChanges)
    }

    @Test func savingAnEditKeepsItAtTheNextRevisionAndSendsItToEachRecipient() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID, samID])
        await settle(alex, riley, sam)
        let form = try editForm(of: pills.id, on: alex)
        form.title = "Take the blue pills"
        form.dueTime = NewYork.local(2026, 10, 15, 9, 0)

        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        let kept = try #require(alex.sharing.data.sentReminders.first { $0.reminder.id == pills.id })
        #expect(kept.revision == 1)
        #expect(kept.reminder.title == "Take the blue pills")
        #expect(kept.reminder.dueTime == NewYork.local(2026, 10, 15, 9, 0))
        #expect(kept.reminder.tagIDs.isEmpty)
        let revisions = alex.adapter.submitted.filter { $0.kind == .revise }
        #expect(Set(revisions.map(\.connectionID)) == [rileyID, samID])
        for revision in revisions {
            guard case .reminder(let sent) = revision.content else { Issue.record("A revise with no reminder"); continue }
            #expect(sent == kept)
        }
        #expect(sent(on: alex).people.flatMap(\.rows).map(\.title) == ["Take the blue pills", "Take the blue pills"])
        #expect(details(of: pills.id, on: alex)?.next == .at(day: "Today", time: "9:00\u{202F}AM"))
        #expect(alex.model.engine.reminders.isEmpty)
    }

    @Test func savingWithNothingChangedSendsNothing() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)
        let submitted = alex.adapter.submitted.count

        #expect(try editForm(of: pills.id, on: alex).save(to: alex.model))

        #expect(alex.adapter.submitted.count == submitted)
        #expect(alex.sharing.data.sentReminders.first?.revision == 0)
    }

    @Test func anEditTheStoreWontKeepSendsNothingAndTheFormSaysSo() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)
        let form = try editForm(of: pills.id, on: alex)
        form.title = "Take the blue pills"
        let submitted = alex.adapter.submitted.count
        alex.sharingStoreOpens = false
        alex.relaunch()

        #expect(!form.save(to: alex.model))

        #expect(form.isShowingCouldntSend)
        #expect(!form.isShowingDeletedMeanwhile)
        #expect(alex.adapter.submitted.count == submitted)
    }
}

extension SentTests {
    /// Deleted on its details while its form was open: there's nothing to save, so the form says
    /// so, not that trying again might work.
    @Test func savingAReminderDeletedMeanwhileSendsNothingAndTheFormSaysSo() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.send(pills, to: [rileyID])
        await settle(alex, riley, sam)
        let form = try editForm(of: pills.id, on: alex)
        form.title = "Take the blue pills"
        try alex.model.deleteSent(pills.id)
        let submitted = alex.adapter.submitted.count

        #expect(!form.save(to: alex.model))

        #expect(form.isShowingDeletedMeanwhile)
        #expect(!form.isShowingCouldntSend)
        #expect(alex.adapter.submitted.count == submitted)
    }
}
