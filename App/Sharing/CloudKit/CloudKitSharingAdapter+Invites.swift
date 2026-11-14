import CloudKit
import Foundation
import NudgeEngine
import UIKit

/// Inviting and accepting (#217), apart from the sync the adapter runs: the connection's zone and
/// private share, the invite that reaches the other person, and keeping one person on a share.
extension CloudKitSharingAdapter {
    /// Makes the connection's zone and a private share, adds `person` to it with read-write
    /// permission, and has `delivery` hand the share's link to the person by `route`. Returns
    /// `false`, with the zone deleted again, when the delivery was canceled. Throws if the zone or
    /// share couldn't be made or the address has no Apple Account, and then nothing was sent.
    func invite(_ connectionID: UUID, to person: InvitedPerson, via route: InviteRoute) async throws -> Bool {
        start()
        guard let sync, let container else { throw NotAvailableYet() }
        let zoneID = sync.makeZone(for: connectionID)
        keep()
        do {
            let link = try await shareLink(in: zoneID, for: person, container: container)
            guard await delivery.deliver(link, to: person, via: route) else {
                revokeInvite(connectionID)
                return false
            }
            return true
        } catch {
            Self.logger.error("An invite couldn't be made: \(error, privacy: .public)")
            revokeInvite(connectionID)
            throw error
        }
    }

    /// The link of a new private share of the zone with `person` on it. The zone is saved first,
    /// since a share can only be saved into a zone iCloud has (the engine saves it too; saving it
    /// twice does no harm). Only the person added can open the link.
    private func shareLink(in zoneID: CKRecordZone.ID, for person: InvitedPerson, container: CKContainer) async throws -> URL {
        let database = container.privateCloudDatabase
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        let participant = try await shareParticipant(for: person, container: container)
        participant.permission = .readWrite
        let share = CloudKitSync.share(for: zoneID)
        share[CKShare.SystemFieldKey.title] = String(localized: "Nudge-inator Reminders", comment: "Invite: the title of the share the invite carries, which the invitation shows.")
        share[CKShare.SystemFieldKey.thumbnailImageData] = Self.appIconData()
        share.addParticipant(participant)
        let saved = try await database.modifyRecords(saving: [share], deleting: [])
        guard let result = saved.saveResults[share.recordID] else { throw NotAvailableYet() }
        guard let record = try result.get() as? CKShare, let url = record.url else { throw NotAvailableYet() }
        return url
    }

    /// iCloud's participant for the person's Apple Account, looked up by the address. Throws when
    /// the address has none, or iCloud can't be reached.
    private func shareParticipant(for person: InvitedPerson, container: CKContainer) async throws -> CKShare.Participant {
        // The sheet only sends an address of a known kind, so anything else is a bug, not a typo.
        guard let kind = InviteAddressKind(address: person.address) else { throw NotAvailableYet() }
        let key = kind.lookupKey(for: person.address)
        let results = switch kind {
        case .phone: try await container.shareParticipants(forPhoneNumbers: [key])
        case .email: try await container.shareParticipants(forEmailAddresses: [key])
        }
        guard let result = results[key] ?? results.values.first else { throw NotAvailableYet() }
        return try result.get()
    }

    /// The app icon as PNG data, from the icon files the build puts in the bundle, or `nil` when
    /// there are none: the invitation then shows a generic picture.
    private static func appIconData() -> Data? {
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let names = primary?["CFBundleIconFiles"] as? [String] ?? []
        return names.reversed().lazy.compactMap { UIImage(named: $0)?.pngData() }.first
    }

    /// The invite a share's metadata carries, or `nil` when it isn't one for this app.
    static func incomingInvite(from metadata: CKShare.Metadata) -> IncomingInvite? {
        let zoneID = metadata.share.recordID.zoneID
        guard metadata.containerIdentifier == containerIdentifier, let connectionID = UUID(uuidString: zoneID.zoneName) else { return nil }
        let sender = InviteParticipant.displayName(metadata.ownerIdentity.nameComponents) ?? metadata.ownerIdentity.lookupInfo?.emailAddress
        return IncomingInvite(
            connectionID: connectionID,
            senderName: sender ?? String(localized: "Someone", comment: "Invite: the sender's name when iCloud gives none.")
        )
    }

    /// Takes an invite the scene delegate received and tells the app model, which accepts it.
    func receive(_ metadata: CKShare.Metadata) {
        guard let invite = Self.incomingInvite(from: metadata) else { return }
        incoming[invite.connectionID] = metadata
        Task { await events?.invited(invite) }
    }

    func accept(_ connectionID: UUID) async throws {
        start()
        guard let sync, let container else { throw NotAvailableYet() }
        // Already joined (the invite was tapped twice): accepting again does no harm.
        if sync.hasJoinedZone(of: connectionID) { return }
        guard let metadata = incoming[connectionID], metadata.participantStatus != .removed else { throw InviteUnavailable() }
        if metadata.participantStatus == .pending {
            do {
                _ = try await container.accept(metadata)
            } catch let error as CKError where [.unknownItem, .permissionFailure].contains(error.code) {
                // Taken off the share: canceled, or someone else was first.
                Self.logger.notice("An invite is no longer available: \(error.code.rawValue)")
                incoming[connectionID] = nil
                throw InviteUnavailable()
            }
        }
        incoming[connectionID] = nil
        sync.joinZone(metadata.share.recordID.zoneID)
        keep()
        try? await engines[.shared]?.fetchChanges()
    }

    /// One person per invite: takes everyone but `participant` off the connection's share.
    func keepOnly(_ participant: SharingParticipant, in connectionID: UUID) {
        start()
        removeOthersOnce(from: connectionID, keeping: participant.id)
    }

    /// Starts taking the others off the share, unless that is under way: the edit is the same
    /// either way, and two saves at once could conflict.
    func removeOthersOnce(from connectionID: UUID, keeping kept: String) {
        guard removing.insert(connectionID).inserted else { return }
        Task {
            await removeOthers(from: connectionID, keeping: kept)
            removing.remove(connectionID)
        }
    }

    private func removeOthers(from connectionID: UUID, keeping kept: String) async {
        guard let container, sync?.ownsZone(of: connectionID) == true else { return }
        let database = container.privateCloudDatabase
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: CloudKitSync.ownZoneID(of: connectionID)))
            guard let share = record as? CKShare else { return }
            let remove = InviteParticipant.toRemove(from: InviteParticipant.invitees(of: share), keeping: kept)
            guard !remove.isEmpty else { return }
            for participant in share.participants where remove.contains(where: { $0.id == participant.userIdentity.userRecordID?.recordName }) {
                share.removeParticipant(participant)
            }
            _ = try await database.modifyRecords(saving: [share], deleting: [])
        } catch {
            // The next fetch of the share tries again.
            Self.logger.error("Other people couldn't be taken off a share: \(error, privacy: .public)")
        }
    }
}
