import NudgeEngine

/// What My Day is filtered by: the tags the person checked, as the mockup's `dayFilter`.
struct MyDayFilter: Equatable {
    /// The checked tags, in the order they were checked.
    private(set) var tagIDs: [Tag.ID] = []
    var match: Match = .all
    /// The count the list is narrowed to, if the person tapped one.
    private(set) var count: MyDayCount?
    /// Only reminders without tags. It excludes the checked tags, as the mockup's `none` does.
    private(set) var noTags = false

    /// Whether a reminder needs every checked tag or any one of them.
    enum Match: Equatable {
        case all
        case any
    }

    /// The engine's filter for the checked tags. With none checked, nothing is filtered.
    var tagFilter: TagFilter {
        if noTags { return .noTags }
        guard !tagIDs.isEmpty else { return .off }
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

    /// Narrows the list to the count, or shows everything again if it is already chosen.
    mutating func tap(_ count: MyDayCount) {
        self.count = self.count == count ? nil : count
    }

    /// Whether tags, or No Tags, are chosen.
    var hasTags: Bool { noTags || !tagIDs.isEmpty }

    /// Clears the tags and No Tags and goes back to Match All. The chosen count stays: it is
    /// chosen on the screen, not in the sheet.
    mutating func clearTags() {
        tagIDs = []
        noTags = false
        match = .all
    }

    /// The filter without tags that no longer exist. A tag that was deleted while chosen would
    /// otherwise stay in Match All, which no reminder could meet.
    func keeping(tagsIn existing: Set<Tag.ID>) -> MyDayFilter {
        var kept = self
        kept.tagIDs.removeAll { !existing.contains($0) }
        return kept
    }
}
