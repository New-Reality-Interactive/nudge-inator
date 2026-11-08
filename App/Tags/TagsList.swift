import NudgeEngine
import SwiftUI

/// The Tags list: a row per tag, which opens the tag. A trailing swipe offers Edit and Delete. When
/// nothing matches, the count stays above the no-match state, and the footer goes.
struct TagsList: View {
    let screen: TagsScreen
    let filter: TagListFilter
    /// Each new value puts VoiceOver on the count, which reads the result itself.
    let countFocusRequests: Int
    /// The no-match state's button: clears the search and the filter.
    let clearAll: () -> Void
    let rename: (Tag) -> Void
    /// Called once the person confirms.
    let delete: (TagSummary) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var countFocused: Bool

    var body: some View {
        SearchResultsContainer(countFocus: $countFocused) { didClear in
            List {
                Section {
                    ForEach(screen.rows, id: \.tag.id) { summary in
                        TagRow(summary: summary, rename: { rename(summary.tag) }, delete: { delete(summary) })
                    }
                    if screen.emptyState == .noMatch {
                        TagsNoMatchView(filter: filter) {
                            clearAll()
                            didClear()
                        }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    CountHeaderRow(count: screen.countText, countFocus: $countFocused)
                        .textCase(nil)
                } footer: {
                    if screen.emptyState == nil {
                        Text("Tags are labels you add to reminders. Choose one to see every reminder that has it.", comment: "Tags: under the list.")
                    }
                }
            }
        }
        .onChange(of: countFocusRequests) { countFocused = true }
        // A row a delete or the minute's read takes out animates, and a Sort choice slides the rows
        // to their new places (Brian, on the iPhone, #140).
        .animation(reduceMotion ? nil : .default, value: screen.rows.map(\.tag.id))
    }
}

/// Says nothing matches, never that there are no tags, and names what's narrowing the list.
private struct TagsNoMatchView: View {
    let filter: TagListFilter
    let clear: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(filter.noMatchTitle)
            } icon: {
                Image(systemName: filter.noMatchSystemImage)
            }
        } description: {
            Text(filter.noMatchText)
        } actions: {
            Button(action: clear) {
                Text(filter.noMatchClearTitle)
            }
            .buttonStyle(.bordered)
        }
    }
}

/// A tag's row. It opens the tag's reminders. The trailing swipe offers Edit, at the edge, and
/// Delete, which asks first. Nothing is on the leading edge and there's no full swipe, so a stray
/// swipe neither renames nor deletes. VoiceOver gets the same as the row's own actions: these and
/// the swipe are the only ways to Edit or Delete a tag (DESIGN.md, Swipe actions).
private struct TagRow: View {
    let summary: TagSummary
    let rename: () -> Void
    let delete: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationLink(value: OpenedTag(id: summary.tag.id)) {
            TagRowContent(summary: summary)
                .frame(minHeight: Design.Size.swipeRowContentHeight)
        }
        .accessibilityActions {
            Button(action: rename) { editLabel }
            Button { isConfirmingDelete = true } label: { deleteLabel }
        }
        // Not while VoiceOver is running: it lists a row's swipe actions among its actions, so
        // each would be offered twice.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !voiceOverEnabled {
                SwipeEditTile(label: editLabel, action: rename)
                SwipeDeleteTile(label: deleteLabel) { isConfirmingDelete = true }
            }
        }
        // The system's confirmation dialog with its title showing, as Apple's own apps ask (#286).
        // From a tile, iOS 27.0 (simulator) draws a popover with Delete alone: a tap outside it, or
        // VoiceOver's "Dismiss popup", closes it with nothing deleted. As an action sheet, its Cancel does.
        .confirmationDialog(
            Text("Delete \(summary.tag.label)?", comment: "Tags: title of the question that asks before deleting a tag. The placeholder is the tag, such as \"#home\"."),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive, action: delete) {
                Text("Delete Tag", comment: "Tags: confirms deleting the tag, as Delete Reminder does for a reminder. The reminders that have it are kept.")
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Keeps the tag instead of deleting it.")
            }
        } message: {
            Text(summary.deleteMessage)
        }
    }

    private var editLabel: Text {
        Text("Edit", comment: "Tags: a row's swipe action and VoiceOver action that opens the sheet that renames the tag.")
    }

    private var deleteLabel: Text {
        Text("Delete", comment: "Tags: a row's swipe action and VoiceOver action that asks before deleting the tag.")
    }
}

/// The tile, name and counts of a tag's row.
private struct TagRowContent: View {
    let summary: TagSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = Design.Size.tagTile

    /// Not past the least tap height: stacked above the text, a tile scaled with it only costs room.
    private var tile: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? min(tileSize, Design.Spacing.rowMin) : tileSize
    }

    var body: some View {
        // Stacked at accessibility sizes: beside a tile that large, a long name like
        // "#appointments" had a few letters of width and broke mid-word.
        SizeAdaptiveStack(rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s2) {
            TagTile(size: tile)
            VStack(alignment: .leading, spacing: Design.Spacing.line) {
                Text(verbatim: summary.tag.label)
                    .font(.body)
                Text(styledDetail)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The bold part in the negative color, as the mockup's `note-warn`.
    private var styledDetail: AttributedString {
        var text = AttributedString(localized: summary.counts)
        for run in text.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            text[run.range].foregroundColor = Color.negative
        }
        return text
    }
}

#if DEBUG
#Preview("No match") {
    List {
        TagsNoMatchView(filter: TagListFilter(search: "zebra")) {}
            .listRowBackground(Color.clear)
    }
}

#Preview("No match, filter") {
    List {
        TagsNoMatchView(filter: TagListFilter(hasNoReminders: true)) {}
            .listRowBackground(Color.clear)
    }
}

#Preview("No match, search and filter") {
    List {
        TagsNoMatchView(filter: TagListFilter(search: "zebra", hasNoReminders: true)) {}
            .listRowBackground(Color.clear)
    }
}
#endif
