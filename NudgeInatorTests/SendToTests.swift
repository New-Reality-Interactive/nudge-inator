import Foundation
import NudgeEngine
import Testing
import UserNotifications
@testable import NudgeInator

/// Send To in the reminder form (ticket 198, spec #127 seam 1): Alex sends a reminder from the
/// form to Riley and Sam, each connected to Alex through a connection of their own. What a test
/// asserts is what each person's app model holds and plans, what each sharing store keeps, and
/// what each phone has scheduled.
@MainActor
struct SendToTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let rileyID = UUID()
    let samID = UUID()

    /// Alex, connected to Riley and Sam, and both of them, launched and joined by the network.
    /// `riley` and `sam` are each person's Delivery mode for what Alex sends them.
    func phones(riley rileyMode: DeliveryMode = .startRightAway, sam samMode: DeliveryMode = .startRightAway) async throws -> (alex: Phone, riley: Phone, sam: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: rileyID, name: "Riley Park", state: .connected, theirs: ConnectionChoices(deliveryMode: rileyMode)),
            SharingConnection(id: samID, name: "Sam Rivera", state: .connected, theirs: ConnectionChoices(deliveryMode: samMode)),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: rileyID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(deliveryMode: rileyMode)),
        ]))
        let sam = try Phone(seed: SharingData(connections: [
            SharingConnection(id: samID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(deliveryMode: samMode)),
        ]))
        network.join(alex.adapter, riley.adapter, through: rileyID)
        network.join(alex.adapter, sam.adapter, through: samID)
        for phone in [alex, riley, sam] { await phone.launch() }
        return (alex, riley, sam)
    }

    /// A New form on `phone`, filled in as `reminder` says.
    func form(on phone: Phone, filledWith reminder: Reminder) -> ReminderForm {
        let form = ReminderForm(engine: { phone.model.engine }, now: { phone.clock.now }, defaultPace: .shipped, sharing: phone.model.sharing)
        form.title = reminder.title
        form.notes = reminder.notes
        form.tagIDs = reminder.tagIDs
        form.dueTime = reminder.dueTime
        form.repeatRule = reminder.repeatRule
        form.strength = reminder.strength
        form.paceChoice = PaceChoice(reminder.pace)
        if case .consistent(let wait) = reminder.pace { form.consistentWait = wait }
        form.breakThroughFocus = reminder.breakThroughFocus
        return form
    }

    /// Due at 8:30 every day, Firm, Consistent every 10 min: the phones' clocks say 8:00.
    let pills = Reminder(
        title: "Take the pills",
        notes: "Two with water",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm,
        pace: .consistent(wait: 10 * 60),
        breakThroughFocus: true
    )

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    // MARK: The sender

    @Test func aSentReminderDoesntNudgeTheSenderAndIsKeptAsSent() async throws {
        let (alex, riley, sam) = try await phones()
        let form = form(on: alex, filledWith: pills)
        form.toggleRecipient(rileyID)
        form.toggleRecipient(samID)

        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        #expect(alex.model.engine.reminders.isEmpty)
        #expect(alex.manager.scheduled.isEmpty)
        #expect(alex.center.pending.isEmpty)
        let sent = try #require(alex.sharing.data.sentReminders.first)
        #expect(alex.sharing.data.sentReminders.count == 1)
        #expect(sent.revision == 0)
        #expect(sent.reminder.title == "Take the pills")
        #expect(sent.reminder.tagIDs.isEmpty)
        #expect(Set(alex.sharing.data.sentCopies.map(\.connectionID)) == [rileyID, samID])
        #expect(alex.adapter.submitted.map(\.kind) == [.send, .send])
    }

    // MARK: The recipients

    @Test func eachRecipientGetsACopyOfTheirOwnWithTheContentAndNoTags() async throws {
        let (alex, riley, sam) = try await phones()
        let tag = try #require(try alex.model.createTag(named: "health"))
        var tagged = pills
        tagged.tagIDs = [tag.id]
        let form = form(on: alex, filledWith: tagged)
        form.toggleRecipient(rileyID)
        form.toggleRecipient(samID)

        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        let sentID = try #require(alex.sharing.data.sentReminders.first?.reminder.id)
        let rileysCopy = try #require(riley.model.engine.reminders.first)
        let samsCopy = try #require(sam.model.engine.reminders.first)
        #expect(rileysCopy.id != samsCopy.id)
        #expect(rileysCopy.id != sentID)
        #expect(rileysCopy.origin == .received(connectionID: rileyID, sendersReminderID: sentID, revision: 0, state: .accepted))
        #expect(samsCopy.origin == .received(connectionID: samID, sendersReminderID: sentID, revision: 0, state: .accepted))
        for copy in [rileysCopy, samsCopy] {
            #expect(copy.title == "Take the pills")
            #expect(copy.notes == "Two with water")
            #expect(copy.dueTime == pills.dueTime)
            #expect(copy.repeatRule == .everyDay)
            #expect(copy.strength == .firm)
            #expect(copy.pace == .consistent(wait: 10 * 60))
            #expect(copy.breakThroughFocus)
            #expect(copy.tagIDs.isEmpty)
        }
        #expect(riley.model.engine.tags.isEmpty)
    }

    /// Every strength, Relentless included, with the switch either way: the copy schedules the
    /// alarms and notifications a personal reminder of the same strength and pace schedules.
    @Test(arguments: [Strength.gentle, .firm, .relentless], [true, false])
    func aCopyThatStartsRightAwayNudgesAsAPersonalReminderWould(strength: Strength, breakThroughFocus: Bool) async throws {
        let (alex, riley, sam) = try await phones()
        var reminder = pills
        reminder.strength = strength
        reminder.breakThroughFocus = breakThroughFocus
        reminder.pace = .escalating
        let form = form(on: alex, filledWith: reminder)
        form.toggleRecipient(rileyID)
        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        let personal = try Phone()
        await personal.launch()
        personal.model.add(reminder)
        await personal.model.waitUntilApplied()

        #expect(riley.model.engine.reminders.count == 1)
        #expect(riley.manager.scheduled.map(\.fireDate) == personal.manager.scheduled.map(\.fireDate))
        #expect(riley.center.pending.map(\.content.interruptionLevel) == personal.center.pending.map(\.content.interruptionLevel))
        #expect(riley.center.pending.map { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }
            == personal.center.pending.map { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval })
        #expect(!riley.center.pending.isEmpty || !riley.manager.scheduled.isEmpty)
    }

    /// Any repeat and pace: the copy plans as a personal reminder with the same ones would.
    @Test(arguments: [
        (RepeatRule?.none, Pace.consistent(wait: 10 * 60)),
        (RepeatRule.everyDay, Pace.consistent(wait: 60 * 60)),
        (RepeatRule(frequency: .daily, interval: 3), Pace.escalating),
    ])
    func aCopyWithAnyRepeatAndPaceNudgesAsAPersonalReminderWould(repeatRule: RepeatRule?, pace: Pace) async throws {
        let (alex, riley, sam) = try await phones()
        var reminder = pills
        reminder.repeatRule = repeatRule
        reminder.pace = pace
        let form = form(on: alex, filledWith: reminder)
        form.toggleRecipient(rileyID)
        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        let personal = try Phone()
        await personal.launch()
        personal.model.add(reminder)
        await personal.model.waitUntilApplied()

        let copy = try #require(riley.model.engine.reminders.first)
        #expect(copy.repeatRule == repeatRule)
        #expect(copy.pace == pace)
        #expect(riley.manager.scheduled.map(\.fireDate) == personal.manager.scheduled.map(\.fireDate))
        #expect(riley.center.pending.map { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }
            == personal.center.pending.map { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval })
    }

    @Test func aCopyThatStartsRightAwayIsReportedStarted() async throws {
        let (alex, riley, sam) = try await phones()
        let form = form(on: alex, filledWith: pills)
        form.toggleRecipient(rileyID)

        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        #expect(alex.sharing.data.sentCopies.map(\.receipt) == [.started])
    }

    @Test func anAskMeFirstCopyWaitsSchedulesNothingAndIsReportedWaiting() async throws {
        let (alex, riley, sam) = try await phones(riley: .askMeFirst)
        let form = form(on: alex, filledWith: pills)
        form.toggleRecipient(rileyID)
        form.toggleRecipient(samID)

        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        let copy = try #require(riley.model.engine.reminders.first)
        #expect(copy.isWaiting)
        #expect(riley.manager.scheduled.isEmpty)
        #expect(riley.center.pending.isEmpty)
        let receipts = Dictionary(uniqueKeysWithValues: alex.sharing.data.sentCopies.map { ($0.connectionID, $0.receipt) })
        #expect(receipts == [rileyID: .waitingForAcceptance, samID: .started])
    }

    @Test func aSendDeliveredTwiceIsKeptOnce() async throws {
        let (alex, riley, sam) = try await phones()
        let form = form(on: alex, filledWith: pills)
        form.toggleRecipient(rileyID)
        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        let send = try #require(alex.adapter.submitted.first)
        try await riley.sharing.received(send)
        await settle(riley)

        #expect(riley.model.engine.reminders.count == 1)
        #expect(riley.sharing.data.receivedSyncStates.count == 1)
    }

    /// A recipient offline across a send and a revision hears of the revision first (#193).
    @Test func aFirstRevisionOfACopyNotHeldYetCreatesIt() async throws {
        let (_, riley, _) = try await phones()
        let sent = SentReminder(reminder: pills, revision: 2)

        try await riley.sharing.received(.revise(sent, for: rileyID))
        await settle(riley)

        let copy = try #require(riley.model.engine.reminders.first)
        #expect(copy.origin == .received(connectionID: rileyID, sendersReminderID: pills.id, revision: 2, state: .accepted))
        // The receipt, and the copy's status, which status sharing sends (ticket 206).
        #expect(riley.adapter.submitted.map(\.kind) == [.receipt, .status])
    }

    @Test(arguments: [SharingConnection.State.invited, .ended])
    func aSendThroughAConnectionThatIsntConnectedIsIgnored(state: SharingConnection.State) async throws {
        let riley = try Phone(seed: SharingData(connections: [SharingConnection(id: rileyID, name: "Alex Morgan", state: state)]))
        await riley.launch()

        try await riley.sharing.received(.send(SentReminder(reminder: pills, revision: 0), to: rileyID))
        await settle(riley)

        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.adapter.submitted.isEmpty)
    }

    @Test func aCopyOutlivesARelaunch() async throws {
        let (alex, riley, sam) = try await phones()
        let form = form(on: alex, filledWith: pills)
        form.toggleRecipient(rileyID)
        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)
        let copy = try #require(riley.model.engine.reminders.first)

        riley.relaunch()
        await riley.launch()

        #expect(riley.model.engine.reminders.map(\.id) == [copy.id])
        #expect(riley.model.engine.reminders.first?.origin == copy.origin)
        #expect(riley.sharing.data.receivedSyncStates.map(\.reminderID) == [copy.id])
    }

    /// The recipient's app hasn't read its reminders yet, so the send is turned down, and the
    /// adapter offers it again.
    @Test func aSendArrivingBeforeTheRemindersAreReadIsTurnedDown() async throws {
        let riley = try Phone(seed: SharingData(connections: [SharingConnection(id: rileyID, name: "Alex Morgan", state: .connected)]))

        await #expect(throws: (any Error).self) {
            try await riley.sharing.received(.send(SentReminder(reminder: pills, revision: 0), to: rileyID))
        }
        await riley.launch()
        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.sharing.data.receivedSyncStates.isEmpty)
    }

    // MARK: What can't be sent

    @Test func aSharingStoreThatWontOpenSendsNothing() async throws {
        let (alex, riley, sam) = try await phones()
        alex.sharingStoreOpens = false
        alex.relaunch()
        await alex.launch()

        #expect(throws: Phone.StoreWouldNotOpen.self) {
            try alex.sharing.send(pills, to: [rileyID])
        }
        await settle(alex, riley, sam)

        #expect(alex.adapter.submitted.isEmpty)
        #expect(riley.model.engine.reminders.isEmpty)
    }

    /// A send the app model turns down keeps the form open and says so, adding nothing: here, a
    /// model with no sharing behind it.
    @Test func aSendTurnedDownKeepsTheFormOpenAndSaysSo() async throws {
        let (alex, _, _) = try await phones()
        let unshared = AppModel(
            clock: alex.clock,
            openStore: { try ReminderStore(location: .inMemory) },
            notifications: NotificationAdapter(center: FakeNotificationCenter(), clock: alex.clock),
            alarms: AlarmAdapter(manager: FakeAlarmManager(), clock: alex.clock),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await unshared.launch()
        let form = form(on: alex, filledWith: pills)
        form.toggleRecipient(rileyID)

        #expect(!form.save(to: unshared))

        #expect(form.isShowingCouldntSend)
        #expect(unshared.engine.reminders.isEmpty)
        #expect(alex.adapter.submitted.isEmpty)
    }

    /// Someone chosen who disconnects while the form is open drops off what's chosen, so the row
    /// shows who it goes to and Add sends to the rest.
    @Test func someoneWhoDisconnectsWhileTheFormIsOpenIsNoLongerChosen() async throws {
        let (alex, riley, sam) = try await phones()
        let form = form(on: alex, filledWith: pills)
        form.toggleRecipient(rileyID)
        form.toggleRecipient(samID)
        try alex.model.disconnect(samID, choosing: .remove)
        await settle(alex, riley, sam)

        #expect(form.recipientNames == ["Riley Park"])
        #expect(form.save(to: alex.model))
        await settle(alex, riley, sam)

        #expect(alex.sharing.data.sentCopies.map(\.connectionID) == [rileyID])
        #expect(riley.model.engine.reminders.count == 1)
        #expect(sam.model.engine.reminders.isEmpty)
    }

    /// Everyone chosen disconnects: the form is a personal reminder's again, Tags row and all.
    @Test func whenEveryoneChosenDisconnectsTheFormSavesAPersonalReminder() async throws {
        let (alex, riley, sam) = try await phones()
        let form = form(on: alex, filledWith: pills)
        form.toggleRecipient(samID)
        try alex.model.disconnect(samID, choosing: .remove)
        await settle(alex, riley, sam)

        #expect(form.showsTags)
        #expect(form.save(to: alex.model))

        #expect(alex.model.engine.reminders.map(\.title) == ["Take the pills"])
        #expect(!alex.adapter.submitted.contains { $0.kind == .send })
    }

    /// Sharing turns down a send to someone not connected, whatever the form shows.
    @Test func sharingSendsNothingWhenSomeoneIsntConnected() async throws {
        let (alex, riley, sam) = try await phones()
        try alex.model.disconnect(samID, choosing: .remove)
        await settle(alex, riley, sam)

        #expect(throws: SharingModel.NotConnected.self) {
            try alex.sharing.send(pills, to: [rileyID, samID])
        }
        #expect(alex.sharing.data.sentReminders.isEmpty)
        #expect(!alex.adapter.submitted.contains { $0.kind == .send })
    }

    // MARK: The form

    @Test func sendToOffersOnlyConnectedPeople() async throws {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: rileyID, name: "Riley Park", state: .connected),
            SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited),
            SharingConnection(id: samID, name: "Sam Rivera", state: .ended),
        ]))
        await alex.launch()

        let form = form(on: alex, filledWith: pills)

        #expect(form.offersSendTo)
        #expect(form.sendToChoices.map(\.name) == ["Riley Park"])
    }

    @Test func withNoOneConnectedSendToOffersOnlyTheInvite() async throws {
        let alex = try Phone(seed: SharingData(connections: [SharingConnection(id: rileyID, name: "Jordan Lee", state: .invited)]))
        await alex.launch()

        let form = form(on: alex, filledWith: pills)

        #expect(form.offersSendTo)
        #expect(form.sendToChoices.isEmpty)
    }

    @Test func choosingSomeoneTakesTheTagsAwayAndChoosingNoOneGivesThemBack() async throws {
        let (alex, _, _) = try await phones()
        let tag = try #require(try alex.model.createTag(named: "health"))
        let form = form(on: alex, filledWith: pills)
        form.tagIDs = [tag.id]
        #expect(form.showsTags)

        form.toggleRecipient(rileyID)
        #expect(!form.showsTags)
        #expect(form.recipientNames == ["Riley Park"])
        #expect(form.hasChanges)

        form.toggleRecipient(rileyID)
        #expect(form.showsTags)
        #expect(form.recipientNames.isEmpty)
        #expect(form.save(to: alex.model))
        #expect(alex.model.engine.reminders.first?.tagIDs == [tag.id])
        #expect(alex.sharing.data.sentReminders.isEmpty)
    }

    @Test func recipientsAreNamedInTheOrderTheyreListed() async throws {
        let (alex, _, _) = try await phones()
        let form = form(on: alex, filledWith: pills)

        form.toggleRecipient(samID)
        form.toggleRecipient(rileyID)

        #expect(form.recipientNames == ["Riley Park", "Sam Rivera"])
    }

    @Test func withoutSharingOrInAnEditFormThereIsNoSendTo() async throws {
        let (alex, _, _) = try await phones()
        alex.model.add(pills)
        let edit = try #require(ReminderForm(engine: { alex.model.engine }, editing: pills.id, now: { alex.clock.now }))
        let unshared = ReminderForm(engine: { alex.model.engine }, now: { alex.clock.now }, defaultPace: .shipped)

        #expect(!edit.offersSendTo)
        #expect(!unshared.offersSendTo)
    }
}
