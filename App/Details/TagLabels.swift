import NudgeEngine

extension Engine {
    /// The tags with these IDs as "#home", in the order given. An ID the engine doesn't hold is
    /// left out, as the tag filters do. The "#" is the screens' (a tag's name has none).
    func tagLabels(for tagIDs: [Tag.ID]) -> [String] {
        tagIDs.compactMap { tagID in tags.first { $0.id == tagID }.map { "#\($0.name)" } }
    }
}
