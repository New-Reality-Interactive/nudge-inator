import Foundation

/// Whether Settings' Sharing switch is on (#387). Unset, as on a new install and an install updated
/// from 1.3.0, reads off. `UserDefaults` is shut before the first unlock after a restart and reads
/// off then too, so the app model reads it again once its store opens, and writes it only when the
/// person flips the switch.
struct SharingSwitchRecord {
    let defaults: UserDefaults

    static var standard: SharingSwitchRecord { SharingSwitchRecord(defaults: .standard) }

    private static let key = "sharingOn"
    private static let windingDownKey = "sharingWindingDown"

    var isOn: Bool {
        get { defaults.bool(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }

    /// Whether the switch turned off with disconnects or revoked invites still to reach iCloud
    /// (#388), so a launch with it off still makes the sharing model to send them. Cleared once they
    /// have gone, or the switch turns on again.
    var isWindingDown: Bool {
        get { defaults.bool(forKey: Self.windingDownKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.windingDownKey) }
    }
}
