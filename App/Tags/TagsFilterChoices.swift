import Foundation
import NudgeEngine

/// What the Tags filter sheet has chosen, applied or as a draft: its one condition, about the tag
/// itself (spec #104, Decision 53). Search isn't part of it, so Apply, Reset and Clear All Filters
/// leave the search as it is.
struct TagsFilterChoices: FilterSheetChoices {
    /// Only tags no reminder uses.
    var hasNoReminders = false

    /// The Filter button's badge: 1 while the sheet's one section is in use.
    var sectionsInUse: Int { hasNoReminders ? 1 : 0 }

    /// What the list is narrowed by with this applied and `search` in the field.
    func narrowing(search: String) -> TagListFilter {
        TagListFilter(search: search, hasNoReminders: hasNoReminders)
    }
}

/// What the Tags filter sheet shows, read from the engine at one moment: how many tags Apply would
/// show, and whether the draft differs from what's applied. A value, so the tests read it with no
/// view.
struct TagsFilterSheet: FilterSheetSummary {
    /// How many tags Apply would show, with the search as it is.
    let result: LocalizedStringResource
    /// Whether Cancel, tapping above or swiping down asks before discarding the draft.
    let hasChanges: Bool
    /// Whether Reset has anything to clear.
    let canReset: Bool

    init(engine: Engine, draft: TagsFilterChoices, applied: TagsFilterChoices, search: String) {
        hasChanges = draft != applied
        canReset = draft != TagsFilterChoices()
        let shown = engine.tagList(filteredBy: draft.narrowing(search: search)).visibleCount
        result = LocalizedStringResource("Apply shows \(shown) tags.", comment: "Tags' filter sheet: above Reset. The placeholder is how many tags the list would show with this filter and the search as it is.")
    }
}
