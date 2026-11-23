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

    /// How many Apply would show on the day My Day shows.
    let dueCount: Int

    /// `day` is the day My Day shows, today if none (#374); the count and its words are that day's (#375).
    init(engine: Engine, draft: MyDayFilterChoices, applied: MyDayFilterChoices, day: CalendarDay? = nil) {
        let existing = Set(engine.tags.map(\.id))
        let draft = draft.keeping(tagsIn: existing)
        choice = TagChoiceRows(engine: engine, choice: draft.tags)
        hasChanges = draft != applied.keeping(tagsIn: existing)
        canReset = draft != MyDayFilterChoices()
        offersFromOthers = draft.fromOthers || engine.hasReceivedReminders
        let shown = MyDayShownDay(engine: engine, asked: day)
        let due = engine.myDay(on: shown.day, tagFilter: draft.tagFilter, fromOthers: draft.fromOthers).items.count
        dueCount = due
        result = shown.sheetResult(due: due)
    }
}
