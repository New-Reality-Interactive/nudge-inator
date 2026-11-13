import Foundation

/// The person's iCloud account as the sharing adapter reports it, never read from the system by
/// anything else (as `PermissionStates` comes from the scheduler adapters). Sharing syncs through
/// iCloud, so only an available account lets it work.
public enum SharingAccountState: Equatable, Sendable {
    case available
    /// No iCloud account is signed in on the iPhone.
    case noAccount
    /// The account is restricted, for example by Screen Time or a device management profile.
    case restricted
    /// iCloud can't be reached for now.
    case temporarilyUnavailable

    /// What sharing can do with this account, as the messages on Connections, Send To and Sent say it
    /// (as `Engine.reach` is for the permission banners).
    public var reach: SharingReach {
        switch self {
        case .available: .working
        case .noAccount: .paused(.noAccount)
        case .restricted: .paused(.restricted)
        case .temporarilyUnavailable: .paused(.temporarilyUnavailable)
        }
    }
}

/// Whether sharing works, and if not, why it is paused. Nothing else in the app changes while it
/// is: received reminders keep nudging and personal reminders are untouched.
public enum SharingReach: Equatable, Sendable {
    case working
    case paused(Pause)

    /// Why sharing is paused, or `nil` while it works (ticket 210).
    public var pause: Pause? {
        if case .paused(let pause) = self { pause } else { nil }
    }

    /// Why sharing is paused, which decides what the person is told to do.
    public enum Pause: Equatable, Sendable {
        case noAccount
        case restricted
        case temporarilyUnavailable
    }
}
