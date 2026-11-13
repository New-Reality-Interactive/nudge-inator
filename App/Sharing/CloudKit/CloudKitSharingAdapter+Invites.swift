import CloudKit
import Foundation

/// Inviting and accepting (#217), apart from the sync the adapter runs: the connection's zone and
/// private share, the system sharing sheet, the invite that reaches the other person, and keeping
/// one person on a share.
extension CloudKitSharingAdapter {
    /// Makes the connection's zone and its private share (or reuses them), shows the system sharing
    /// sheet for it, and returns who the person invited, or `nil` when they sent it to nobody (the
    /// zone is then deleted again). Throws if the zone or share couldn't be made or shown, and then
    /// nothing was sent.
    func invite(_ connectionID: UUID) async throws -> InvitedPerson? {
        start()
        guard let sync, let container else { throw NotAvailableYet() }
        let createdZone = !sync.ownsZone(of: connectionID)
        let zoneID = createdZone ? sync.makeZone(for: connectionID) : CloudKitSync.ownZoneID(of: connectionID)
        keep()
        do {
            let share = try await zoneShare(in: zoneID, container: container)
            try await InviteSheet.present(share: share, container: container)
            // What the sheet saved, as iCloud has it now.
            let fetched = try await container.privateCloudDatabase.record(for: share.recordID)
            let invitees = (fetched as? CKShare).map(InviteParticipant.invitees(of:)) ?? []
            guard let person = InviteParticipant.invitedPerson(among: invitees) else {
                if createdZone { revokeInvite(connectionID) }
                return nil
            }
            // One person per invite: a second person added in the sheet comes off the share.
            if let first = invitees.first(where: { $0.status != .other }), let id = first.id {
                removeOthersOnce(from: connectionID, keeping: id)
            }
            return person
        } catch {
            Self.logger.error("An invite couldn't be made: \(error, privacy: .public)")
            if createdZone { revokeInvite(connectionID) }
            throw error
        }
    }

    /// The zone's share: the one it has already, or a new private one. The zone is saved first,
    /// since a share can only be saved into a zone iCloud has (the engine saves it too; saving it
    /// twice does no harm).
    private func zoneShare(in zoneID: CKRecordZone.ID, container: CKContainer) async throws -> CKShare {
        let database = container.privateCloudDatabase
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        if let existing = try? await database.record(for: shareID) as? CKShare { return existing }
        let share = CloudKitSync.share(for: zoneID)
        share[CKShare.SystemFieldKey.title] = String(localized: "Nudge-inator reminders", comment: "Invite: the title of the share the invite carries.")
        let saved = try await database.modifyRecords(saving: [share], deleting: [])
        guard let result = saved.saveResults[share.recordID] else { throw NotAvailableYet() }
        guard let record = try result.get() as? CKShare else { throw NotAvailableYet() }
        return record
    }

    /// Takes an invite the scene delegate received and tells the app model, which accepts it.
    func receive(_ metadata: CKShare.Metadata) {
        let zoneID = metadata.share.recordID.zoneID
        guard metadata.containerIdentifier == Self.containerIdentifier, let connectionID = UUID(uuidString: zoneID.zoneName) else { return }
        incoming[connectionID] = metadata
        let sender = InviteParticipant.displayName(metadata.ownerIdentity.nameComponents) ?? metadata.ownerIdentity.lookupInfo?.emailAddress
        let invite = IncomingInvite(
            connectionID: connectionID,
            senderName: sender ?? String(localized: "Someone", comment: "Invite: the sender's name when iCloud gives none.")
        )
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

    /// Follows what the system sharing sheet saves, for the log of a device check. What the sheet
    /// saved is read back from iCloud when it closes (`invite`), so this drives nothing.
    func observeSharingSheet(_ container: CKContainer) {
        let observer = CKSystemSharingUIObserver(container: container)
        observer.systemSharingUIDidSaveShareBlock = { _, result in
            Self.logger.notice("The sharing sheet saved a share: \(String(describing: try? result.get().participants.count), privacy: .public) people")
        }
        observer.systemSharingUIDidStopSharingBlock = { _, _ in
            Self.logger.notice("The sharing sheet stopped sharing")
        }
        sharingObserver = observer
    }
}
