import Testing
@testable import NudgeInator

/// The rules for who stays on an invite's share: the first to accept (#217, seam 1).
struct InviteParticipantsTests {
    let owner = InviteParticipant(id: "_owner", isOwner: true, status: .accepted)
    let sam = InviteParticipant(id: "_sam", status: .accepted, name: "Sam Lee", address: "sam@example.com")
    let pat = InviteParticipant(id: "_pat", status: .pending, name: nil, address: "+15555550100")

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
