import Foundation
import NudgeEngine

/// A received reminder's strength in words (ticket 200, DESIGN.md's Shared reminders), on its
/// arrival notification and its details: "Relentless: rings an alarm until you mark it done", or the
/// strength's name before the line the form shows under it (`StrengthBlurb`), as the mockup's
/// `strengthLine` words it. The ladder is the reminder's own, with its pace, switch and the alarm
/// permission, so a Firm one that never reaches an alarm doesn't say it rings.
struct StrengthLine: Equatable {
    var strength: Strength
    /// The first nudge that rings, or `nil` if none does.
    var firstAlarm: Int?

    init(_ strength: Strength, _ howItNudges: HowItNudges) {
        self.strength = strength
        firstAlarm = howItNudges.firstAlarm
    }

    /// The reminder's own line, from its ladder as `engine` plans it.
    init(of reminder: Reminder, in engine: Engine) {
        self.init(reminder.strength, engine.howItNudges(reminder.strength, pace: reminder.pace, breakThroughFocus: reminder.breakThroughFocus))
    }

    var text: LocalizedStringResource {
        // The fixed sentence for Relentless, as the spec and the mockup word it.
        if strength == .relentless {
            return LocalizedStringResource("Relentless: rings an alarm until you mark it done", comment: "A received Relentless reminder's strength in words, on its arrival notification and its details.")
        }
        let name = String(localized: strength.title)
        switch firstAlarm {
        case 1?:
            return LocalizedStringResource("\(name): every nudge rings as an alarm", comment: "A received reminder's strength in words, on its arrival notification and its details, when every nudge rings. The placeholder is the strength, such as \"Firm\".")
        case let firstAlarm?:
            return LocalizedStringResource("\(name): rings as an alarm from nudge \(firstAlarm)", comment: "A received reminder's strength in words, on its arrival notification and its details. 1: the strength, such as \"Firm\". 2: the first nudge that rings as an alarm.")
        case nil:
            return LocalizedStringResource("\(name): never rings as an alarm", comment: "A received reminder's strength in words, on its arrival notification and its details, when none of its nudges rings. The placeholder is the strength, such as \"Gentle\".")
        }
    }
}
