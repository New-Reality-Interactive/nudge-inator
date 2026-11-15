import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Turning Sharing off after it's been used (#388, spec #127 seam 1): Alex and Riley connected
/// through the fake network, and Riley turning Sharing off. Riley's sharing is made by the switch's
/// factory over the switch's record in a suite of the phone's own, as the app delegate makes it. What
/// a test asserts is what Riley's app model, stores and alarms keep, and what reaches Alex. The
/// sheet's layout, VoiceOver and the largest text size are the phone check.
@MainActor
final class TurnOffSharingTests {
    /// One person's iPhone, with Sharing on.
    @MainActor
    final class Phone {
        let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
        let center = FakeNotificationCenter()
        let manager = FakeAlarmManager()
        let adapter = FakeSharingAdapter()
        let reminderFile = TemporaryStoreFile()
        let sharingFile = TemporaryStoreFile()
        let suiteName = "TurnOffSharingTests.\(UUID().uuidString)"
        /// How many sharing models the switch's factory made.
        private(set) var made = 0
        private(set) var model: AppModel!

        init(seed: SharingData = SharingData(), sharingOn: Bool = true) throws {
            try SharingStore(location: .file(sharingFile.url)).save(seed)
            record.isOn = sharingOn
            model = makeModel()
        }

        deinit {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }

        var record: SharingSwitchRecord {
            SharingSwitchRecord(defaults: UserDefaults(suiteName: suiteName)!)
        }

        /// A new app model over the same files, record and adapter, as a relaunch is.
        func relaunch() {
            model = makeModel()
        }

        private func makeModel() -> AppModel {
            let reminderFile = reminderFile
            let sharingFile = sharingFile
            let clock = clock
            return AppModel(
                clock: clock,
                openStore: { try ReminderStore(location: .file(reminderFile.url)) },
                notifications: NotificationAdapter(center: center, clock: clock),
                alarms: AlarmAdapter(manager: manager, clock: clock),
                defaultPaceRecord: .temporary,
                remindersSortRecord: .temporary,
                tagsSortRecord: .temporary,
                doneQueue: .temporary,
                sharingSwitch: record,
                makeSharing: { [unowned self] in
                    made += 1
                    return SharingModel(adapter: adapter, clock: clock) {
                        try SharingStore(location: .file(sharingFile.url))
                    }
                },
                timeZone: NewYork.timeZone
            )
        }

        var sharing: SharingModel { model.sharing! }

        /// What the sharing store holds, read from its file: with Sharing off, no model shows it.
        func keptSharing() throws -> SharingData {
            try SharingStore(location: .file(sharingFile.url)).load()
        }

        func launch() async {
            await model.launch()
            await model.waitUntilApplied()
        }
    }

