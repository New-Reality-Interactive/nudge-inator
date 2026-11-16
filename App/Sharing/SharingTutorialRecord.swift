import Foundation

/// Whether How Sharing Works (#423) has been seen, so it opens by itself only the first time
/// Sharing is turned on (#424). In this app's own `UserDefaults`, on this iPhone only: never the
/// sharing store or iCloud, so a reinstall, which empties it, shows the tutorial again, and Delete
/// All Data leaves it as it was. Unset reads unseen.
struct SharingTutorialRecord {
    let defaults: UserDefaults

    static var standard: SharingTutorialRecord { SharingTutorialRecord(defaults: .standard) }

    private static let key = "sharingTutorialSeen"

    var isSeen: Bool {
        get { defaults.bool(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }

    /// Unseen: the starting state.
    func reset() {
        defaults.removeObject(forKey: Self.key)
    }
}
