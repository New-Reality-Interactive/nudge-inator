import Foundation
import NudgeEngine

/// What the filter sheet shows, read from the engine at one moment: every tag with a check, No
/// Tags, and how many are due today with the filter on. A value, so the tests read it with no view.
struct MyDayFilterSheet {
    let choice: TagChoiceRows
    var result: LocalizedStringResource

    var tags: [TagChoiceRows.Row] { choice.rows }
    var isNoTagsChecked: Bool { choice.isNoTagsChecked }
    var canChooseMatch: Bool { choice.canChooseMatch }
    var tagsFooter: LocalizedStringResource { choice.footer }

    init(engine: Engine, filter: MyDayFilter) {
        let filter = filter.keeping(tagsIn: Set(engine.tags.map(\.id)))
        choice = TagChoiceRows(engine: engine, choice: filter.tags)
        let due = engine.myDay(tagFilter: filter.tagFilter).items.count
        if filter.noTags {
            result = LocalizedStringResource("\(due) due today without tags.", comment: "My Day's filter sheet: under the lists when No Tags is checked. The placeholder is how many are due today.")
        } else if filter.tagIDs.isEmpty {
            result = LocalizedStringResource("Showing everything due today (\(due)).", comment: "My Day's filter sheet: under the lists when nothing is checked. The placeholder is how many are due today.")
        } else {
            let list = filter.match.list(of: engine.tagLabels(for: filter.tagIDs))
            result = LocalizedStringResource("\(due) due today with \(list).", comment: "My Day's filter sheet: under the lists when tags are checked. 1: how many are due today. 2: the checked tags, such as \"#home and #money\" (Match All) or \"#home or #money\" (Match Any).")
        }
    }
}
