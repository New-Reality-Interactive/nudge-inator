import Foundation

/// Last synced and Quiet (GLOSSARY.md, #435): what a connection's heartbeat tells this person.
extension SharingConnection {
    /// How long the other person's app may go without syncing before the connection is Quiet: 14
    /// days, or 2 minutes in a Debug build, so a device check runs in minutes.
    static let quietAfter: TimeInterval = {
        #if DEBUG
        quietInterval(isDebug: true)
        #else
        quietInterval(isDebug: false)
        #endif
    }()

    static func quietInterval(isDebug: Bool) -> TimeInterval {
        isDebug ? 2 * 60 : 14 * 24 * 60 * 60
    }

    /// The Last synced time of a Quiet connection, which its page shows; `nil` for one that isn't.
    /// Quiet at `now` is: connected, the other person's Status sharing on, and their app last synced
    /// `interval` or more ago by iCloud's time. A connection with no Last synced isn't Quiet: their
    /// Status sharing is off, or no heartbeat has come yet, and silence then says nothing.
    func lastSyncedIfQuiet(at now: Date, after interval: TimeInterval = SharingConnection.quietAfter) -> Date? {
        guard state == .connected, theirs.sharesStatus, let theirLastSynced, now.timeIntervalSince(theirLastSynced) >= interval else { return nil }
        return theirLastSynced
    }
}
