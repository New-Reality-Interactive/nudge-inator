import NudgeEngine
import SwiftUI

/// Which sheet is open: a new tag, or a rename.
enum TagSheetKind: Identifiable {
    case new
    case rename(Tag)

    /// What the name field starts with.
    var initialName: String {
        switch self {
        case .new: ""
        case .rename(let tag): tag.name
        }
    }

    /// The tag being renamed, or `nil` for a new one.
    var renamedTagID: Tag.ID? {
        if case .rename(let tag) = self { tag.id } else { nil }
    }

    var title: Text {
        switch self {
        case .new: Text("New Tag", comment: "Title of the sheet that adds a tag.")
        case .rename: Text("Rename Tag", comment: "Title of the sheet that renames a tag.")
        }
    }

    var hint: Text {
        switch self {
        case .new:
            Text("One word. Spaces become hyphens. Add it to a reminder when you create or edit one.", comment: "New Tag sheet: under the name field.")
        case .rename:
            Text("One word. Spaces become hyphens. Every reminder with this tag gets the new name.", comment: "Rename Tag sheet: under the name field.")
        }
    }

    var id: String {
        switch self {
        case .new: "new"
        case .rename(let tag): tag.id.uuidString
        }
    }
}

/// The sheet that adds a tag or renames one, as the mockup's `tagSheet`: a tile, the name, and
/// under it why the name can't be used. Done stays off until the name can be.
struct TagSheet: View {
    let kind: TagSheetKind
    let engine: Engine

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    /// What the engine refused on Done, when the sheet's copy of the tags had gone stale.
    @State private var refused: TagNameDraft.Problem?
    @FocusState private var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric(relativeTo: .largeTitle) private var scaledTileSize: CGFloat = Design.Size.tagTileLarge

    /// Not scaled at accessibility sizes: the tile only decorates, and grown with the text it
    /// pushed the field and its error message down behind the keyboard.
    private var tileSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? Design.Size.tagTileLarge : scaledTileSize
    }

    init(kind: TagSheetKind, engine: Engine) {
        self.kind = kind
        self.engine = engine
        _text = State(initialValue: kind.initialName)
    }

    private var draft: TagNameDraft {
        TagNameDraft(text: text, renaming: kind.renamedTagID, in: engine)
    }

    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    private var shownProblem: TagNameDraft.Problem? {
        draft.shownProblem ?? refused
    }

    var body: some View {
        NavigationStack {
            Form {
                // Left out in landscape: with the keyboard up there is no room for a decoration.
                if !isCompactHeight {
                    Section {
                        TagTile(size: tileSize)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }
                }
                Section {
                    TextField(text: $text) {
                        Text("Tag Name", comment: "The New Tag and Rename Tag sheet's field for the tag's name.")
                    }
                    .multilineTextAlignment(.center)
                    .font(.body.weight(.semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit(save)
                    .onChange(of: text) { refused = nil }
                } header: {
                    // In landscape the keyboard covers whatever sits below the field (even at the
                    // largest text size the field alone ends at its edge), so the error goes above it.
                    if isCompactHeight, let problem = shownProblem {
                        problemText(problem)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                        if !isCompactHeight, let problem = shownProblem {
                            problemText(problem)
                        }
                        kind.hint
                    }
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Label {
                            Text("Cancel", comment: "The tag sheet's cancel button (an xmark).")
                        } icon: {
                            Image(systemName: "xmark")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: save) {
                        Label {
                            Text("Done", comment: "The tag sheet's confirm button (a checkmark).")
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(model == nil || draft.problem != nil)
                }
            }
        }
        .onAppear { isFocused = true }
    }

    private func problemText(_ problem: TagNameDraft.Problem) -> some View {
        Group {
            switch problem {
            case .empty:
                Text("Enter a name for the tag.", comment: "Tag sheet: shown when what was typed leaves no name, such as only a #.")
            case .taken(let existing):
                Text("You already have the tag \(existing.label).", comment: "Tag sheet: shown when another tag has the name, ignoring case. The placeholder is that tag, such as \"#home\".")
            }
        }
        .font(.footnote)
        .textCase(nil)
        .foregroundStyle(Color.negative)
        // A header's content is read as a heading; the error is a message, in either place.
        .accessibilityRemoveTraits(.isHeader)
    }

    private func save() {
        guard let model, draft.problem == nil else { return }
        do throws(TagNameError) {
            if let renamedTagID = kind.renamedTagID {
                try model.renameTag(renamedTagID, to: text)
            } else {
                try model.createTag(named: text)
            }
            dismiss()
        } catch {
            // The draft checked the same rules, so this is only a tag that changed under the sheet.
            refused = TagNameDraft.Problem(error)
        }
    }
}

#Preview("New") {
    TagSheet(kind: .new, engine: .myDayPreview())
}

#Preview("Rename, taken") {
    let engine = Engine.myDayPreview()
    if let work = engine.tags.first(where: { $0.name == "work" }) {
        TagSheet(kind: .rename(work), engine: engine)
    }
}
