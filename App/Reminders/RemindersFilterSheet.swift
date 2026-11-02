import Foundation
import NudgeEngine

/// What the Reminders filter sheet shows, read from the engine at one moment: the draft's tags, how
/// many reminders Apply would show, and whether the draft differs from what's applied. A value, so
/// the tests read it with no view.
struct RemindersFilterSheet {
    let tags: TagChoiceRows
    /// How many reminders Apply would show, with the search as it is.
    let result: LocalizedStringResource
    /// Whether Cancel, tapping above or swiping down asks before discarding the draft. By what each
    /// narrows the list by, so tags checked in another order aren't a change.
    let hasChanges: Bool
    /// Whether Reset has anything to clear.
    let canReset: Bool

    init(engine: Engine, draft: RemindersSheetFilter, applied: RemindersSheetFilter, search: String) {
        let existing = Set(engine.tags.map(\.id))
        let draft = draft.keeping(tagsIn: existing)
        let narrowing = draft.narrowing(search: "")
        tags = TagChoiceRows(engine: engine, choice: draft.tags)
        hasChanges = narrowing != applied.keeping(tagsIn: existing).narrowing(search: "")
        canReset = narrowing.hasSheetFilters
        let shown = engine.remindersList(filteredBy: draft.narrowing(search: search)).items.count
        result = LocalizedStringResource("Apply shows \(shown) reminders.", comment: "Reminders' filter sheet: above Reset. The placeholder is how many reminders the list would show with these filters and the search as it is.")
    }
}
