import NudgeEngine
import SwiftUI

/// The line under the reminder form's strength choice (the mockup's `strengthBlurb`), from the
/// engine's ladder rather than typed copy: how the strength arrives, "Rings as an alarm from nudge
/// 4." It follows the draft's pace, switch and the alarm permission, so a long wait that gives up
/// before nudge 4 never rings. The waits are under Pace (`PaceBlurb`).
struct StrengthBlurb: Equatable {
    /// The first nudge that rings, or `nil` if none does.
    var firstAlarm: Int?

    init(firstAlarm: Int?) {
        self.firstAlarm = firstAlarm
    }

    init(_ howItNudges: HowItNudges) {
        firstAlarm = howItNudges.firstAlarm
    }

    var text: Text {
        switch firstAlarm {
        case 1?:
            return Text("Every nudge rings as an alarm.",
                        comment: "Under the reminder form's strength, when every nudge rings, as Relentless's do.")
        case let firstAlarm?:
            return Text("Rings as an alarm from nudge \(firstAlarm).",
                        comment: "Under the reminder form's strength. The placeholder is the first nudge that rings as an alarm.")
        case nil:
            return Text("Never rings as an alarm.",
                        comment: "Under the reminder form's strength, when none of its nudges rings.")
        }
    }
}
