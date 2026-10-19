import Foundation

/// Whether the person has finished onboarding (ticket 31), kept in `UserDefaults` so it outlives a
/// relaunch. Delete All Data leaves it, since the permissions it asked for stay too; uninstalling
/// clears both.
struct OnboardingRecord {
    let defaults: UserDefaults

    static var standard: OnboardingRecord { OnboardingRecord(defaults: .standard) }

    private static let key = "onboardingFinished"

    var isFinished: Bool {
        get { defaults.bool(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
