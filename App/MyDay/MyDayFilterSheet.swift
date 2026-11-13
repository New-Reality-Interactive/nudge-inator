import Foundation
import NudgeEngine

/// What the filter sheet shows for a draft, read from the engine at one moment: every tag with a
/// check, No Tags, From others once someone has sent a reminder, and above Reset how many due
/// today Apply would show. A value, so the tests read it with no view.
struct MyDayFilterSheet: FilterSheetSummary {
    let choice: TagChoiceRows
    let result: LocalizedStringResource
    /// Whether the X asks, and a swipe down springs back, before discarding the draft.
    let hasChanges: Bool
    /// Whether Reset has anything to clear.
    let canReset: Bool
    /// Whether the From section shows: someone has sent this person a reminder, or From others is
    /// on, so it can be turned off where it was turned on (ticket 209).
    let offersFromOthers: Bool

    var tags: [TagChoiceRows.Row] { choice.tags }
    var isNoTagsChecked: Bool { choice.isNoTagsChecked }
    var canChooseMatch: Bool { choice.canChooseMatch }
    var tagsFooter: LocalizedStringResource { choice.footer }

    init(engine: Engine, draft: MyDayFilterChoices, applied: MyDayFilterChoices) {
        let existing = Set(engine.tags.map(\.id))
        let draft = draft.keeping(tagsIn: existing)
        choice = TagChoiceRows(engine: engine, choice: draft.tags)
        hasChanges = draft != applied.keeping(tagsIn: existing)
        canReset = draft != MyDayFilterChoices()
        offersFromOthers = draft.fromOthers || engine.hasReceivedReminders
        let due = engine.myDay(tagFilter: draft.tagFilter, fromOthers: draft.fromOthers).items.count
        result = LocalizedStringResource("Apply shows \(due) reminders due today.", comment: "My Day's filter sheet: above Reset. The placeholder is how many reminders due today My Day would show with these filters.")
    }
}
