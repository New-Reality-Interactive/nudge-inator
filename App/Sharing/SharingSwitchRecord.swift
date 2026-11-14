import Foundation

/// Whether Settings' Sharing switch is on (#387). Unset, as on a new install and an install updated
/// from 1.3.0, reads off. `UserDefaults` is shut before the first unlock after a restart and reads
/// off then too, so the app model reads it again once its store opens, and writes it only when the
/// person flips the switch.
struct SharingSwitchRecord {
    let defaults: UserDefaults

    static var standard: SharingSwitchRecord { SharingSwitchRecord(defaults: .standard) }

    private static let key = "sharingOn"

    var isOn: Bool {
        get { defaults.bool(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
