import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The sharing adapter's seam (ticket 192, spec #127 seam 1): two app models, a sender's and a
/// recipient's, each with its own stores, engine and fake clock, joined by an in-memory fake of the
/// adapter that can hold, reorder and drop changes and go offline. What a test asserts is what the
/// other person's app model ends up with, and what each model keeps in its sharing store.
@MainActor
struct SharingAdapterTests {
    let network = FakeSharingNetwork()
    let connectionID = UUID()
    let reminderID = UUID()

    /// One person's iPhone: an app model over its own reminder store, sharing store, notification
    /// center, alarm manager and clock, and its end of the fake adapter.
    @MainActor
    final class Phone {
        let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
        let center = FakeNotificationCenter()
        let manager = FakeAlarmManager()
        let adapter = FakeSharingAdapter()
        let reminderFile = TemporaryStoreFile()
        let sharingFile = TemporaryStoreFile()
        /// Fails to open the sharing store while set, as a locked or damaged file would.
        var sharingStoreOpens = true
        private(set) var model: AppModel!

        struct StoreWouldNotOpen: Error {}

        init(seed: SharingData = SharingData()) throws {
            try SharingStore(location: .file(sharingFile.url)).save(seed)
            model = makeModel()
        }

        /// A new app model over the same files and the same adapter, as a relaunch is.
        func relaunch() {
            model = makeModel()
        }

        private func makeModel() -> AppModel {
            let reminderFile = reminderFile
            let sharingFile = sharingFile
            let opens = { [unowned self] in sharingStoreOpens }
            return AppModel(
                clock: clock,
                openStore: { try ReminderStore(location: .file(reminderFile.url)) },
                notifications: NotificationAdapter(center: center, clock: clock),
                alarms: AlarmAdapter(manager: manager, clock: clock),
                defaultPaceRecord: .temporary,
                remindersSortRecord: .temporary,
                tagsSortRecord: .temporary,
                doneQueue: .temporary,
                sharing: SharingModel(adapter: adapter, clock: clock) {
                    guard opens() else { throw StoreWouldNotOpen() }
                    return try SharingStore(location: .file(sharingFile.url))
                },
                timeZone: NewYork.timeZone
            )
        }

        var sharing: SharingModel { model.sharing! }

        func launch() async {
            await model.launch()
            await model.waitUntilApplied()
        }
    }

    /// A sender and a recipient who share one connection, both launched, joined by the network.
    func connectedPhones(sentCopy: SentCopy? = nil) async throws -> (sender: Phone, recipient: Phone) {
        let sender = try Phone(seed: SharingData(
            connections: [SharingConnection(id: connectionID, name: "Sam", state: .connected, theirs: ConnectionChoices(sharesStatus: false))],
            sentCopies: sentCopy.map { [$0] } ?? []
        ))
        let recipient = try Phone(seed: SharingData(
            connections: [SharingConnection(id: connectionID, name: "Alex", state: .connected, theirs: ConnectionChoices(sharesStatus: false))]
        ))
        network.join(sender.adapter, recipient.adapter)
        await sender.launch()
        await recipient.launch()
        return (sender, recipient)
    }

    func copy(receipt: SentCopy.Receipt = .notDelivered) -> SentCopy {
        SentCopy(connectionID: connectionID, reminderID: reminderID, createdAt: NewYork.local(2026, 10, 15, 8), receipt: receipt, statusRecord: nil)
    }

    func settings(_ deliveryMode: DeliveryMode, sharesStatus: Bool = true) -> SharingChange {
        .settings(SharingChange.ConnectionSettings(ConnectionChoices(sharesStatus: sharesStatus, deliveryMode: deliveryMode)), for: connectionID)
    }

    // MARK: A change made by one arrives at the other

    @Test func aChangeOnePersonMakesArrivesAtTheOther() async throws {
        let (sender, recipient) = try await connectedPhones()

        try recipient.sharing.submit(settings(.askMeFirst))
        await network.settle()

        let seen = try #require(sender.sharing.data.connections.first)
        #expect(seen.theirs == ConnectionChoices(sharesStatus: true, deliveryMode: .askMeFirst))
        // The change was the other way round, so the recipient's own connection is as it was.
        #expect(recipient.sharing.data.connections.first?.theirs == ConnectionChoices(sharesStatus: false))
    }

