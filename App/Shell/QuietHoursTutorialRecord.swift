import Foundation

/// Whether How Quiet Hours Work (#468) has been seen, so it opens by itself only the first time the
/// Quiet Hours page opens. In this app's own `UserDefaults`, on this iPhone only, as How Sharing
/// Works' flag is: an update keeps it, a reinstall, which empties it, shows the tutorial again, and
/// Delete All Data leaves it as it was. Unset reads unseen.
struct QuietHoursTutorialRecord {
    let defaults: UserDefaults

    static var standard: QuietHoursTutorialRecord { QuietHoursTutorialRecord(defaults: .standard) }

    private static let key = "quietHoursTutorialSeen"

    var isSeen: Bool {
        get { defaults.bool(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
