import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// What the sender is told (ticket 208, spec #127 seam 1): Alex sends Riley a reminder, Riley's app
/// reports how the copy is going through the fake network, and the tests read the notifications Alex's
/// notification center was handed. How a banner looks and reads is the phone check.
@MainActor
struct SenderNoticesTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm: the phones' clocks say 8:00 on 15 October.
    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm,
        pace: .consistent(wait: 10 * 60)
    )

    /// Due at 9:00 today, once, Gentle.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 15, 9, 0), strength: .gentle)

    func phones(sharesStatus: Bool = true, deliveryMode: DeliveryMode = .startRightAway) async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected, theirs: ConnectionChoices(sharesStatus: sharesStatus, deliveryMode: deliveryMode)),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(sharesStatus: sharesStatus, deliveryMode: deliveryMode)),
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

    func send(_ reminder: Reminder, from alex: Phone, to riley: Phone) async throws {
        try alex.model.send(reminder, to: [connectionID])
        await settle(alex, riley)
    }

    /// Riley's phone at `hour`:`minute` on 15 October, the app opened there.
    func open(_ riley: Phone, at hour: Int, _ minute: Int, alex: Phone) async {
        riley.clock.now = NewYork.local(2026, 10, 15, hour, minute)
        await riley.model.appOpened()
        await settle(alex, riley)
    }

    func copy(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    /// Notifications that aren't nudges, as the phone's center was handed them.
    func notices(on phone: Phone) -> [(identifier: String, title: String, body: String)] {
        phone.center.added.filter { !$0.identifier.hasPrefix("nudge.") }.map { ($0.identifier, $0.content.title, $0.content.body) }
    }

    @Test func theSenderIsToldWhenAOneOffCopyIsMarkedDone() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        await open(riley, at: 9, 5, alex: alex)
        #expect(notices(on: alex).isEmpty)

        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)

        let told = notices(on: alex)
        #expect(told.count == 1)
        #expect(told.first?.title == "Call the clinic")
        #expect(told.first?.body == "Riley Park marked it Done")
    }

    /// A repeating copy's label reads Coming up again once today's occurrence is Done.
    @Test func theSenderIsToldWhenARepeatingCopyIsMarkedDone() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 35, alex: alex)

        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)

        #expect(notices(on: alex).map(\.body) == ["Riley Park marked it Done"])
    }

    @Test func theSenderIsToldWhenTheCopyIsRemoved() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        riley.model.delete(try copy(on: riley).id)
        await settle(alex, riley)

        let told = notices(on: alex)
        #expect(told.map(\.title) == ["Take the pills"])
        #expect(told.map(\.body) == ["Riley Park removed it"])
    }

    /// Reported when Riley's app works out the close, which may be long after the give-up limit.
    @Test func theSenderIsToldOfAMissedWhenTheRecipientsAppWorksItOut() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        #expect(notices(on: alex).isEmpty)

        riley.clock.now = NewYork.local(2026, 10, 16, 8)
        await riley.model.appOpened()
        await settle(alex, riley)

        #expect(notices(on: alex).map(\.body) == ["Missed: Riley Park didn't mark it Done"])
    }

    @Test func pauseResumeAndSkippedShowOnlyInTheApp() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 35, alex: alex)

        riley.model.pause(try copy(on: riley).id)
        await settle(alex, riley)
        try riley.model.resume(try copy(on: riley).id)
        await open(riley, at: 8, 40, alex: alex)

        #expect(notices(on: alex).isEmpty)
    }

    @Test func withStatusSharingOffTheSenderIsToldNothing() async throws {
        let (alex, riley) = try await phones(sharesStatus: false)
        try await send(call, from: alex, to: riley)
        await open(riley, at: 9, 5, alex: alex)
        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)
        riley.model.delete(try copy(on: riley).id)
        await settle(alex, riley)

        #expect(notices(on: alex).isEmpty)
    }

    @Test func dontShareThisOneTellsTheSenderNothingAndSharingItAgainIsNotNews() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        try riley.model.setNotSharing(true, for: try copy(on: riley).id)
        await open(riley, at: 9, 5, alex: alex)
        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)
        #expect(notices(on: alex).isEmpty)

        try riley.model.setNotSharing(false, for: try copy(on: riley).id)
        await settle(alex, riley)

        #expect(notices(on: alex).isEmpty)
        #expect(alex.sharing.data.sentCopies.first?.statusRecord?.report.label == .done)
    }

    @Test func turningStatusSharingBackOnShowsTheCurrentStatusWithoutANotice() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        try riley.sharing.change(ConnectionChoices(sharesStatus: false), for: connectionID)
        await open(riley, at: 9, 5, alex: alex)
        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)

        try riley.sharing.change(ConnectionChoices(sharesStatus: true), for: connectionID)
        await settle(alex, riley)

        #expect(alex.sharing.data.sentCopies.first?.statusRecord?.report.label == .done)
        #expect(notices(on: alex).isEmpty)
    }

    /// A relaunch re-sends each copy's current status once.
    @Test func aRelaunchOfTheRecipientTellsTheSenderNothingMore() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        await open(riley, at: 9, 5, alex: alex)
        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)
        let before = notices(on: alex).count

        riley.relaunch()
        await riley.launch()
        await open(riley, at: 9, 6, alex: alex)

        #expect(before == 1)
        #expect(notices(on: alex).count == before)
    }

    @Test func aRelaunchOfTheSenderHoldingTheStatusTellsNothingMore() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        await open(riley, at: 9, 5, alex: alex)
        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)
        let before = notices(on: alex).count

        alex.relaunch()
        await alex.launch()
        riley.relaunch()
        await riley.launch()
        await open(riley, at: 9, 6, alex: alex)

        #expect(notices(on: alex).count == before)
    }

    @Test func aRecipientAwayForDaysMakesOneNoticeForTheLatestOccurrence() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        riley.clock.now = NewYork.local(2026, 10, 18, 7)
        await riley.model.appOpened()
        await settle(alex, riley)

        #expect(notices(on: alex).count == 1)
        #expect(notices(on: alex).first?.body == "Missed: Riley Park didn't mark it Done")
    }

    @Test func eachOccurrencesNoticeHasItsOwnIdentifierAndTheSameOneReplacesItself() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 35, alex: alex)
        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)
        riley.clock.now = NewYork.local(2026, 10, 16, 8, 35)
        await riley.model.appOpened()
        await settle(alex, riley)
        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)

        let identifiers = notices(on: alex).map(\.identifier)
        #expect(identifiers.count == 2)
        #expect(Set(identifiers).count == 2)
        #expect(identifiers.allSatisfy { $0.hasPrefix("sent.") })
    }

    /// #200's arrival and #204's change are the recipient's: the sender's notices don't touch them.
    @Test func theRecipientsOwnNoticesAreUnchanged() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)

        #expect(notices(on: riley).map(\.identifier).allSatisfy { $0.hasPrefix("arrival.") })
        #expect(notices(on: riley).count == 1)
        #expect(notices(on: alex).isEmpty)
    }
}
