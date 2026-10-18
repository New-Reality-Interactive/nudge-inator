import NudgeEngine

extension Tag {
    /// The tag as "#home". The "#" is the screens' (a tag's name has none).
    var label: String { "#\(name)" }
}

extension Engine {
    /// The tags with these IDs as "#home", in the order given. An ID the engine doesn't hold is
    /// left out, as the tag filters do.
    func tagLabels(for tagIDs: [Tag.ID]) -> [String] {
        tagIDs.compactMap { tag(withID: $0)?.label }
    }

    /// The tag with this ID, or `nil` if the engine doesn't hold it.
    func tag(withID tagID: Tag.ID) -> Tag? {
        tags.first { $0.id == tagID }
    }
}
