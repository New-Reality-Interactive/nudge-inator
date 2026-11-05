import NudgeEngine
import SwiftUI

/// Tags: your tags with their counts, in the Sort menu's order, a search by name, a filter, + to add
/// one, and a swipe to edit or delete one. A tag opens its reminders. The sheets live here, so they
/// survive a redraw of the list. The search and the filter are screen state, so a launch resets them
/// and Back from a tag keeps them.
///
/// The list is read again at the start of every minute, as Reminders' is, so a tag that starts or
/// stops matching the filter comes and goes with no tap.
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
    /// What's in the search field, spaces included. `filter` holds it trimmed, so a space typed after
    /// a word doesn't change the list.
    @State private var searchText = ""
    /// What's applied from the filter sheet.
    @State private var choices = TagsFilterChoices()
    @State private var isFiltering = false
    /// Apply was tapped, so the count takes VoiceOver when the sheet has closed.
    @State private var wasApplied = false
    /// Each one puts VoiceOver on the count.
    @State private var countFocusRequests = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                TimelineView(.everyMinute) { _ in
                    let screen = engine.map { TagsScreen(engine: $0, sort: sort.wrappedValue, filter: filter) }
                    if let screen, screen.emptyState != .noTags {
                        TagsList(
                            screen: screen,
                            filter: filter,
                            countFocusRequests: countFocusRequests,
                            clearAll: {
                                searchText = ""
                                choices = TagsFilterChoices()
                            },
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
            }
            // Here as well as on the list's rows: the last tag's delete swaps the list for the empty state.
            .animation(reduceMotion ? nil : .default, value: hasTags)
            .modifier(ListSearchField(
                isShown: hasTags,
                text: $searchText,
                prompt: Text("Search tags", comment: "Tags tab: the search field's prompt.")
            ))
            // The field and the Filter button go with the last tag, and an old search or filter
            // mustn't hide the next tag made.
            .onChange(of: hasTags) {
                if !hasTags {
                    searchText = ""
                    choices = TagsFilterChoices()
                }
            }
            .navigationTitle(Text(AppTab.tags.title))
            .navigationDestination(for: OpenedTag.self) { TagRemindersView(tagID: $0.id, previewEngine: previewEngine) }
            .reminderDetailsDestination()
            .toolbar {
                if hasTags {
                    ToolbarItem(placement: .topBarTrailing) {
                        FilterButton(
                            sectionsInUse: choices.sectionsInUse,
                            showsBadge: !dynamicTypeSize.isAccessibilitySize,
                            open: { isFiltering = true },
                            clear: {
                                choices = TagsFilterChoices()
                                countFocusRequests += 1
                            }
                        )
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        TagsSortButton(sort: sort)
                    }
                    // Filter and Sort share a glass group, and New Tag stands apart, as on Reminders
                    // (Decision 49).
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
            // Closing the sheet moves VoiceOver to the bar, which cut an announcement of the count
            // off on Reminders, so after Apply it goes to the count, as there.
            .sheet(isPresented: $isFiltering, onDismiss: {
                if wasApplied { countFocusRequests += 1 }
                wasApplied = false
            }) {
                if let engine {
                    TagsFilterSheetView(engine: engine, applied: choices, search: searchText) {
                        choices = $0
                        wasApplied = true
                    }
                }
            }
        }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    private var hasTags: Bool {
        engine?.tags.isEmpty == false
    }

    /// What narrows the list: the sheet's filter and the search, together.
    private var filter: TagListFilter {
        choices.narrowing(search: searchText)
    }

    /// The model's, which outlives a relaunch, or the previews' own.
    private var sort: Binding<TagSort> {
        if let model {
            Binding { model.tagsSort } set: { model.tagsSort = $0 }
        } else {
            $previewSort
        }
    }

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
