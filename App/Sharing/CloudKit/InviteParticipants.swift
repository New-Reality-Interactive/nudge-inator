import CloudKit
import Foundation

/// What the invite code needs to know of one person on a connection's share, so the rules below
/// run on plain values (a `CKShare.Participant` can't be made in a test).
struct InviteParticipant: Equatable {
    enum Status: Equatable {
        case pending
        case accepted
        case other
    }

    /// iCloud's ID for their account (user record name), or `nil` before iCloud knows it.
    var id: String?
    var isOwner: Bool
    var status: Status
    var name: String?
    /// The email address or phone number the invite was sent to.
    var address: String?

    init(id: String?, isOwner: Bool = false, status: Status, name: String? = nil, address: String? = nil) {
        self.id = id
        self.isOwner = isOwner
        self.status = status
        self.name = name
        self.address = address
    }

    init(_ participant: CKShare.Participant) {
        let identity = participant.userIdentity
        let name = Self.displayName(identity.nameComponents)
        let status: Status = switch participant.acceptanceStatus {
        case .accepted: .accepted
        case .pending: .pending
        default: .other
        }
        self.init(
            id: identity.userRecordID?.recordName,
            isOwner: participant.role == .owner,
            status: status,
            name: name,
            address: identity.lookupInfo?.emailAddress ?? identity.lookupInfo?.phoneNumber
        )
    }

    /// The name as the person's iCloud gives it, or `nil` when it has none.
    static func displayName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = PersonNameComponentsFormatter().string(from: components)
        return name.isEmpty ? nil : name
    }

    /// The people on a share other than its owner.
    static func invitees(of share: CKShare) -> [InviteParticipant] {
        share.participants.map(InviteParticipant.init).filter { !$0.isOwner }
    }

    /// Who an invite went to: the one person on the share, or `nil` when the sheet sent it to
    /// nobody. With several, the first: the app invites one person.
    static func invitedPerson(among participants: [InviteParticipant]) -> InvitedPerson? {
        guard let first = participants.first(where: { !$0.isOwner && $0.status != .other }) else { return nil }
        guard let label = first.name ?? first.address else { return nil }
        return InvitedPerson(name: label, address: first.address ?? label)
    }

    /// The person to keep on the share, one person per invite (spec #127, A6): the first to accept.
    static func firstToAccept(among participants: [InviteParticipant]) -> InviteParticipant? {
        participants.first { !$0.isOwner && $0.status == .accepted && $0.id != nil }
    }

    /// Everyone on the share except the owner and `kept`, who must come off it.
    static func toRemove(from participants: [InviteParticipant], keeping kept: String) -> [InviteParticipant] {
        participants.filter { !$0.isOwner && $0.id != kept }
    }
}
