import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A change of Apple Account (ticket 212, spec #127 seam 1, decision A13): Alex and Riley,
/// connected through the fake network, and a different Apple Account signing in on Riley's iPhone.
/// What a test asserts is what Riley's app model and sharing store keep, the alarms Riley's phone
/// has scheduled, and what reaches Alex. Layout, landscape, the largest text size and VoiceOver
/// are the phone check.
@MainActor
struct AccountChangeTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Riley's own reminder, Relentless and due at 8:30 every day, so its alarms are scheduled
    /// from the phones' 8:00.
    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .relentless
    )

    /// Alex and Riley, connected and launched, joined by the network.
    func phones() async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected),
        ]))
        network.join(alex.adapter, riley.adapter, through: connectionID)
        for phone in [alex, riley] { await phone.launch() }
        return (alex, riley)
    }

    /// A reminder Alex sent Riley, Relentless unless said otherwise, due at 9:00 every day.
    func received(_ title: String = "Water the plants", strength: Strength = .relentless) -> Reminder {
        Reminder(
            title: title,
            dueTime: NewYork.local(2026, 10, 15, 9),
            repeatRule: .everyDay,
            strength: strength,
            origin: .received(connectionID: connectionID, sendersReminderID: UUID(), revision: 0, state: .accepted)
        )
    }

    func alarmIDs(on phone: Phone) -> Set<UUID> {
        Set(phone.manager.scheduled.map(\.id))
    }

    func pendingIDs(on phone: Phone) -> Set<String> {
        Set(phone.center.pending.map(\.identifier))
    }

    /// A nudge's delivered notification, as the center would hold it after the nudge fired.
    func delivered(_ reminder: Reminder, nudgeAt fireTime: Date) -> String {
        NotificationAdapter.identifier(for: SchedulePlan.Item(
            reminderID: reminder.id, dueTime: reminder.dueTime, nudgeNumber: 1, nudgesInAll: 20, fireTime: fireTime,
            urgency: .normal, title: reminder.title, deliveryKind: .notification, isPastAlarmLimit: false, predictedBadgeCount: 0
        ))
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    // MARK: A different account

    /// Riley's own reminder keeps its tags, its history, its alarms and its notifications. What
    /// was received loses all four, its delivered banners included.
    @Test func aDifferentAccountRemovesWhatWasReceivedAndLeavesThePersonsOwn() async throws {
        let (alex, riley) = try await phones()
        let home = try #require(try riley.model.createTag(named: "home"))
        var own = pills
        own.tagIDs = [home.id]
        // Due at 8:05 every day, and Done at 8:10, so it has a history.
        own.dueTime = NewYork.local(2026, 10, 15, 8, 5)
        riley.model.add(own)
        riley.clock.now = NewYork.local(2026, 10, 15, 8, 10)
        await riley.model.appOpened()
        riley.model.markDone(own.id)
        await settle(riley)
        let ownAlarms = alarmIDs(on: riley)
        let ownPending = pendingIDs(on: riley)
        let ownHistory = try #require(riley.model.engine.histories[own.id])
        let water = received()
        let cat = received("Feed the cat", strength: .firm)
        riley.model.add(water)
        riley.model.add(cat)
        await settle(riley)
        #expect(alarmIDs(on: riley) != ownAlarms)
        #expect(pendingIDs(on: riley) != ownPending)
        let ownDelivered = delivered(own, nudgeAt: NewYork.local(2026, 10, 15, 8, 5))
        riley.center.delivered = [delivered(cat, nudgeAt: NewYork.local(2026, 10, 15, 9)), ownDelivered]

        riley.adapter.signIn(as: "another-account")
        await settle(alex, riley)

        #expect(riley.model.engine.reminders.map(\.id) == [own.id])
        #expect(riley.model.engine.reminders.first?.tagIDs == [home.id])
        #expect(riley.model.engine.tags.map(\.name) == ["home"])
        #expect(riley.model.engine.histories[own.id] == ownHistory)
        #expect(riley.model.engine.histories[water.id] == nil)
        #expect(alarmIDs(on: riley) == ownAlarms)
        #expect(pendingIDs(on: riley) == ownPending)
        #expect(riley.center.delivered == [ownDelivered])
        riley.relaunch()
        await riley.launch()
        #expect(riley.model.engine.reminders.map(\.id) == [own.id])
    }

    @Test func aDifferentAccountRemovesTheOldAccountsSharingAndSaysWhat() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        riley.model.add(received("Feed the cat"))
        try riley.model.send(pills, to: [connectionID])
        riley.adapter.inviteAnswer = .names(InvitedPerson(name: "Sam Rivera", address: "sam@example.com"))
        _ = try await riley.sharing.invite()
        await settle(alex, riley)

        riley.adapter.signIn(as: "another-account")
        await settle(alex, riley)

        let data = riley.sharing.data
        #expect(data.connections.isEmpty)
        #expect(data.sentReminders.isEmpty)
        #expect(data.sentCopies.isEmpty)
        #expect(data.receivedSyncStates.isEmpty)
        #expect(data.outbox.isEmpty)
        #expect(riley.sharing.accountChangeNote == AccountChangeNote(
            receivedCount: 2, senders: ["Alex Morgan"], connections: ["Alex Morgan", "Sam Rivera"], sentCount: 1
        ))
    }

    /// Alex's side is as it was: nothing reached Alex from the change, and a change Riley made
    /// offline under the old account never does.
    @Test func whatTheOldAccountHadNotSentIsNeverSent() async throws {
        let (alex, riley) = try await phones()
        riley.adapter.isOnline = false
        try riley.model.send(pills, to: [connectionID])
        await settle(alex, riley)

        riley.adapter.signIn(as: "another-account")
        riley.adapter.isOnline = true
        await settle(alex, riley)

        #expect(alex.model.engine.reminders.isEmpty)
        #expect(alex.sharing.isConnected(connectionID))
        #expect(riley.sharing.data.outbox.isEmpty)
    }

    @Test func theNoteStaysAcrossARelaunchUntilThePersonHasSeenIt() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        riley.adapter.signIn(as: "another-account")
        await settle(alex, riley)

        riley.relaunch()
        await riley.launch()
        #expect(riley.sharing.accountChangeNote?.receivedCount == 1)

        try riley.sharing.dismissAccountChangeNote()
        riley.relaunch()
        await riley.launch()
        #expect(riley.sharing.accountChangeNote == nil)
    }

    /// Two changes before the person has seen the first note: one note, saying what both removed.
    @Test func aSecondChangeBeforeTheNoteIsSeenAddsToIt() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        riley.adapter.signIn(as: "second-account")
        await settle(alex, riley)
        riley.adapter.inviteAnswer = .names(InvitedPerson(name: "Sam Rivera", address: "sam@example.com"))
        _ = try await riley.sharing.invite()

        riley.adapter.signIn(as: "third-account")
        await settle(alex, riley)

        #expect(riley.sharing.accountChangeNote == AccountChangeNote(
            receivedCount: 1, senders: ["Alex Morgan"], connections: ["Alex Morgan", "Sam Rivera"], sentCount: 0
        ))
    }

    // MARK: Nothing removed

    /// Signing out pauses sharing (ticket 210); signing back in to the same account resumes it.
    @Test(arguments: SharingPausedTests.pausedAccounts)
    func signingOutAndBackInToTheSameAccountRemovesNothing(account: SharingAccountState) async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        await settle(riley)
        let before = riley.sharing.data

        riley.adapter.account = account
        await settle(alex, riley)
        riley.adapter.account = .available
        await settle(alex, riley)

        #expect(riley.model.engine.reminders.count == 1)
        #expect(riley.sharing.data == before)
        #expect(riley.sharing.accountChangeNote == nil)
    }

    /// Sharing kept before the adapter reported any account (as the Debug stand-in's seed is) is
    /// that account's: the first ID is recorded and removes nothing.
    @Test func theFirstAccountReportedIsRecordedAndRemovesNothing() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        await settle(alex, riley)

        #expect(riley.sharing.data.accountID == riley.adapter.accountID)
        #expect(riley.sharing.isConnected(connectionID))
        #expect(riley.model.engine.reminders.count == 1)
        #expect(riley.sharing.accountChangeNote == nil)
    }

    @Test func aDifferentAccountWithNothingSharedHasNoNote() async throws {
        let riley = try Phone()
        await riley.launch()
        riley.model.add(pills)

        riley.adapter.signIn(as: "another-account")
        await settle(riley)

        #expect(riley.sharing.data.accountID == AppleAccountID("another-account"))
        #expect(riley.sharing.accountChangeNote == nil)
        #expect(riley.model.engine.reminders.count == 1)
    }

    // MARK: When it's found

    /// A different account signed in while the app was suspended, so no event came: App opened
    /// reads the account again and finds it.
    @Test func aChangeTheAppWasntToldOfIsFoundOnAppOpened() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        await settle(riley)

        riley.adapter.signIn(as: "another-account", tellingTheApp: false)
        await settle(alex, riley)
        #expect(riley.model.engine.reminders.count == 1)

        await riley.model.appOpened()
        await settle(alex, riley)
        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.sharing.accountChangeNote?.receivedCount == 1)
    }

    /// A sharing store that won't open removes nothing, reminders included, and the change is
    /// applied once it opens.
    @Test func aSharingStoreThatWontOpenRemovesNothingUntilItDoes() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        await settle(riley)
        riley.sharingStoreOpens = false
        riley.relaunch()
        await riley.launch()

        riley.adapter.signIn(as: "another-account")
        await settle(alex, riley)
        #expect(riley.model.engine.reminders.count == 1)

        riley.sharingStoreOpens = true
        await riley.model.appOpened()
        await settle(alex, riley)
        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.sharing.accountChangeNote?.receivedCount == 1)
    }
}

/// The Apple Account Changed note's rows (ticket 212, the mockup's `accountSheet`): what was
/// removed, a row with nothing in it left out.
struct AccountChangeNoteRowsTests {
    @Test func everyKindRemovedHasItsRowInTheMockupsOrder() {
        let note = AccountChangeNote(receivedCount: 5, senders: ["Maya Torres", "Sam Okafor"], connections: ["Maya Torres", "Sam Okafor", "Jordan Lee"], sentCount: 2)

        #expect(note.rows == [
            .received(count: 5, senders: "Maya Torres and Sam Okafor"),
            .connections(count: 3, names: "Maya Torres, Sam Okafor, and Jordan Lee"),
            .sent(count: 2),
        ])
    }

    @Test func aKindWithNothingRemovedHasNoRow() {
        let note = AccountChangeNote(receivedCount: 0, senders: [], connections: ["Jordan Lee"], sentCount: 0)

        #expect(note.rows == [.connections(count: 1, names: "Jordan Lee")])
    }
}