    let network = FakeSharingNetwork()
    let connectionID = UUID()
    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .relentless
    )

    func phones(rileyAlsoHas others: [SharingConnection] = []) async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected),
        ] + others))
        network.join(alex.adapter, riley.adapter, through: connectionID)
        for phone in [alex, riley] { await phone.launch() }
        return (alex, riley)
    }

    func received(_ title: String = "Water the plants", state: ReminderOrigin.ReceivedState = .accepted) -> Reminder {
        Reminder(
            title: title,
            dueTime: NewYork.local(2026, 10, 15, 9),
            repeatRule: .everyDay,
            strength: .relentless,
            origin: .received(connectionID: connectionID, sendersReminderID: UUID(), revision: 0, state: state)
        )
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    // MARK: The confirmation

    /// Connections and open invites are counted apart, with every reminder received, for the sheet's
    /// "This disconnects you from 1 person and cancels 2 invites" and its Remove or Keep header.
    @Test func turningOffWithSomeoneConnectedAsksFirstAndSaysWhatGoes() async throws {
        let (_, riley) = try await phones(rileyAlsoHas: [
            SharingConnection(id: UUID(), name: "Sam Rivera", state: .invited),
            SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited),
        ])
        riley.model.add(received())
        riley.model.add(received("Feed the cat"))

        #expect(riley.model.sharingOff == .confirm(SharingOffSummary(connected: 1, invited: 2, received: 2)))
        riley.model.setSharing(on: false)

        // The switch stays on until the person confirms; canceling the sheet is this too.
        #expect(riley.model.isSharingOn)
        #expect(riley.record.isOn)
        #expect(riley.sharing.data.connections.count == 3)
        #expect(riley.model.engine.reminders.count == 2)
    }

    /// With no one connected or invited and nothing received, off is at once (the mockup).
    @Test func turningOffWithNothingConnectedOrReceivedIsAtOnce() async throws {
        let riley = try Phone(seed: SharingData())
        await riley.launch()

        #expect(riley.model.sharingOff == .atOnce)
    }

    /// Turning off asks whenever it would delete anything, as every destructive action does: with
    /// only reminders received (the other people ended their connections) it still asks.
    @Test func turningOffWithOnlyReceivedRemindersAsks() async throws {
        let riley = try Phone(seed: SharingData())
        await riley.launch()
        riley.model.add(received())

        #expect(riley.model.sharingOff == .confirm(SharingOffSummary(connected: 0, invited: 0, received: 1)))
        riley.model.setSharing(on: false)

        #expect(riley.model.isSharingOn)
        #expect(riley.model.engine.reminders.count == 1)
    }

    /// A Sent list and its history are deleted too, so they are asked about.
    @Test func turningOffWithOnlyASentReminderAsks() async throws {
        let riley = try Phone(seed: SharingData(sentReminders: [SentReminder(reminder: pills, revision: 0)]))
        await riley.launch()

        #expect(riley.model.sharingOff == .confirm(SharingOffSummary(connected: 0, invited: 0, received: 0)))
    }

    /// Until the reminders and the sharing store are read, nothing can be said about what it holds.
    @Test func turningOffBeforeEverythingIsReadIsNotYet() async throws {
        let riley = try Phone(seed: SharingData())

        #expect(riley.model.sharingOff == .notYet)
        #expect(!riley.model.canTurnSharingOff)

        await riley.launch()

        #expect(riley.model.sharingOff == .atOnce)
        #expect(riley.model.canTurnSharingOff)
    }

    /// While it's off there is nothing to turn off.
    @Test func whileSharingIsOffThereIsNothingToTurnOff() async throws {
        let riley = try Phone(seed: SharingData())
        riley.record.isOn = false
        riley.relaunch()
        await riley.launch()

        #expect(riley.model.sharingOff == nil)
        #expect(riley.model.canTurnSharingOff)
    }

    /// The sheet reads the counts live: an invite accepted while it is up is counted when it asks again.
    @Test func theCountsFollowTheStoreWhileTheSheetIsUp() async throws {
        let (alex, riley) = try await phones()
        #expect(riley.model.sharingOff == .confirm(SharingOffSummary(connected: 1, invited: 0, received: 0)))

        try riley.sharing.keep(SharingData(connections: riley.sharing.data.connections + [
            SharingConnection(id: UUID(), name: "Sam Rivera", state: .connected),
        ]))

        #expect(riley.model.sharingOff == .confirm(SharingOffSummary(connected: 2, invited: 0, received: 0)))
        _ = alex
    }

    // MARK: Share Activity (#396)

    /// Turning Sharing off empties the sharing store, the Share Activity record with it.
    @Test func turningOffClearsTheShareActivityRecord() async throws {
        let (alex, riley) = try await phones()
        try await riley.sharing.received(.connectionLost(connectionID))
        #expect(riley.sharing.data.activity.count == 1)

        try riley.model.turnSharingOff(choosing: .remove)
        await settle(alex, riley)

        #expect(try riley.keptSharing().activity.isEmpty)
    }

    /// A disconnect still on its way, refused for good while the model winds down, records nothing
    /// into the record that Turn Off Sharing, or Delete All Data, just cleared.
    @Test func aDisconnectRefusedWhileWindingDownRecordsNothing() async throws {
        let (alex, riley) = try await phones()
        riley.adapter.isOnline = false
        try riley.model.turnSharingOff(choosing: .remove)
        let disconnect = try #require(riley.adapter.submitted.last)
        #expect(disconnect.kind == .disconnect)

        try await riley.adapter.events?.gaveUp(disconnect.entry.id)

        #expect(try riley.keptSharing().activity.isEmpty)
        _ = alex
    }

    // MARK: Confirming

    /// Remove deletes every received reminder, stops its ring and takes it out of Notification
    /// Center, as Disconnect's Remove does, and the person's own reminders stay.
    @Test func confirmingWithRemoveDeletesEveryReceivedReminder() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(pills)
        riley.model.add(received())
        await settle(alex, riley)

        try riley.model.turnSharingOff(choosing: .remove)
        await settle(alex, riley)

        #expect(riley.model.engine.reminders.map(\.title) == ["Take the pills"])
        #expect(!riley.manager.scheduled.isEmpty)
        #expect(!riley.manager.scheduled.contains { $0.fireDate == NewYork.local(2026, 10, 15, 9) })
        #expect(!riley.model.isSharingOn)
        #expect(!riley.record.isOn)
    }

    /// Keep keeps each accepted reminder as the person's own, from no one; one still waiting to be
    /// accepted goes, as Disconnect's Keep does.
    @Test func confirmingWithKeepKeepsEachAcceptedReminderAsTheirOwn() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        riley.model.add(received("Feed the cat", state: .waiting))
        await settle(alex, riley)

        try riley.model.turnSharingOff(choosing: .keepAsMyOwnReminders)

        #expect(riley.model.engine.reminders.map(\.title) == ["Water the plants"])
        #expect(riley.model.engine.reminders.allSatisfy { $0.origin == .mine })
    }

    /// Each other person sees Connection Ended, with their own Remove or Keep choice; open invites
    /// are revoked; the Sent list, its history and the connection settings go.
    @Test func confirmingDisconnectsEveryoneAndEmptiesTheSharingStore() async throws {
        let inviteID = UUID()
        let (alex, riley) = try await phones(rileyAlsoHas: [
            SharingConnection(id: inviteID, name: "Sam Rivera", state: .invited),
        ])
        riley.model.add(pills)
        try riley.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        let account = riley.sharing.data.accountID

        try riley.model.turnSharingOff(choosing: .remove)
        await settle(alex, riley)

        #expect(alex.sharing.endedConnection?.id == connectionID)
        #expect(riley.adapter.revoked == [inviteID])
        #expect(try riley.keptSharing() == SharingData(accountID: account))
    }

    /// Turning Sharing on again starts fresh: Connections shows No Connections.
    @Test func turningSharingOnAgainShowsNoOne() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(pills)
        try riley.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        try riley.model.turnSharingOff(choosing: .remove)
        await settle(alex, riley)

        riley.model.setSharing(on: true)
        await settle(riley)

        #expect(riley.sharing.data.connections.isEmpty)
        #expect(riley.sharing.data.sentReminders.isEmpty)
    }

    // MARK: Winding down

    /// Off while iCloud is out of reach: the disconnect waits in the store and the adapter, which
    /// keeps going with Sharing off, through a relaunch, until it has gone (#211). Only then does
    /// the adapter stop.
    @Test func aDisconnectMadeOfflineStillGoesWithSharingOff() async throws {
        let (alex, riley) = try await phones()
        riley.adapter.isOnline = false

        try riley.model.turnSharingOff(choosing: .remove)
        await settle(alex, riley)
        #expect(riley.adapter.stops == 0)
        #expect(riley.record.isWindingDown)
        riley.relaunch()
        await riley.launch()

        #expect(!riley.model.isSharingOn)
        #expect(try riley.keptSharing().outbox.map(\.kind) == [.disconnect])
        #expect(alex.sharing.endedConnection == nil)

        riley.adapter.isOnline = true
        await settle(alex, riley)

        #expect(alex.sharing.endedConnection?.id == connectionID)
        #expect(try riley.keptSharing().outbox.isEmpty)
        #expect(riley.adapter.stops == 1)
        #expect(!riley.record.isWindingDown)
        #expect(!riley.model.isSharingOn)
    }

    /// A revoked invite waits too, though it is no outbox entry.
    @Test func anInviteCanceledOfflineIsStillRevoked() async throws {
        let inviteID = UUID()
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: inviteID, name: "Sam Rivera", state: .invited),
        ]))
        network.add(riley.adapter)
        await riley.launch()
        riley.adapter.isOnline = false

        try riley.model.turnSharingOff(choosing: .remove)
        await settle(riley)
        #expect(riley.adapter.stops == 0)

        riley.adapter.isOnline = true
        await settle(riley)

        #expect(riley.adapter.revoked == [inviteID])
        #expect(riley.adapter.stops == 1)
        #expect(!riley.record.isWindingDown)
    }

    /// Turning Sharing on while the disconnects wait carries on with the same sharing, still empty,
    /// and they still go.
    @Test func turningSharingOnWhileWindingDownStartsFreshAndStillSends() async throws {
        let (alex, riley) = try await phones()
        riley.adapter.isOnline = false
        try riley.model.turnSharingOff(choosing: .remove)
        await settle(alex, riley)
        let made = riley.made

        riley.model.setSharing(on: true)

        #expect(riley.made == made)
        #expect(riley.sharing.data.connections.isEmpty)
        #expect(!riley.record.isWindingDown)
        riley.adapter.isOnline = true
        await settle(alex, riley)
        #expect(alex.sharing.endedConnection?.id == connectionID)
        #expect(riley.adapter.stops == 0)
        #expect(riley.model.isSharingOn)
    }

    // MARK: Delete All Data

    /// Delete All Data turns Sharing off and disconnects everyone, with Remove (shared with #214).
    @Test func deleteAllDataTurnsSharingOff() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())

        try await riley.model.deleteAllData()
        await settle(alex, riley)

        #expect(!riley.model.isSharingOn)
        #expect(!riley.record.isOn)
        #expect(riley.model.engine.reminders.isEmpty)
        #expect(alex.sharing.endedConnection?.id == connectionID)
    }

    // MARK: Must keep

    /// Disconnecting one person from their connection page leaves Sharing on.
    @Test func disconnectingOnePersonLeavesSharingOn() async throws {
        let (alex, riley) = try await phones()

        try riley.model.disconnect(connectionID, choosing: .remove)
        await settle(alex, riley)

        #expect(riley.model.isSharingOn)
        #expect(riley.adapter.stops == 0)
        #expect(alex.sharing.endedConnection?.id == connectionID)
    }
}
