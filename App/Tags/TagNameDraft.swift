import NudgeEngine

/// The name typed in the New Tag and Rename Tag sheet, checked with the engine's own rules (on a
/// copy, so nothing is created), so the sheet has no rule of its own.
struct TagNameDraft {
    enum Problem: Equatable {
        /// Nothing is left once the name is made one word.
        case empty
        /// Another tag has the name, ignoring case.
        case taken(Tag)

        init(_ error: TagNameError) {
            switch error {
            case .empty: self = .empty
            case .taken(by: let existing): self = .taken(existing)
            }
        }
    }

    /// Why the name can't be used, or `nil` when it can. Done is disabled while it is set.
    let problem: Problem?
    private let isBlank: Bool

    /// What the sheet says under the field. Nothing for a field with nothing typed yet, which
    /// only disables Done.
    var shownProblem: Problem? { isBlank && problem == .empty ? nil : problem }

    /// `tagID` is the tag being renamed, or `nil` for a new one.
    init(text: String, renaming tagID: Tag.ID?, in engine: Engine) {
        isBlank = text.allSatisfy(\.isWhitespace)
        var copy = engine
        do throws(TagNameError) {
            if let tagID {
                try copy.renameTag(tagID, to: text)
            } else {
                _ = try copy.createTag(named: text)
            }
            problem = nil
        } catch {
            problem = Problem(error)
        }
    }
}
