import CloudKit
import Foundation
import Testing
@testable import NudgeInator

/// An invite left in iCloud when the app was closed while its compose screen was up (#400): its
/// share has the person on it, but Connections doesn't list them. Seam 1: which of the kept
/// zones are leftovers, with plain values.
@MainActor
struct LeftoverInviteRuleTests {
    let invite = UUID()

    func cache(own: [UUID] = [], joined: [UUID] = [], deleting: [UUID] = []) -> CloudKitSyncCache {
        var cache = CloudKitSyncCache()
        for id in own { cache.zones[id] = CloudKitSyncCache.Zone(ownerName: CKCurrentUserDefaultName) }
        for id in joined { cache.zones[id] = CloudKitSyncCache.Zone(ownerName: "_alex") }
        for id in deleting { cache.zoneDeletes[id] = [UUID()] }
        return cache
    }

    @Test func anInviteConnectionsDoesntListIsALeftover() {
        #expect(cache(own: [invite]).leftoverInvites(listed: []) == [invite])
    }

    @Test func anInviteConnectionsListsIsNot() {
        #expect(cache(own: [invite]).leftoverInvites(listed: [invite]).isEmpty)
    }

    /// The other person's zone: this person accepted an invite, so it was never theirs to revoke.
    @Test func aZoneJoinedThroughSomeoneElsesInviteIsNot() {
        #expect(cache(joined: [invite]).leftoverInvites(listed: []).isEmpty)
    }

    /// Revoked already, and the delete waits for iCloud.
    @Test func anInviteAlreadyBeingDeletedIsNot() {
        #expect(cache(own: [invite], deleting: [invite]).leftoverInvites(listed: []).isEmpty)
    }

    /// The app was closed before iCloud had even made the invite's zone: iCloud finds no zone to
    /// delete, and the revoke counts as done.
    @Test func aLeftoverICloudNeverMadeIsDoneWhenItsDeleteFindsNoZone() {
        let sync = CloudKitSync()
        let zoneID = sync.makeZone(for: invite)
        let revoke = SharingChange.disconnect(invite)
        _ = sync.submit(revoke)

        let outcome = sync.sentZones(saved: [], deleted: [], failedSaves: [:], failedDeletes: [zoneID: CKError(.zoneNotFound)])

        #expect(outcome.gone == [revoke.entry.id])
        #expect(!sync.ownsZone(of: invite))
        #expect(!sync.hasUnsentDisconnects)
    }

    @Test func onlyTheUnlistedOnesOfSeveralAreLeftovers() {
        let sent = UUID()
        let other = UUID()

        let leftovers = cache(own: [invite, sent, other]).leftoverInvites(listed: [sent])

        #expect(Set(leftovers) == [invite, other])
    }
}

/// Seam 2: the real adapter over two real `CKSyncEngine`s, with `automaticallySync` off so nothing
/// reaches the network (as #216): a relaunch hands the private engine the leftover's zone delete,
/// which ends its share for everyone. What iCloud does with it is the device check.
@MainActor
struct LeftoverInviteAdapterTests {
    let invite = UUID()
    let events = RecordingSharingEvents()

    func adapter() -> CloudKitSharingAdapter {
        let container = CKContainer(identifier: CloudKitSharingAdapter.containerIdentifier)
        let adapter = CloudKitSharingAdapter(reader: CloudKitAccountReader(source: container), container: container, automaticallySync: false)
        adapter.events = events
        return adapter
    }

    func startedAdapter() -> CloudKitSharingAdapter {
        let adapter = adapter()
        adapter.start()
        return adapter
    }

    /// The app made the invite's zone and share, then was closed with its compose screen up.
    func closedWithTheComposeScreenUp() throws {
        let adapter = startedAdapter()
        try #require(adapter.sync).makeZone(for: invite)
        adapter.keep()
    }

    func zoneDeletes(_ adapter: CloudKitSharingAdapter) throws -> [CKRecordZone.ID] {
        try #require(adapter.engines[.private]).state.pendingDatabaseChanges.compactMap {
            if case .deleteZone(let zoneID) = $0 { zoneID } else { nil }
        }
    }

    @Test func aLeftoverInviteIsDeletedWhenTheAdapterStartsAfterARelaunch() throws {
        try closedWithTheComposeScreenUp()
        events.listedConnections = []

        let relaunched = startedAdapter()

        #expect(try zoneDeletes(relaunched) == [CloudKitSync.ownZoneID(of: invite)])
        #expect(relaunched.sync?.ownsZone(of: invite) == true)
        #expect(relaunched.hasUnsentDisconnects)
    }

    @Test func aSentInviteWithItsInvitedRowIsLeftAlone() throws {
        try closedWithTheComposeScreenUp()
        events.listedConnections = [invite]

        let relaunched = startedAdapter()

        #expect(try zoneDeletes(relaunched).isEmpty)
        #expect(!relaunched.hasUnsentDisconnects)
    }

    /// Its compose screen is up now: the start was before its zone, so it's no leftover.
    @Test func anInviteMadeAfterTheStartIsLeftAlone() throws {
        events.listedConnections = []
        let adapter = startedAdapter()
        try #require(adapter.sync).makeZone(for: invite)

        adapter.start()
        adapter.submit(.disconnect(UUID()))

        #expect(try zoneDeletes(adapter).isEmpty)
        #expect(!adapter.holdsLeftoverInvite)
    }

    /// Read before the start, from what the store kept, so the app model can start the adapter
    /// at launch for it. The adapter asks iCloud nothing for it: it has no engines yet.
    @Test func theAdapterSaysItHoldsALeftoverBeforeItStarts() throws {
        try closedWithTheComposeScreenUp()
        events.listedConnections = []

        let relaunched = adapter()

        #expect(relaunched.holdsLeftoverInvite)
        #expect(relaunched.engines.isEmpty)
    }

    @Test func aSentInviteIsNoLeftoverBeforeTheStartEither() throws {
        try closedWithTheComposeScreenUp()
        events.listedConnections = [invite]

        #expect(!adapter().holdsLeftoverInvite)
    }

    /// The app model's launch check and the start read the leftovers once, and the start revokes
    /// what the check found.
    @Test func theLeftoverTheLaunchCheckFindsIsTheOneTheStartRevokes() throws {
        try closedWithTheComposeScreenUp()
        events.listedConnections = []
        let relaunched = adapter()
        #expect(relaunched.holdsLeftoverInvite)

        relaunched.start()

        #expect(try zoneDeletes(relaunched) == [CloudKitSync.ownZoneID(of: invite)])
        #expect(!relaunched.holdsLeftoverInvite)
    }

    @Test func onceStartedTheAdapterHoldsNoLeftover() throws {
        try closedWithTheComposeScreenUp()
        events.listedConnections = []

        #expect(!startedAdapter().holdsLeftoverInvite)
    }
}
