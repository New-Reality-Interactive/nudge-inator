import Foundation
import NudgeEngine

/// The Repeat page's first section: Never and the six presets (GLOSSARY.md › Repeat), in the
/// mockup's order. Each is one of the engine's rules (ticket 08); any other rule is Custom
/// (ticket 25).
enum RepeatPreset: CaseIterable, Hashable {
    case never
    case everyDay
    case everyWeekday
    case everyWeek
    case everyTwoWeeks
    case everyMonth
    case everyYear

    /// The preset this rule is, or `nil` if it's a custom rule.
    init?(_ rule: RepeatRule?) {
        guard let preset = Self.allCases.first(where: { $0.rule == rule }) else { return nil }
        self = preset
    }

    /// `nil` repeats Never.
    var rule: RepeatRule? {
        switch self {
        case .never: nil
        case .everyDay: .everyDay
        case .everyWeekday: .everyWeekday
        case .everyWeek: .everyWeek
        case .everyTwoWeeks: .everyTwoWeeks
        case .everyMonth: .everyMonth
        case .everyYear: .everyYear
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .never: LocalizedStringResource("Never", comment: "Repeat preset, on the Repeat page and the form's Repeat row: the reminder doesn't repeat.")
        case .everyDay: LocalizedStringResource("Every Day", comment: "Repeat preset, on the Repeat page and the form's Repeat row.")
        case .everyWeekday: LocalizedStringResource("Every Weekday", comment: "Repeat preset, on the Repeat page and the form's Repeat row: Monday to Friday.")
        case .everyWeek: LocalizedStringResource("Every Week", comment: "Repeat preset, on the Repeat page and the form's Repeat row.")
        case .everyTwoWeeks: LocalizedStringResource("Every 2 Weeks", comment: "Repeat preset, on the Repeat page and the form's Repeat row.")
        case .everyMonth: LocalizedStringResource("Every Month", comment: "Repeat preset, on the Repeat page and the form's Repeat row.")
        case .everyYear: LocalizedStringResource("Every Year", comment: "Repeat preset, on the Repeat page and the form's Repeat row.")
        }
    }
}
