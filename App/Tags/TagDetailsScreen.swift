import NudgeEngine

/// What a tag's details page shows, read from the engine at one moment: the tag and the counts its
/// row on the Tags list shows for it, the same numbers from the same read. A value, so the tests and
/// previews read it with no view.
struct TagDetailsScreen {
    let summary: TagSummary

    var tag: Tag { summary.tag }

    /// `nil` when the engine doesn't hold the tag: it was deleted while its page was open.
    init?(engine: Engine, tagID: Tag.ID) {
        guard let summary = engine.tagSummary(for: tagID) else { return nil }
        self.summary = summary
    }
}
