import Foundation
import NudgeEngine

/// What Settings' How It Nudges page says at the Default Pace (enhancement-pace ticket 10), so it
/// matches what a new reminder will do.
struct HowItNudgesPageContent {
    let pace: Pace
    let engine: Engine

    /// Under the welcome's points, before the strengths' sections.
    var intro: LocalizedStringResource {
        LocalizedStringResource("Below is how each strength nudges a new reminder at your Default Pace, \(pace.title), with Break Through Focus on.", comment: "How It Nudges page: under the points at the top, before the three strengths' schedules. The placeholder is the Default Pace, such as \"Consistent · 10 min\" or \"Escalating\".")
    }

    /// Each strength in the form's order, as a new reminder at this pace with Break Through Focus
    /// on would nudge, from the engine.
    var sections: [(strength: Strength, howItNudges: HowItNudges)] {
        Strength.formOrder.map { ($0, engine.howItNudges($0, pace: pace, breakThroughFocus: true)) }
    }
}

extension HowItNudgesPageContent {
    /// At the model's Default Pace, read now, so the page follows a change the next time it's drawn.
    @MainActor init(model: AppModel) {
        self.init(pace: model.defaultPace.pace, engine: model.engine)
    }
}
