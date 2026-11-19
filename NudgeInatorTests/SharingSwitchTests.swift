import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Settings' Sharing switch (#387), through the app model over the fake sharing adapter: the
/// switch's record in a suite of this test's own, and the sharing model made by a factory, as the
/// app delegate makes it. A class so `deinit` removes the suite, even when a test fails; the store
/// files remove themselves.
@MainActor
final class SharingSwitchTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    let reminderFile = TemporaryStoreFile()
    let sharingFile = TemporaryStoreFile()
    let suiteName = "SharingSwitchTests.\(UUID().uuidString)"
    /// Each adapter the factory made, newest last.
    private(set) var adapters: [FakeSharingAdapter] = []

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    var record: SharingSwitchRecord {
        SharingSwitchRecord(defaults: UserDefaults(suiteName: suiteName)!)
    }

    /// A model before launch, as the app delegate builds it.
    func makeModel() -> AppModel {
        let reminderFile = reminderFile
        let sharingFile = sharingFile
        let clock = clock
        return AppModel(
            clock: clock,
            openStore: { try ReminderStore(location: .file(reminderFile.url)) },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            defaultPaceRecord: .temporary,
            defaultAlarmSoundRecord: .temporary,
            remindersSortRecord: .temporary,
            tagsSortRecord: .temporary,
            doneQueue: .temporary,
            sharingSwitch: record,
            makeSharing: { [unowned self] in
                let adapter = FakeSharingAdapter()
                adapters.append(adapter)
                return SharingModel(adapter: adapter, clock: clock) {
                    try SharingStore(location: .file(sharingFile.url))
                }
            },
            timeZone: NewYork.timeZone
        )
    }

    func launched() async -> AppModel {
        let model = makeModel()
        await model.launch()
        await model.waitUntilApplied()
        return model
    }

    // MARK: Off until turned on

    /// A new install, and an install updated from 1.3.0, have no record: Sharing is off, so the
    /// app has no sharing model, which every sharing screen needs to show.
    @Test func aNewInstallHasSharingOff() async {
        let model = await launched()

        #expect(!model.isSharingOn)
        #expect(model.sharing == nil)
        #expect(adapters.isEmpty)
    }

    // MARK: Turning it on

    /// Every sharing screen shows once the app model has a sharing model, with no relaunch, and it
    /// starts fresh: no one connected.
    @Test func turningSharingOnMakesSharingAtOnce() async throws {
        let model = await launched()

        model.setSharing(on: true)

        #expect(model.isSharingOn)
        let sharing = try #require(model.sharing)
        await sharing.waitUntilApplied()
        #expect(sharing.data.connections.isEmpty)
        #expect(record.isOn)
    }

    /// Turning it on is the person choosing to share, so iCloud is asked at once: without it, the
    /// paused messages (#210) say why nothing can be sent yet.
    @Test func turningSharingOnSignedOutOfICloudShowsSharingPaused() async throws {
        let model = await launched()

        model.setSharing(on: true)
        let adapter = try #require(adapters.last)
        adapter.setAccountWithoutTellingTheApp(.noAccount)
        let sharing = try #require(model.sharing)
        await sharing.waitUntilApplied()

        #expect(adapter.starts == 1)
        #expect(sharing.banner == .paused(.noAccount))
    }

    // MARK: Turning it off

    /// With nothing sent, received or invited, off happens at once, with no confirmation, and no
    /// sharing work runs afterwards: App opened reads no account, and the model is let go.
    @Test func turningSharingOffWithNothingSharedStopsItAtOnce() async throws {
        let model = await launched()
        model.setSharing(on: true)
        let adapter = try #require(adapters.last)
        await model.sharing?.waitUntilApplied()
        let reads = adapter.accountReads

        model.setSharing(on: false)
        await model.appOpened()
        model.minutePassed()

        #expect(!model.isSharingOn)
        #expect(model.sharing == nil)
        #expect(!record.isOn)
        #expect(adapter.accountReads == reads)
        #expect(adapter.submitted.isEmpty)
        #expect(adapter.stops == 1)
    }

    /// Until the sharing store has been read, an empty list says nothing about what it holds.
    @Test func sharingCantTurnOffBeforeItsStoreIsRead() async throws {
        let model = await launched()
        model.setSharing(on: true)
        let sharing = try #require(model.sharing)
        #expect(!sharing.hasReadStore)

        model.setSharing(on: false)

        #expect(model.isSharingOn)
        await sharing.waitUntilApplied()
        #expect(model.sharingOff == .atOnce)
    }

    /// An account read already queued when the switch goes off asks nothing once it runs.
    @Test func anAccountReadQueuedBeforeTurningOffAsksNothing() async throws {
        let model = await launched()
        model.setSharing(on: true)
        let adapter = try #require(adapters.last)
        let sharing = try #require(model.sharing)
        await sharing.waitUntilApplied()
        let reads = adapter.accountReads

        sharing.refreshAccountState()
        model.setSharing(on: false)
        await sharing.waitUntilApplied()

        #expect(adapter.accountReads == reads)
    }

    /// The model is let go, so nothing holds it and its adapter to keep working.
    @Test func turningSharingOffLetsTheSharingModelGo() async throws {
        let model = await launched()
        model.setSharing(on: true)
        weak let sharing = model.sharing
        await sharing?.waitUntilApplied()

        model.setSharing(on: false)
        adapters.removeAll()

        #expect(sharing == nil)
    }

    /// With anyone connected or invited, off needs #388's confirmation, so here it stays on.
    @Test func turningSharingOffWithSomeoneConnectedLeavesItOn() async throws {
        try SharingStore(location: .file(sharingFile.url)).save(SharingData(connections: [
            SharingConnection(id: UUID(), name: "Riley Park", state: .connected),
        ]))
        record.isOn = true
        let model = await launched()

        #expect(model.sharingOff != .atOnce)
        model.setSharing(on: false)

        #expect(model.isSharingOn)
        #expect(record.isOn)
    }

    /// A reminder received and kept is something shared too.
    @Test func turningSharingOffWithAReceivedReminderLeavesItOn() async throws {
        record.isOn = true
        let model = await launched()
        model.add(Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm, origin: .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 0, state: .accepted)))

        model.setSharing(on: false)

        #expect(model.isSharingOn)
    }

    // MARK: The choice is kept

    @Test func sharingTurnedOnIsStillOnAfterARelaunch() async {
        let first = await launched()
        first.setSharing(on: true)

        let model = await launched()

        #expect(model.isSharingOn)
    }

    /// The switch is the person's lasting choice to share, so a relaunch asks iCloud too, and the
    /// paused messages show without opening Connections first.
    @Test func sharingStillOnAfterARelaunchAsksICloud() async throws {
        let first = await launched()
        first.setSharing(on: true)
        await first.waitUntilApplied()

        let model = await launched()

        let adapter = try #require(adapters.last)
        #expect(adapter.starts == 1)
        #expect(adapter.accountReads == 1)
        #expect(model.sharing?.accountState == .available)
    }

    @Test func sharingTurnedOffIsStillOffAfterARelaunch() async {
        let first = await launched()
        first.setSharing(on: true)
        await first.waitUntilApplied()
        first.setSharing(on: false)

        let model = await launched()

        #expect(!model.isSharingOn)
    }

    /// Before the first unlock after a restart, `UserDefaults` reads nothing, and the store won't
    /// open. Once it does, the record is read again, so Sharing is still on.
    @Test func sharingReadBeforeTheFirstUnlockIsReadAgainOnceTheStoreOpens() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        var storeIsShut = true
        let reminderFile = reminderFile
        let model = AppModel(
            clock: clock,
            openStore: {
                if storeIsShut { throw CocoaError(.fileReadNoPermission) }
                return try ReminderStore(location: .file(reminderFile.url))
            },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            doneQueue: .temporary,
            sharingSwitch: SharingSwitchRecord(defaults: defaults),
            makeSharing: { [clock] in SharingModel(adapter: FakeSharingAdapter(), clock: clock) { try SharingStore(location: .inMemory) } },
            timeZone: NewYork.timeZone
        )
        await model.launch()
        #expect(!model.isSharingOn)

        SharingSwitchRecord(defaults: defaults).isOn = true
        storeIsShut = false
        await model.protectedDataBecameAvailable()

        #expect(model.isSharingOn)
    }
}
