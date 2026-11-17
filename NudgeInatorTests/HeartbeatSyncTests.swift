import CloudKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The heartbeat in the CloudKit sync (#435, spec #127 seam 1, the sync layer): Alex's app lets
/// Sam's know it is still there, at most once a day by iCloud's stamp of the last one. Sam reads
/// iCloud's time, never Alex's phone's clock.
@MainActor
struct HeartbeatSyncTests {
    let icloud = FakeICloud()
    let connectionID = UUID()
    let alex: FakeSyncDevice
    let sam: FakeSyncDevice
    let start = Date(timeIntervalSinceReferenceDate: 815_000_000)
    let day: TimeInterval = 86_400

    init() {
        alex = FakeSyncDevice(icloud: icloud, userRecordName: "_alex")
        sam = FakeSyncDevice(icloud: icloud, userRecordName: "_sam")
        alex.sync.makeZone(for: connectionID)
        alex.send()
        icloud.share(connectionID, with: sam)
        sam.sync.joinZone(sam.zoneID(connectionID, owner: alex))
        icloud.now = start
    }

    /// Alex's app syncs at `now` on his phone's clock, and iCloud stamps what it saves at `iCloudNow`.
    func beat(at now: Date, iCloudNow: Date? = nil) {
        icloud.now = iCloudNow ?? now
        alex.heartbeat(for: [connectionID], at: now)
        alex.send()
        sam.fetch()
    }

    /// The Last synced of each settings change Sam received.
    var lastSyncedSeen: [Date?] {
        sam.received.compactMap { change in
            guard case .settings(let settings) = change.content else { return nil }
            return settings.lastSynced
        }
    }

    var heartbeatWaiting: Bool { !alex.privateQueue.pendingRecordZoneChanges.isEmpty }

    @Test func aHeartbeatReachesTheOtherPersonAsICloudsTimeOfIt() {
        beat(at: start)

        #expect(lastSyncedSeen == [start])
    }

    @Test func aHeartbeatIsNotAChangeInTheOutbox() {
        beat(at: start)

        #expect(alex.sentIDs.isEmpty)
    }

    @Test func aSecondHeartbeatWithinADayIsNotSent() {
        beat(at: start)

        alex.heartbeat(for: [connectionID], at: start.addingTimeInterval(day - 1))

        #expect(!heartbeatWaiting)
    }

    @Test func aHeartbeatAfterADayIsSent() {
        beat(at: start)

        beat(at: start.addingTimeInterval(day))

        #expect(lastSyncedSeen == [start, start.addingTimeInterval(day)])
    }

    @Test func theDayIsKeptAcrossARelaunch() {
        beat(at: start)
        alex.relaunch()

        alex.heartbeat(for: [connectionID], at: start.addingTimeInterval(60))

        #expect(!heartbeatWaiting)
    }

    @Test func aPhoneClockADayAheadOfICloudsStillSendsInsteadOfWaitingForTheClockToCatchUp() {
        // iCloud stamped the last one ten days after this phone's clock says it is.
        beat(at: start, iCloudNow: start.addingTimeInterval(10 * day))

        alex.heartbeat(for: [connectionID], at: start.addingTimeInterval(60))

        #expect(heartbeatWaiting)
    }

    @Test func aHeartbeatKeepsTheSettingsTheRecordAlreadyHolds() throws {
        alex.submit(.settings(.init(ConnectionChoices(deliveryMode: .askMeFirst)), for: connectionID))
        alex.send()

        beat(at: start.addingTimeInterval(day))

        let change = try #require(sam.received.last)
        guard case .settings(let settings) = change.content else { Issue.record("Not settings"); return }
        #expect(settings.choices == ConnectionChoices(deliveryMode: .askMeFirst))
        #expect(settings.lastSynced == start.addingTimeInterval(day))
    }

    @Test func aSettingsChangeWithStatusSharingOnIsAHeartbeatToo() {
        alex.submit(.settings(.init(ConnectionChoices(deliveryMode: .askMeFirst)), for: connectionID))
        alex.send()
        sam.fetch()

        alex.heartbeat(for: [connectionID], at: start.addingTimeInterval(3_600))

        #expect(lastSyncedSeen == [start])
        #expect(!heartbeatWaiting)
    }

    @Test func turningStatusSharingOffRemovesTheHeartbeatSoTheOtherPersonHasNoLastSynced() {
        beat(at: start)

        alex.submit(.settings(.init(ConnectionChoices(sharesStatus: false)), for: connectionID))
        alex.send()
        sam.fetch()

        #expect(lastSyncedSeen == [start, nil])
        #expect(icloud.stored(connectionID, "ConnectionSettings.owner")?.fields["heartbeat"] == nil)
    }

    @Test func noHeartbeatIsSentWhileStatusSharingIsOff() {
        alex.submit(.settings(.init(ConnectionChoices(sharesStatus: false)), for: connectionID))
        alex.send()

        alex.heartbeat(for: [connectionID], at: start.addingTimeInterval(30 * day))

        #expect(!heartbeatWaiting)
    }

    @Test func turningStatusSharingBackOnHeartbeatsAgain() {
        alex.submit(.settings(.init(ConnectionChoices(sharesStatus: false)), for: connectionID))
        alex.send()
        sam.fetch()
        icloud.now = start.addingTimeInterval(60)

        alex.submit(.settings(.init(ConnectionChoices(sharesStatus: true)), for: connectionID))
        alex.send()
        sam.fetch()

        #expect(lastSyncedSeen == [nil, start.addingTimeInterval(60)])
    }

    @Test func noHeartbeatForAConnectionWithNoZone() {
        alex.heartbeat(for: [UUID()], at: start)

        #expect(!heartbeatWaiting)
    }

    @Test func noHeartbeatForAConnectionBeingDeleted() {
        alex.submit(.disconnect(connectionID))

        alex.heartbeat(for: [connectionID], at: start)

        #expect(!heartbeatWaiting)
    }
}
