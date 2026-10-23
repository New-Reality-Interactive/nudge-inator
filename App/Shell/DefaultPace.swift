import Foundation
import NudgeEngine

/// Settings' Default Pace: the pace every new reminder starts with (spec stories 36–42). Its wait
/// is kept apart, as the form's is, so Escalating keeps the Every row's wait for Consistent.
struct DefaultPace: Equatable {
    var choice: PaceChoice
    /// One of `Pace.consistentWaits`.
    var consistentWait: TimeInterval

    /// Out of the box, and after Delete All Data: Consistent · 10 min.
    static let shipped = DefaultPace(choice: .consistent, consistentWait: 10 * 60)

    var pace: Pace {
        choice.pace(wait: consistentWait)
    }
}

/// The Default Pace, kept in `UserDefaults` so it outlives a relaunch. Delete All Data clears it,
/// unlike the onboarding record.
struct DefaultPaceRecord {
    let defaults: UserDefaults

    static var standard: DefaultPaceRecord { DefaultPaceRecord(defaults: .standard) }

    private static let choiceKey = "defaultPace"
    private static let waitKey = "defaultPaceWait"

    var defaultPace: DefaultPace {
        get {
            let choice = defaults.string(forKey: Self.choiceKey).flatMap(PaceChoice.init(rawValue:))
            // The store refuses a reminder whose wait isn't in the list (ticket 07).
            let wait = (defaults.object(forKey: Self.waitKey) as? TimeInterval).flatMap { Pace.consistentWaits.contains($0) ? $0 : nil }
            return DefaultPace(choice: choice ?? DefaultPace.shipped.choice, consistentWait: wait ?? DefaultPace.shipped.consistentWait)
        }
        nonmutating set {
            defaults.set(newValue.choice.rawValue, forKey: Self.choiceKey)
            defaults.set(newValue.consistentWait, forKey: Self.waitKey)
        }
    }

    /// Back to Consistent · 10 min.
    func clear() {
        defaults.removeObject(forKey: Self.choiceKey)
        defaults.removeObject(forKey: Self.waitKey)
    }
}
