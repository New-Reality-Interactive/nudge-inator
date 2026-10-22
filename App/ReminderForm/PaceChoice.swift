import Foundation
import NudgeEngine

/// The form's Pace control. A Consistent pace's wait is the Every row's, so it is kept apart and
/// survives a switch to Escalating and back.
enum PaceChoice: Hashable, CaseIterable {
    case escalating
    case consistent

    /// The Every row's wait until the Default Pace sets it (ticket 09): the mockup's 10 min.
    static let startingWait: TimeInterval = 10 * 60

    /// The choice that shows `pace`.
    init(_ pace: Pace) {
        switch pace {
        case .escalating: self = .escalating
        case .consistent: self = .consistent
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .escalating: LocalizedStringResource("Escalating", comment: "Pace name: the waits between nudges come from the strength and shrink as the nudging goes on.")
        case .consistent: LocalizedStringResource("Consistent", comment: "Pace name: one wait, chosen by the person, between every nudge.")
        }
    }
}

extension Pace {
    /// "Escalating", or "Consistent · 30 min", as reminder details show a pace.
    var title: LocalizedStringResource {
        switch self {
        case .escalating:
            PaceChoice.escalating.title
        case .consistent(let wait):
            LocalizedStringResource("Consistent · \(HowItNudgesDuration.text(wait))", comment: "A Consistent pace with its wait, as reminder details show it. The placeholder is the wait between nudges, such as \"30 min\".")
        }
    }
}
