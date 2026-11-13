import Testing
@testable import NudgeInator

/// The rules for who an invite went to and who stays on its share (#217, seam 1).
struct InviteParticipantsTests {
    let owner = InviteParticipant(id: "_owner", isOwner: true, status: .accepted)
    let sam = InviteParticipant(id: "_sam", status: .accepted, name: "Sam Lee", address: "sam@example.com")
    let pat = InviteParticipant(id: "_pat", status: .pending, name: nil, address: "+15555550100")

    @Test func theInvitedPersonIsNamedByNameOrElseAddress() {
        #expect(InviteParticipant.invitedPerson(among: [owner, sam]) == InvitedPerson(name: "Sam Lee", address: "sam@example.com"))
        #expect(InviteParticipant.invitedPerson(among: [owner, pat]) == InvitedPerson(name: "+15555550100", address: "+15555550100"))
    }

    @Test func aSheetThatInvitedNobodyNamesNobody() {
        #expect(InviteParticipant.invitedPerson(among: [owner]) == nil)
        #expect(InviteParticipant.invitedPerson(among: []) == nil)
    }

    @Test func theFirstToAcceptStaysAndTheRestComeOff() {
        let late = InviteParticipant(id: "_late", status: .accepted)
        let first = InviteParticipant.firstToAccept(among: [owner, pat, sam, late])
        #expect(first?.id == "_sam")
        #expect(InviteParticipant.toRemove(from: [owner, pat, sam, late], keeping: "_sam").map(\.id) == ["_pat", "_late"])
    }

    @Test func nobodyHasAcceptedYet() {
        #expect(InviteParticipant.firstToAccept(among: [owner, pat]) == nil)
    }

    @Test func theOwnerIsNeverRemoved() {
        #expect(InviteParticipant.toRemove(from: [owner], keeping: "_sam").isEmpty)
    }
}
