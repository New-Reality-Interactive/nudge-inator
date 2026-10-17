import NudgeEngine
import SwiftUI

/// The form's Tags page, as the mockup's: a field to add a tag, then every tag with a checkmark
/// on the chosen ones. Tags stay editable while nudging.
struct TagsPage: View {
    @Bindable var form: ReminderForm
    @State private var newTag = ""
    @FocusState private var isNewTagFocused: Bool

    var body: some View {
        Form {
            Section {
                HStack(spacing: Design.Spacing.controlGap) {
                    TextField(text: $newTag) {
                        Text("New Tag", comment: "The Tags page's field for typing a new tag's name.")
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNewTagFocused)
                    .onSubmit(add)
                    Button(action: add) {
                        Text("Add", comment: "The Tags page's button that adds the typed tag to the reminder.")
                    }
                    .buttonStyle(.bordered)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } footer: {
                Text("One word. Spaces become hyphens. A reminder can have as many tags as you like.",
                     comment: "Under the Tags page's New Tag field.")
            }
            Section {
                if form.tags.isEmpty {
                    EmptyRow(text: Text("No tags yet. Add one above.", comment: "The Tags page's list when there are no tags."))
                }
                ForEach(sortedTags) { tag in
                    // The person's own tag name, never translated.
                    CheckmarkRow(title: Text(verbatim: "#\(tag.name)"), isChecked: form.tagIDs.contains(tag.id)) {
                        form.toggleTag(tag.id)
                    }
                }
            } header: {
                Text("Your Tags", comment: "The Tags page's section header above every tag.")
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("Tags", comment: "Title of the reminder form's Tags page."))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedTags: [Tag] {
        form.tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Adds the typed tag and keeps the field focused for the next one, as the mockup does.
    private func add() {
        form.addTag(named: newTag)
        newTag = ""
        isNewTagFocused = true
    }
}

#Preview("Tags") {
    NavigationStack {
        TagsPage(form: .preview(tags: ["home", "money", "errands"]))
    }
}

#Preview("No tags, largest text") {
    NavigationStack {
        TagsPage(form: .preview())
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
