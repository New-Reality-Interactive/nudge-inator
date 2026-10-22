import NudgeEngine
import SwiftUI

/// The line under the reminder form's strength choice (the mockup's `blurb`), from the engine's
/// ladder rather than typed copy: "Every 30 min at first, down to every 5 min. Rings as an alarm
/// from nudge 4." Whether it rings follows the draft's switch and the alarm permission.
struct StrengthBlurb: Equatable {
    var firstWait: TimeInterval
    /// The shortest wait, which the last nudges keep to.
    var floor: TimeInterval
    /// The first nudge that rings, or `nil` if none does.
    var firstAlarm: Int?

    init(firstWait: TimeInterval, floor: TimeInterval, firstAlarm: Int?) {
        self.firstWait = firstWait
        self.floor = floor
        self.firstAlarm = firstAlarm
    }

    init(_ howItNudges: HowItNudges) {
        firstWait = howItNudges.rows.first?.wait ?? 0
        floor = howItNudges.rows.last?.wait ?? 0
        firstAlarm = howItNudges.firstAlarm
    }

    var text: Text {
        let first = HowItNudgesDuration.text(firstWait)
        let shortest = HowItNudgesDuration.text(floor)
        switch firstAlarm {
        case 1?:
            return Text("Every \(first) at first, down to every \(shortest). Every nudge rings as an alarm.",
                        comment: "Under the reminder form's strength, when every nudge rings, as Relentless's do. 1: the wait after the first nudge, such as \"10 min\". 2: the shortest wait.")
        case let firstAlarm?:
            return Text("Every \(first) at first, down to every \(shortest). Rings as an alarm from nudge \(firstAlarm).",
                        comment: "Under the reminder form's strength. 1: the wait after the first nudge, such as \"30 min\". 2: the shortest wait. 3: the first nudge that rings as an alarm.")
        case nil:
            return Text("Every \(first) at first, down to every \(shortest). Never rings as an alarm.",
                        comment: "Under the reminder form's strength, when none of its nudges rings. 1: the wait after the first nudge, such as \"1 hr\". 2: the shortest wait.")
        }
    }
}
