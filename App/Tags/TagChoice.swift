import Foundation
import NudgeEngine

/// The tags a filter sheet has chosen, on My Day and on Reminders: the tags checked, Match All or
/// Any, or No Tags, as the mockup's `dayFilter`.
struct TagChoice: Equatable {
    /// The checked tags, in the order they were checked.
    private(set) var tagIDs: [Tag.ID] = []
    var match: Match = .all
    /// Only reminders without tags. It excludes the checked tags, as the mockup's `none` does.
    private(set) var noTags = false

    /// Whether a reminder needs every checked tag or any one of them.
    enum Match: Equatable {
        case all
        case any

        /// The tags as a list in the engine's locale: "#home and #money", or "#home or #money".
        func list(of labels: [String]) -> String {
            labels.formatted(.list(type: self == .all ? .and : .or))
        }
    }

    /// The engine's filter for the checked tags. With none checked, nothing is filtered.
    var tagFilter: TagFilter {
        if noTags { return .noTags }
        guard !tagIDs.isEmpty else { return .off }
        // With one tag All and Any mean the same, whichever was chosen when there were two.
        guard tagIDs.count > 1 else { return .matchAll(Set(tagIDs)) }
        switch match {
        case .all: return .matchAll(Set(tagIDs))
        case .any: return .matchAny(Set(tagIDs))
        }
    }

    /// Checks the tag, or unchecks it if it is checked.
    mutating func toggle(_ tagID: Tag.ID) {
        noTags = false
        if let index = tagIDs.firstIndex(of: tagID) {
            tagIDs.remove(at: index)
        } else {
            tagIDs.append(tagID)
        }
    }

    /// Shows only reminders without tags, or turns that off. Turning it on unchecks the tags.
    mutating func toggleNoTags() {
        noTags.toggle()
        if noTags { tagIDs = [] }
    }

    var isOn: Bool { noTags || !tagIDs.isEmpty }

    /// The checked tags, or 1 for No Tags.
    var checkedCount: Int { noTags ? 1 : tagIDs.count }

    /// Clears the tags and No Tags and goes back to Match All.
    mutating func clear() {
        self = TagChoice()
    }

    /// The choice without tags that no longer exist. A tag that was deleted while chosen would
    /// otherwise stay in Match All, which no reminder could meet.
    func keeping(tagsIn existing: Set<Tag.ID>) -> TagChoice {
        var kept = self
        kept.tagIDs.removeAll { !existing.contains($0) }
        return kept
    }
}

/// What a filter sheet's tag sections show, read from the engine at one moment.
struct TagChoiceRows {
    var tags: [Row]
    var isNoTagsChecked: Bool
    /// The Match control is always shown, so checking a tag doesn't move the rows, and can be
    /// chosen once two or more tags are checked.
    var canChooseMatch: Bool
    /// Under the tags: why Match can't be chosen yet, or what its choices do.
    var footer: LocalizedStringResource

    struct Row: Identifiable {
        var tag: Tag
        var isChecked: Bool

        var id: Tag.ID { tag.id }
        var text: String { tag.label }
    }

    init(engine: Engine, choice: TagChoice) {
        let chosen = Set(choice.tagIDs)
        tags = engine.tagSummaries().map { Row(tag: $0.tag, isChecked: chosen.contains($0.tag.id)) }
        isNoTagsChecked = choice.noTags
        canChooseMatch = choice.tagIDs.count > 1
        footer = canChooseMatch
            ? LocalizedStringResource("All Tags shows reminders with every checked tag. Any Tag shows those with at least one.", comment: "A filter sheet: under the tags when two or more are checked.")
            : LocalizedStringResource("Check one or more tags. Match needs two or more.", comment: "A filter sheet: under the tags when fewer than two are checked. It says why the Match choice above them is dimmed.")
    }
}
