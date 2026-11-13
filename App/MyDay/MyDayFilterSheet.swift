import Foundation
import NudgeEngine

/// What the filter sheet shows, read from the engine at one moment: every tag with a check, No
/// Tags, From others once someone has sent a reminder, and how many are due today with the filter
/// on. A value, so the tests read it with no view.
struct MyDayFilterSheet {
    let choice: TagChoiceRows
    var result: LocalizedStringResource
    /// Whether the From section shows: someone has sent this person a reminder, or From others is
    /// on, so it can be turned off where it was turned on (ticket 209).
    let offersFromOthers: Bool

    var tags: [TagChoiceRows.Row] { choice.tags }
    var isNoTagsChecked: Bool { choice.isNoTagsChecked }
    var canChooseMatch: Bool { choice.canChooseMatch }
    var tagsFooter: LocalizedStringResource { choice.footer }

    init(engine: Engine, filter: MyDayFilter) {
        let filter = filter.keeping(tagsIn: Set(engine.tags.map(\.id)))
        choice = TagChoiceRows(engine: engine, choice: filter.tags)
        offersFromOthers = filter.fromOthers || engine.hasReceivedReminders
        let due = engine.myDay(tagFilter: filter.tagFilter, fromOthers: filter.fromOthers).items.count
        result = Self.result(due: due, filter: filter, engine: engine)
    }

    private static func result(due: Int, filter: MyDayFilter, engine: Engine) -> LocalizedStringResource {
        let list = filter.match.list(of: engine.tagLabels(for: filter.tagIDs))
        switch (filter.noTags, filter.tagIDs.isEmpty, filter.fromOthers) {
        case (true, _, false):
            return LocalizedStringResource("\(due) due today without tags.", comment: "My Day's filter sheet: under the lists when No Tags is checked. The placeholder is how many are due today.")
        case (true, _, true):
            return LocalizedStringResource("\(due) due today without tags from others.", comment: "My Day's filter sheet: under the lists when No Tags and From others are checked. The placeholder is how many are due today.")
        case (false, true, false):
            return LocalizedStringResource("Showing everything due today (\(due)).", comment: "My Day's filter sheet: under the lists when nothing is checked. The placeholder is how many are due today.")
        case (false, true, true):
            return LocalizedStringResource("\(due) due today from others.", comment: "My Day's filter sheet: under the lists when only From others is checked. The placeholder is how many are due today.")
        case (false, false, false):
            return LocalizedStringResource("\(due) due today with \(list).", comment: "My Day's filter sheet: under the lists when tags are checked. 1: how many are due today. 2: the checked tags, such as \"#home and #money\" (Match All) or \"#home or #money\" (Match Any).")
        case (false, false, true):
            return LocalizedStringResource("\(due) due today with \(list) from others.", comment: "My Day's filter sheet: under the lists when tags and From others are checked. 1: how many are due today. 2: the checked tags, such as \"#home and #money\" (Match All) or \"#home or #money\" (Match Any).")
        }
    }
}
