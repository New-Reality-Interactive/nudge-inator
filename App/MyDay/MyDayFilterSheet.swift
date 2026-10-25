import Foundation
import NudgeEngine

/// What the filter sheet shows, read from the engine at one moment: every tag with a check, No
/// Tags, and how many are due today with the filter on. A value, so the tests read it with no view.
struct MyDayFilterSheet {
    var tags: [TagRow]
    var isNoTagsChecked: Bool
    /// The Match control is always shown, so checking a tag doesn't move the rows, and can be
    /// chosen once two or more tags are checked.
    var canChooseMatch: Bool
    /// Under the tags: why Match can't be chosen yet, or what its choices do.
    var tagsFooter: LocalizedStringResource
    var result: LocalizedStringResource

    struct TagRow: Identifiable {
        var tag: Tag
        var isChecked: Bool

        var id: Tag.ID { tag.id }
        var text: String { tag.label }
    }

    init(engine: Engine, filter: MyDayFilter) {
        let filter = filter.keeping(tagsIn: Set(engine.tags.map(\.id)))
        let chosen = Set(filter.tagIDs)
        tags = engine.tagSummaries().map { TagRow(tag: $0.tag, isChecked: chosen.contains($0.tag.id)) }
        isNoTagsChecked = filter.noTags
        canChooseMatch = filter.tagIDs.count > 1
        tagsFooter = canChooseMatch
            ? LocalizedStringResource("All Tags shows reminders with every checked tag. Any Tag shows those with at least one.", comment: "My Day's filter sheet: under the tags when two or more are checked.")
            : LocalizedStringResource("Check one or more tags. Match needs two or more.", comment: "My Day's filter sheet: under the tags when fewer than two are checked. It says why the Match choice above them is dimmed.")
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
