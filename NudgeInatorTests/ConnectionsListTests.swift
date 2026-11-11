import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// What Settings › Connections lists (ticket 194): the connected, then the invited, in the order
/// the store keeps them, and the mismatch help on an Invited row once its invite is 2 days old.
struct ConnectionsListTests {
    let now = NewYork.local(2026, 10, 15, 8)
    let calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NewYork.timeZone
        return calendar
    }()

    func invite(_ name: String, sentAt: Date) -> SharingConnection {
        SharingConnection(id: UUID(), name: name, state: .invited, address: "\(name)@icloud.com", invitedAt: sentAt)
    }

    @Test func noConnectionsAndNoInvitesIsTheEmptyState() {
        let list = ConnectionsList(SharingData(), now: now, calendar: calendar)

        #expect(list.isEmpty)
        #expect(list.connected.isEmpty)
        #expect(list.invited.isEmpty)
    }

    @Test func connectedAndInvitedAreListedApartInTheStoresOrder() {
        let sam = SharingConnection(id: UUID(), name: "Sam", state: .connected)
        let jordan = invite("Jordan", sentAt: now)
        let riley = SharingConnection(id: UUID(), name: "Riley", state: .connected, theirs: ConnectionChoices(sharesStatus: false))
        let priya = invite("Priya", sentAt: now)

        let list = ConnectionsList(SharingData(connections: [sam, jordan, riley, priya]), now: now, calendar: calendar)

        #expect(!list.isEmpty)
        #expect(list.connected == [sam, riley])
        #expect(list.invited.map(\.connection) == [jordan, priya])
    }

    /// iCloud doesn't tell the sender an invite failed to open, so the help shows on the row once
    /// the invite has waited 2 days (the mockup's rule), counted in calendar days.
    @Test(arguments: [
        (NewYork.local(2026, 10, 15, 7), false),
        (NewYork.local(2026, 10, 14, 7), false),
        (NewYork.local(2026, 10, 13, 23, 59), true),
        (NewYork.local(2026, 10, 10, 9), true),
    ])
    func anInvitedRowOffersHelpOnceItsInviteIsTwoDaysOld(sentAt: Date, showsHelp: Bool) {
        let list = ConnectionsList(SharingData(connections: [invite("Jordan", sentAt: sentAt)]), now: now, calendar: calendar)

        #expect(list.invited.first?.showsMismatchHelp == showsHelp)
    }

    /// The page reads the list through the model, whose clock says what now is.
    @MainActor
    @Test func theModelsListUsesItsClock() async throws {
        let sentAt = NewYork.local(2026, 10, 15, 8)
        let phone = try SharingAdapterTests.Phone(seed: SharingData(connections: [invite("Jordan", sentAt: sentAt)]))
        await phone.launch()

        #expect(phone.sharing.connectionsList(calendar: calendar).invited.first?.showsMismatchHelp == false)
        phone.clock.now = NewYork.local(2026, 10, 17, 8)
        #expect(phone.sharing.connectionsList(calendar: calendar).invited.first?.showsMismatchHelp == true)
    }
}
