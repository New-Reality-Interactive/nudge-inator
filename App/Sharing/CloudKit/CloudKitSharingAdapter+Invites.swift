import CloudKit
import Foundation
import UIKit

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
            let started = ContinuousClock.now
            let share = try await zoneShare(in: zoneID, container: container, isNewZone: createdZone)
            Self.logger.notice("Share ready for the sheet after \(started.duration(to: .now), privacy: .public)")
            try await InviteSheet.present(share: share, container: container)
            // What the sheet saved, as iCloud has it. A person invited through Messages can join the
            // share a few seconds after the sheet closes, so it is read again for a while before the
            // invite counts as sent to nobody.
            let invitees = try await inviteesAfterSheet(share.recordID, in: container.privateCloudDatabase)
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

    private func inviteesAfterSheet(_ shareID: CKRecord.ID, in database: CKDatabase) async throws -> [InviteParticipant] {
        let attempts = 6
        for attempt in 1...attempts {
            if attempt > 1 { try await Task.sleep(for: .seconds(2)) }
            guard let share = try await database.record(for: shareID) as? CKShare else { return [] }
            // Never public, whatever the sheet's Copy Link offers.
            if share.publicPermission != .none {
                Self.logger.notice("A share was public after the sheet; making it private again")
                share.publicPermission = .none
                _ = try? await database.modifyRecords(saving: [share], deleting: [])
            }
            let invitees = InviteParticipant.invitees(of: share)
            Self.logger.notice("Share read \(attempt) of \(attempts) after the sheet: \(invitees.count) people")
            if InviteParticipant.invitedPerson(among: invitees) != nil { return invitees }
        }
        return []
    }

    /// The zone's share: the one it has already, or a new private one. The zone is saved first,
    /// since a share can only be saved into a zone iCloud has (the engine saves it too; saving it
    /// twice does no harm).
    private func zoneShare(in zoneID: CKRecordZone.ID, container: CKContainer, isNewZone: Bool) async throws -> CKShare {
        let database = container.privateCloudDatabase
        let clock = ContinuousClock()
        let zoneTime = try await clock.measure {
            _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        }
        Self.logger.notice("Zone saved in \(zoneTime, privacy: .public)")
        // A zone made just now has no share to look for.
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        if !isNewZone, let existing = try? await database.record(for: shareID) as? CKShare { return existing }
        let share = CloudKitSync.share(for: zoneID)
        share[CKShare.SystemFieldKey.title] = String(localized: "Nudge-inator Reminders", comment: "Invite: the title of the share the invite carries, which the sharing sheet and the invitation show.")
        // The sheet and the invitation show this picture, which for a share made beforehand comes
        // from the share, not from the sheet's delegate.
        share[CKShare.SystemFieldKey.thumbnailImageData] = Self.appIconData()
        let shareStart = clock.now
        let saved = try await database.modifyRecords(saving: [share], deleting: [])
        Self.logger.notice("Share saved in \(shareStart.duration(to: .now), privacy: .public)")
        guard let result = saved.saveResults[share.recordID] else { throw NotAvailableYet() }
        guard let record = try result.get() as? CKShare else { throw NotAvailableYet() }
        return record
    }

    /// The app icon as PNG data, from the icon files the build puts in the bundle, or `nil` when
    /// there are none: the sheet then shows its generic picture.
    private static func appIconData() -> Data? {
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let names = primary?["CFBundleIconFiles"] as? [String] ?? []
        return names.reversed().lazy.compactMap { UIImage(named: $0)?.pngData() }.first
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
