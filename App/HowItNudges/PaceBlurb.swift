import NudgeEngine
import SwiftUI

/// The line under the reminder form's pace (the mockup's `paceBlurb`): the strength's waits from
/// the first to the shortest, "Every 30 min at first, down to every 5 min.", or the one wait,
/// "Every 10 min, from when it's due."
enum PaceBlurb: Equatable {
    /// `floor` is the shortest wait, which the last nudges keep to.
    case escalating(firstWait: TimeInterval, floor: TimeInterval)
    case consistent(wait: TimeInterval)

    /// From the draft's pace and its ladder at that pace.
    init(_ pace: Pace, _ howItNudges: HowItNudges) {
        switch pace {
        case .escalating:
            self = .escalating(firstWait: howItNudges.rows.first?.wait ?? 0, floor: howItNudges.rows.last?.wait ?? 0)
        case .consistent(let wait):
            self = .consistent(wait: wait)
        }
    }

    var text: Text {
        switch self {
        case .escalating(let firstWait, let floor):
            return Text("Every \(HowItNudgesDuration.text(firstWait)) at first, down to every \(HowItNudgesDuration.text(floor)).",
                        comment: "Under the reminder form's pace when it is Escalating. 1: the wait after the first nudge, such as \"30 min\". 2: the shortest wait.")
        case .consistent(let wait):
            return Text("Every \(HowItNudgesDuration.text(wait)), from when it's due.",
                        comment: "Under the reminder form's pace when it is Consistent. The placeholder is the wait between nudges, such as \"10 min\".")
        }
    }
}