    @Test func aChangeTheOtherAppKeptIsStillThereAfterARelaunch() async throws {
        let (sender, recipient) = try await connectedPhones()
        try recipient.sharing.submit(settings(.askMeFirst))
        await network.settle()

        sender.relaunch()
        await sender.launch()

        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .askMeFirst)
    }

    @Test func theRecipientsReceiptAndStatusReachTheSendersCopy() async throws {
        let (sender, recipient) = try await connectedPhones(sentCopy: copy())
        let record = SentCopy.StatusRecord(report: StatusReport(label: .nudging, occurrences: []), notSharingThisOne: false)

        try recipient.sharing.submit(.receipt(.started, for: reminderID, from: connectionID))
        try recipient.sharing.submit(.status(record, for: reminderID, from: connectionID))
        await network.settle()

        let seen = try #require(sender.sharing.data.sentCopies.first)
        #expect(seen.receipt == .started)
        #expect(seen.statusRecord == record)

        try recipient.sharing.submit(.status(nil, for: reminderID, from: connectionID))
        await network.settle()
        #expect(sender.sharing.data.sentCopies.first?.statusRecord == nil)
    }

    @Test func aChangeForAConnectionOrCopyTheAppDoesNotHoldChangesNothing() async throws {
        let (sender, recipient) = try await connectedPhones()
        let before = sender.sharing.data

        try recipient.sharing.submit(.settings(.init(name: "Who", ConnectionChoices(sharesStatus: true)), for: UUID()))
        try recipient.sharing.submit(.receipt(.started, for: reminderID, from: connectionID))
        await network.settle()

        #expect(sender.sharing.data == before)
    }

    @Test func eachAppModelKeepsItsOwnReminders() async throws {
        let (sender, recipient) = try await connectedPhones()
        let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 8, 40), strength: .firm, createdAt: NewYork.local(2026, 10, 15, 8))

        sender.model.add(call)
        try sender.sharing.submit(settings(.askMeFirst))
        await network.settle()

        #expect(sender.model.engine.reminders == [call])
        #expect(recipient.model.engine.reminders.isEmpty)
        #expect(try ReminderStore(location: .file(recipient.reminderFile.url)).load().reminders.isEmpty)
    }

    // MARK: What the fake does to changes

    @Test func aHeldChangeWaitsInFlightUntilItIsDelivered() async throws {
        let (sender, recipient) = try await connectedPhones()
        network.holdsDeliveries = true

        try recipient.sharing.submit(settings(.askMeFirst))
        await network.settle()

        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .startRightAway)
        #expect(network.inFlight.count == 1)
        // It went through iCloud, so the recipient's app no longer shows it as waiting to sync.
        #expect(recipient.sharing.data.outbox.isEmpty)

        network.deliverAll()
        await network.settle()
        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .askMeFirst)
        #expect(network.inFlight.isEmpty)
    }

    /// The model applies what arrives, in the order it arrives: ordering between two changes is the
    /// adapter's, and the real one settles it in iCloud (#216).
    @Test func changesReorderedInFlightArriveInTheNewOrder() async throws {
        let (sender, recipient) = try await connectedPhones()
        network.holdsDeliveries = true
        try recipient.sharing.submit(settings(.askMeFirst))
        try recipient.sharing.submit(settings(.startRightAway))
        await network.settle()

        network.move(from: 1, to: 0)
        network.deliverAll()
        await network.settle()

        // Delivered the second, then the first.
        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .askMeFirst)
    }

    @Test func aChangeCanBeDeliveredAheadOfTheOnesBeforeIt() async throws {
        let (sender, recipient) = try await connectedPhones()
        network.holdsDeliveries = true
        try recipient.sharing.submit(settings(.askMeFirst, sharesStatus: false))
        try recipient.sharing.submit(settings(.startRightAway))
        await network.settle()

        network.deliver(at: 1)
        await network.settle()

        #expect(sender.sharing.data.connections.first?.theirs == ConnectionChoices(sharesStatus: true, deliveryMode: .startRightAway))
        #expect(network.inFlight.count == 1)
    }

    @Test func aDroppedChangeNeverArrives() async throws {
        let (sender, recipient) = try await connectedPhones()
        network.holdsDeliveries = true
        try recipient.sharing.submit(settings(.askMeFirst))
        await network.settle()

        network.drop(at: 0)
        network.holdsDeliveries = false
        await network.settle()

        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .startRightAway)
        #expect(network.inFlight.isEmpty)
    }

    @Test func anOfflinePersonsChangeWaitsInTheOutboxUntilTheyAreBackOnline() async throws {
        let (sender, recipient) = try await connectedPhones()
        let change = settings(.askMeFirst)
        recipient.adapter.isOnline = false

        try recipient.sharing.submit(change)
        await network.settle()

        #expect(recipient.sharing.data.outbox == [change.entry])
        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .startRightAway)

        // Closing the app doesn't lose the entry: the next launch reads the outbox from the store. (The
        // change itself is the adapter's to keep, as CloudKit's sync engine keeps its pending changes
        // in its saved state; this fake keeps it in the same instance across the relaunch.)
        recipient.relaunch()
        await recipient.launch()
        #expect(recipient.sharing.data.outbox == [change.entry])

        recipient.adapter.isOnline = true
        await network.settle()
        #expect(recipient.sharing.data.outbox.isEmpty)
        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .askMeFirst)

        recipient.relaunch()
        await recipient.launch()
        #expect(recipient.sharing.data.outbox.isEmpty)
    }

    @Test func aChangeForAnOfflinePersonArrivesWhenTheyAreBack() async throws {
        let (sender, recipient) = try await connectedPhones()
        sender.adapter.isOnline = false

        try recipient.sharing.submit(settings(.askMeFirst))
        await network.settle()
        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .startRightAway)
        #expect(network.inFlight.count == 1)

        sender.adapter.isOnline = true
        await network.settle()
        #expect(sender.sharing.data.connections.first?.theirs.deliveryMode == .askMeFirst)
    }

    // MARK: The adapter carries every kind of change

    @Test func everyKindOfChangeReachesTheOtherEndWhole() async throws {
        let sent = SentReminder(reminder: Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 16, 18), strength: .relentless, createdAt: NewYork.local(2026, 10, 15, 8)), revision: 0)
        let record = SentCopy.StatusRecord(report: StatusReport(label: .done, occurrences: []), notSharingThisOne: true)
        let changes: [SharingChange] = [
            .send(sent, to: connectionID),
            .revise(sent, for: connectionID),
            .cancel(sent.reminder.id, for: connectionID),
            .receipt(.waitingForAcceptance, for: sent.reminder.id, from: connectionID),
            .status(record, for: sent.reminder.id, from: connectionID),
            settings(.askMeFirst),
            .disconnect(connectionID),
        ]
        let first = FakeSharingAdapter()
        let second = FakeSharingAdapter()
        network.join(first, second)
        let events = RecordingSharingEvents()
        second.events = events

        changes.forEach(first.submit)
        await network.settle()

        #expect(events.received == changes)
    }

    // MARK: The iCloud account state

    @Test func theAccountStateComesFromTheAdapterAtLaunch() async throws {
        let (_, recipient) = try await connectedPhones()

        #expect(recipient.sharing.accountState == .available)
        #expect(recipient.sharing.reach == .working)
    }

    @Test(arguments: [
        (SharingAccountState.noAccount, SharingReach.paused(.noAccount)),
        (.restricted, .paused(.restricted)),
        (.temporarilyUnavailable, .paused(.temporarilyUnavailable)),
    ])
    func aChangeOfAccountStateReachesTheModelAsReach(state: SharingAccountState, reach: SharingReach) async throws {
        let (_, recipient) = try await connectedPhones()

        recipient.adapter.account = state
        await recipient.model.waitUntilApplied()

        #expect(recipient.sharing.accountState == state)
        #expect(recipient.sharing.reach == reach)

        recipient.adapter.account = .available
        await recipient.model.waitUntilApplied()
        #expect(recipient.sharing.reach == .working)
    }

    @Test func theAccountIsReadAgainWhenTheAppIsOpened() async throws {
        let (_, recipient) = try await connectedPhones()
        // The system changed it while the app was suspended, which no event told the app.
        recipient.adapter.setAccountWithoutTellingTheApp(.noAccount)

        await recipient.model.appOpened()
        await recipient.model.waitUntilApplied()

        #expect(recipient.sharing.accountState == .noAccount)
    }

    @Test func theAccountIsUnknownUntilTheAdapterReportsIt() throws {
        let phone = try Phone()

        #expect(phone.sharing.accountState == nil)
        #expect(phone.sharing.reach == nil)
    }

    // MARK: Personal reminders are left alone

    @Test func aModelWithNoSharingAdapterHasNoSharingAndWorksAsBefore() async throws {
        let center = FakeNotificationCenter()
        let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
        let model = AppModel(
            clock: clock,
            openStore: { try ReminderStore(location: .inMemory) },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: FakeAlarmManager(), clock: clock),
            defaultPaceRecord: .temporary,
            remindersSortRecord: .temporary,
            tagsSortRecord: .temporary,
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await model.launch()
        let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 8, 40), strength: .gentle, createdAt: clock.now)

        model.add(call)
        await model.waitUntilApplied()

        #expect(model.sharing == nil)
        #expect(model.engine.reminders == [call])
    }

    @Test func aSharingStoreThatWontOpenLeavesPersonalRemindersAlone() async throws {
        let phone = try Phone()
        phone.sharingStoreOpens = false
        await phone.launch()
        let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 8, 40), strength: .gentle, createdAt: phone.clock.now)

        phone.model.add(call)
        await phone.model.waitUntilApplied()

        guard case .ready = phone.model.launchState else {
            Issue.record("The reminder store should have opened")
            return
        }
        #expect(phone.model.engine.reminders == [call])
        #expect(try ReminderStore(location: .file(phone.reminderFile.url)).load().reminders == [call])
        #expect(throws: Phone.StoreWouldNotOpen.self) {
            try phone.sharing.submit(.disconnect(UUID()))
        }
        // A change that comes meanwhile isn't kept either, so it throws and the adapter holds it.
        await #expect(throws: Phone.StoreWouldNotOpen.self) {
            try await phone.sharing.received(.settings(.init(name: "Sam M", ConnectionChoices(sharesStatus: true)), for: self.connectionID))
        }
        await #expect(throws: Phone.StoreWouldNotOpen.self) {
            try await phone.sharing.sent(UUID())
        }
        #expect(phone.sharing.data == SharingData())

        // The next App opened tries again.
        phone.sharingStoreOpens = true
        await phone.model.appOpened()
        await phone.model.waitUntilApplied()
        try phone.sharing.submit(.disconnect(UUID()))
        #expect(phone.sharing.data.outbox.count == 1)
    }

    @Test func aPersonalReminderIsUntouchedBySharingChangesComingAndGoing() async throws {
        let (sender, recipient) = try await connectedPhones()
        let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 8, 40), strength: .firm, createdAt: NewYork.local(2026, 10, 15, 8))
        recipient.model.add(call)
        await recipient.model.waitUntilApplied()
        let planned = recipient.center.pending.map(\.identifier)
        let stored = try ReminderStore(location: .file(recipient.reminderFile.url)).load()

        try sender.sharing.submit(settings(.askMeFirst))
        try recipient.sharing.submit(settings(.askMeFirst))
        try recipient.sharing.submit(.disconnect(connectionID))
        await network.settle()
        await recipient.model.waitUntilApplied()

        #expect(recipient.model.engine.reminders == [call])
        #expect(recipient.center.pending.map(\.identifier) == planned)
        #expect(try ReminderStore(location: .file(recipient.reminderFile.url)).load().reminders == stored.reminders)
    }
}

/// Records what an adapter reports, for tests of the adapter alone.
@MainActor
final class RecordingSharingEvents: SharingAdapterEvents {
    private(set) var received: [SharingChange] = []
    private(set) var sent: [OutboxChange.ID] = []
    private(set) var accountChanges = 0

    func received(_ change: SharingChange) async throws {
        received.append(change)
    }

    func sent(_ changeID: OutboxChange.ID) async throws {
        sent.append(changeID)
    }

    func accountStateChanged() {
        accountChanges += 1
    }

    func connectivityChanged() {}

    func invited(_ invite: IncomingInvite) async {}

    func inviteAccepted(_ connectionID: UUID, by participant: SharingParticipant) async throws {}

    func inviteWithdrawn(_ connectionID: UUID) async throws {}
}
