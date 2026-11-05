import NudgeEngine
import SwiftUI

/// Tags: your tags with their counts, in the Sort menu's order, + to add one, and a swipe to edit or
/// delete one. A tag opens its reminders. The sheet lives here, so it survives a redraw of the list.
struct TagsTab: View {
    let state: ScreenState
    /// A tag's screen, and the reminders pushed from it.
    @Binding var path: NavigationPath
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheet: TagSheetKind?
    /// The sort previews show, since they have no app model to keep it.
    @State private var previewSort = TagSort.nameAToZ

    var body: some View {
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                if let engine, !engine.tags.isEmpty {
                    TagsList(
                        screen: TagsScreen(engine: engine, sort: sort.wrappedValue),
                        rename: { sheet = .rename($0) },
                        delete: { model?.deleteTag($0.tag.id) }
                    )
                } else {
                    // Scrolls only when it must: at the largest text the help text ran off the screen.
                    ViewThatFits(in: .vertical) {
                        emptyState
                        ScrollView { emptyState }
                    }
                }
            }
            // Here as well as on the list's rows: the last tag's delete swaps the list for the empty state.
            .animation(reduceMotion ? nil : .default, value: engine?.tags.isEmpty)
            .navigationTitle(Text(AppTab.tags.title))
            .navigationDestination(for: OpenedTag.self) { TagRemindersView(tagID: $0.id, previewEngine: previewEngine) }
            .reminderDetailsDestination()
            .toolbar {
                if engine?.tags.isEmpty == false {
                    ToolbarItem(placement: .topBarTrailing) {
                        TagsSortButton(sort: sort.transaction(Self.noAnimation))
                    }
                    // New Tag stands apart, as New does on Reminders (Decision 49).
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
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
        }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    /// The model's, which outlives a relaunch, or the previews' own.
    private var sort: Binding<TagSort> {
        if let model {
            Binding { model.tagsSort } set: { model.tagsSort = $0 }
        } else {
            $previewSort
        }
    }

    /// A Sort choice redraws the list at once, as on Reminders. Only a row a delete takes out animates.
    private static let noAnimation = {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        return transaction
    }()

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No Tags", comment: "Tags: title when there are no tags yet.")
            } icon: {
                Image(systemName: "tag")
            }
        } description: {
            Text("Tags are labels, like #home or #errands, that you add to reminders so you can find them together. Tap + to make one, or add one when you create or edit a reminder.", comment: "Tags: under the title when there are no tags yet: what a tag is and how to make one.")
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
