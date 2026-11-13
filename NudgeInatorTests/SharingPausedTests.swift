import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Sharing paused without iCloud (ticket 210, spec #127 seam 1): Alex and Riley, connected through
/// the fake network, and Alex's iCloud account reported as missing, restricted or temporarily
/// unavailable. What a test asserts is what each app model and sharing store keeps, and what the
/// adapter was handed. Layout, landscape, the largest text size and VoiceOver are the phone check.
@MainActor
struct SharingPausedTests {
    typealias Phone = SharingAdapterTests.Phone

    nonisolated static let pausedAccounts: [SharingAccountState] = [.noAccount, .restricted, .temporarilyUnavailable]

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm: the phones' clocks say 8:00.
    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm
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

    /// `phone`'s account becomes `state`, and the model has read it.
    func setAccount(_ state: SharingAccountState, on phone: Phone) async {
        phone.adapter.account = state
        await phone.model.waitUntilApplied()
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    // MARK: Nothing is sent

    @Test(arguments: pausedAccounts)
    func aSendWhilePausedKeepsAndSendsNothing(account: SharingAccountState) async throws {
        let (alex, riley) = try await phones()
        await setAccount(account, on: alex)

        #expect(throws: SharingModel.SharingPaused.self) {
            try alex.model.send(pills, to: [connectionID])
        }
        await settle(alex, riley)

        #expect(alex.sharing.data.sentReminders.isEmpty)
        #expect(alex.sharing.data.sentCopies.isEmpty)
        #expect(alex.sharing.data.outbox.isEmpty)
        #expect(alex.adapter.submitted.isEmpty)
        #expect(riley.model.engine.reminders.isEmpty)
    }

    @Test(arguments: pausedAccounts)
    func anInviteWhilePausedIsTurnedDownBeforeTheSharingSheet(account: SharingAccountState) async throws {
        let (alex, _) = try await phones()
        alex.adapter.inviteAnswer = .names(InvitedPerson(name: "Sam Rivera", address: "sam@example.com"))
        await setAccount(account, on: alex)

        await #expect(throws: SharingModel.SharingPaused.self) {
            _ = try await alex.sharing.invite()
        }

        #expect(alex.adapter.invites.isEmpty)
        #expect(alex.sharing.data.connections.map(\.name) == ["Riley Park"])
    }

    @Test func onceICloudIsBackASendGoesThrough() async throws {
        let (alex, riley) = try await phones()
        await setAccount(.noAccount, on: alex)
        await setAccount(.available, on: alex)

        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)

        #expect(alex.sharing.data.sentReminders.map(\.reminder.title) == ["Take the pills"])
        #expect(riley.model.engine.reminders.map(\.title) == ["Take the pills"])
    }

    // MARK: Nothing else changes

    @Test(arguments: pausedAccounts)
    func aReminderReceivedWhilePausedIsKeptAndNudges(account: SharingAccountState) async throws {
        let (alex, riley) = try await phones()
        await setAccount(account, on: riley)

        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)

        let copy = try #require(riley.model.engine.reminders.first)
        #expect(copy.isReceived)
        #expect(!riley.center.pending.isEmpty)
    }

    @Test(arguments: pausedAccounts)
    func aReminderReceivedBeforeThePauseKeepsItsNudges(account: SharingAccountState) async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        let pending = riley.center.pending.map(\.identifier)

        await setAccount(account, on: riley)
        await riley.model.appOpened()
        await settle(alex, riley)

        #expect(riley.model.engine.reminders.map(\.title) == ["Take the pills"])
        #expect(riley.center.pending.map(\.identifier) == pending)
    }

    @Test(arguments: pausedAccounts)
    func whatWaitsToSyncStaysInTheOutboxWhilePaused(account: SharingAccountState) async throws {
        let (alex, riley) = try await phones()
        alex.adapter.isOnline = false
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        let waiting = alex.sharing.data.outbox

        await setAccount(account, on: alex)
        await settle(alex, riley)

        #expect(waiting.count == 1)
        #expect(alex.sharing.data.outbox == waiting)
        #expect(alex.sharing.data.sentReminders.map(\.reminder.title) == ["Take the pills"])
    }

    // MARK: What the screens say

    /// The mockup's `sharingBanner` and `sendToSection`, for each reason.
    @Test(arguments: [
        (SharingReach.Pause.noAccount,
         "**Sharing is paused.** Sign in to iCloud in iOS Settings to send and receive reminders. Reminders you've received keep nudging.",
         "Sharing is paused. Sign in to iCloud in iOS Settings to send and receive reminders.",
         true),
        (.restricted,
         "**Sharing is paused.** iCloud is restricted on this iPhone. Screen Time or whoever manages it can change that. Reminders you've received keep nudging.",
         "Sharing is paused. iCloud is restricted on this iPhone. Screen Time or whoever manages it can change that.",
         true),
        // It starts again by itself, so there's nothing to open.
        (.temporarilyUnavailable,
         "**Sharing is paused.** iCloud isn't available right now. Sharing starts again by itself. Reminders you've received keep nudging.",
         "Sharing is paused. iCloud isn't available right now. Sharing starts again by itself.",
         false),
    ])
    func thePausedMessageSaysWhyAndWhatToDo(pause: SharingReach.Pause, banner: String, footer: String, offersOpenSettings: Bool) {
        #expect(String(localized: pause.bannerText) == banner)
        #expect(String(localized: pause.sendToFooter) == footer)
        #expect(pause.offersOpenSettings == offersOpenSettings)
    }

    @Test(arguments: pausedAccounts)
    func thePausedReasonComesFromTheAccount(account: SharingAccountState) async throws {
        let (alex, _) = try await phones()
        await setAccount(account, on: alex)

        #expect(alex.sharing.pause == account.reach.pause)
        #expect(alex.sharing.pause != nil)
    }

    @Test func workingSharingHasNoPausedMessage() async throws {
        let (alex, _) = try await phones()

        #expect(alex.sharing.pause == nil)
    }

    // MARK: The form's Send To

    /// A New form on `phone`, filled in as `pills`.
    func form(on phone: Phone) -> ReminderForm {
        let form = ReminderForm(engine: { phone.model.engine }, now: { phone.clock.now }, defaultPace: .shipped, sharing: phone.model.sharing)
        form.title = pills.title
        form.dueTime = pills.dueTime
        form.repeatRule = pills.repeatRule
        form.strength = pills.strength
        return form
    }

    @Test(arguments: pausedAccounts)
    func sendToIsShownOffWithTheReason(account: SharingAccountState) async throws {
        let (alex, _) = try await phones()
        await setAccount(account, on: alex)

        let form = form(on: alex)

        #expect(form.offersSendTo)
        #expect(form.sendToPause == account.reach.pause)
        #expect(form.recipients.isEmpty)
        #expect(form.showsTags)
    }

    @Test func whoWasChosenIsLeftOutWhilePausedAndComesBackAfter() async throws {
        let (alex, riley) = try await phones()
        let form = form(on: alex)
        form.toggleRecipient(connectionID)

        await setAccount(.temporarilyUnavailable, on: alex)
        #expect(form.recipients.isEmpty)
        #expect(form.recipientsText == nil)

        await setAccount(.available, on: alex)
        #expect(form.sendToPause == nil)
        #expect(form.recipients == [connectionID])
        #expect(form.save(to: alex.model))
        await settle(alex, riley)
        #expect(riley.model.engine.reminders.map(\.title) == ["Take the pills"])
    }

    @Test func addWhilePausedSendsNothing() async throws {
        let (alex, riley) = try await phones()
        let form = form(on: alex)
        form.toggleRecipient(connectionID)
        await setAccount(.noAccount, on: alex)

        _ = form.save(to: alex.model)
        await settle(alex, riley)

        #expect(alex.adapter.submitted.isEmpty)
        #expect(alex.sharing.data.sentReminders.isEmpty)
        #expect(riley.model.engine.reminders.isEmpty)
    }
}

