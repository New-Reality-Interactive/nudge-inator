import NudgeEngine
import SwiftUI

/// Tags: your tags with their counts, + to add one, and Edit to rename or delete them. A tag opens
/// its reminders. Editing and the sheet live here, so they survive a redraw of the list.
struct TagsTab: View {
    let state: ScreenState
    /// A tag's screen, and the reminders pushed from it.
    @Binding var path: NavigationPath
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?
    @State private var isEditing = false
    @State private var sheet: TagSheetKind?

    var body: some View {
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                if let engine, !engine.tags.isEmpty {
                    TagsList(
                        screen: TagsScreen(engine: engine),
                        isEditing: isEditing,
                        rename: { sheet = .rename($0) },
                        delete: { model?.deleteTag($0.tag.id) }
                    )
                } else {
                    emptyState
                }
            }
            .navigationTitle(Text(AppTab.tags.title))
            .navigationDestination(for: OpenedTag.self) { TagRemindersView(tagID: $0.id, previewEngine: previewEngine) }
            .reminderDetailsDestination()
            .toolbar {
                if state == .ready, let engine, !engine.tags.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isEditing.toggle()
                        } label: {
                            isEditing
                                ? Text("Done", comment: "Tags: leaves Edit mode.")
                                : Text("Edit", comment: "Tags: enters Edit mode, where a tag can be renamed or deleted.")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sheet = .new
                    } label: {
                        Label {
                            Text("New Tag", comment: "Toolbar button (a plus) on Tags that adds a tag.")
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(engine == nil || state != .ready)
                }
            }
            .sheet(item: $sheet) { kind in
                if let engine {
                    TagSheet(kind: kind, engine: engine)
                }
            }
            // Edit mode ends when the last tag is deleted, with no Edit button left to end it.
            .onChange(of: engine?.tags.isEmpty ?? true) { _, isEmpty in
                if isEmpty { isEditing = false }
            }
        }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No Tags", comment: "Tags: title when there are no tags yet.")
            } icon: {
                Image(systemName: "tag")
            }
        } description: {
            Text("Tap + to add a tag, or add tags to a reminder when you create or edit it.", comment: "Tags: how to add a tag when there are none.")
        }
    }
}

#if DEBUG
#Preview("Light") {
    TagsTab(state: .ready, path: .constant(NavigationPath()), previewEngine: .myDayPreview())
}

#Preview("Dark") {
    TagsTab(state: .ready, path: .constant(NavigationPath()), previewEngine: .myDayPreview())
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    TagsTab(state: .ready, path: .constant(NavigationPath()), previewEngine: .myDayPreview())
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    TagsTab(state: .ready, path: .constant(NavigationPath()), previewEngine: .myDayPreview())
}

#Preview("Empty") {
    TagsTab(state: .ready, path: .constant(NavigationPath()))
}
#endif
