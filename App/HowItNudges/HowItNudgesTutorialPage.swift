import Foundation
import NudgeEngine

/// A page of the How It Nudges sheet (#470, the mockup `2026-11-20-tutorial-sheets`): the welcome's
/// points, so they can be found again after onboarding, then each strength's ladder at the Default
/// Pace with Break Through Focus on, from the engine (enhancement-pace ticket 10). The strength pages
/// carry their schedules, so the sheet's pages are built when it opens, at the Default Pace of the
/// moment. It never opens by itself: only its Settings row opens it.
enum HowItNudgesTutorialPage: TutorialPage {
    case whatToExpect
    /// A strength as a new reminder at `pace`, with Break Through Focus on, would nudge.
    case strength(Strength, pace: Pace, HowItNudges)

    static let title = LocalizedStringResource("How It Nudges", comment: "How It Nudges: the sheet's title, and the Settings row under Tutorials that opens it, about how each strength nudges and what onboarding said.")

    /// The pages in order: What to Expect, then each strength in the form's order.
    static func pages(pace: Pace, engine: Engine) -> [Self] {
        [.whatToExpect] + Strength.formOrder.map {
            .strength($0, pace: pace, engine.howItNudges($0, pace: pace, breakThroughFocus: true))
        }
    }

    /// At the model's Default Pace, read now, so a change shows the next time the sheet opens.
    @MainActor static func pages(model: AppModel) -> [Self] {
        pages(pace: model.defaultPace.pace, engine: model.engine)
    }

    var heading: LocalizedStringResource {
        switch self {
        case .whatToExpect:
            LocalizedStringResource("What to Expect", comment: "How It Nudges: the first page's heading, over the points onboarding showed.")
        case .strength(let strength, _, _):
            strength.title
        }
    }

    var art: [TutorialArtPiece] {
        switch self {
        case .whatToExpect:
            [.pill(symbol: "bell", text: LocalizedStringResource("Nudge", comment: "How It Nudges, What to Expect: the picture's first pill, a nudge, before an arrow to Done.")),
             .arrow,
             .pill(symbol: "checkmark.circle.fill", text: LocalizedStringResource("Done", comment: "How It Nudges, What to Expect: the picture's last pill, after an arrow from Nudge: the reminder marked Done."))]
        case .strength(let strength, _, _):
            [.strength(strength)]
        }
    }

    var content: TutorialContent {
        switch self {
        case .whatToExpect:
            // The welcome's own points, with #459's line under the alarms point.
            .points(lead: nil, WelcomeFeature.allCases.map {
                TutorialPoint(symbol: $0.symbol, title: $0.title, text: $0.text, note: $0.note(on: .howItNudges))
            })
        case .strength(_, let pace, let howItNudges):
            .schedule(
                lead: StrengthBlurb(howItNudges).resource,
                note: LocalizedStringResource("At your Default Pace, \(pace.title), with Break Through Focus on.", comment: "How It Nudges: under a strength's line, before its schedule. The placeholder is the Default Pace, such as \"Consistent · 10 min\" or \"Escalating\"."),
                howItNudges
            )
        }
    }
}
