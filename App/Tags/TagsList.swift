import NudgeEngine
import SwiftUI

/// The Tags list: a row per tag. Outside Edit mode a row opens the tag; in it, the row has Rename
/// and Delete beside it. The two are sibling controls, not inside a link: nested in one,
/// VoiceOver merged them into the row and listed them twice.
struct TagsList: View {
    let screen: TagsScreen
    let isEditing: Bool
    let rename: (Tag) -> Void
    /// Called once the person confirms.
    let delete: (TagSummary) -> Void

    var body: some View {
        List {
            Section {
                ForEach(screen.rows, id: \.tag.id) { summary in
                    if isEditing {
                        TagEditRow(summary: summary, rename: { rename(summary.tag) }, delete: { delete(summary) })
                    } else {
                        NavigationLink(value: OpenedTag(id: summary.tag.id)) {
                            TagRowContent(summary: summary, detail: summary.counts)
                        }
                    }
                }
            } header: {
                Text("Your Tags", comment: "Tags: header of the list of tags.")
            } footer: {
                footer
            }
        }
    }

    private var footer: Text {
        if isEditing {
            Text("Deleting a tag removes it from its reminders. The reminders aren't deleted.", comment: "Tags, Edit mode: under the list.")
        } else if screen.untaggedCount > 0 {
            Text("Choose a tag to see its reminders. \(screen.untaggedCount) reminders have no tags; My Day can show them.", comment: "Tags: under the list when some reminders have no tag. The placeholder is how many.")
        } else {
            Text("Choose a tag to see its reminders.", comment: "Tags: under the list.")
        }
    }
}

/// The tile, name and a line of detail: a tag's row without its control.
struct TagRowContent: View {
    let summary: TagSummary
    let detail: LocalizedStringResource

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
        var text = AttributedString(localized: detail)
        for run in text.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            text[run.range].foregroundColor = Color.negative
        }
        return text
    }
}

/// A tag's row in Edit mode: Rename and Delete, each at least 44 pt, stacked at accessibility
/// sizes.
private struct TagEditRow: View {
    let summary: TagSummary
    let rename: () -> Void
    let delete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// On the row, so the question comes from its trash button rather than from the screen.
    @State private var isConfirmingDelete = false

    var body: some View {
        SizeAdaptiveStack {
            TagRowContent(summary: summary, detail: summary.reminderCountText)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Design.Spacing.s3) }
            HStack(spacing: Design.Spacing.controlGap) {
                Button(action: rename) {
                    Text("Rename", comment: "Tags, Edit mode: opens the sheet that renames the tag.")
                }
                .buttonStyle(SmallBorderedButtonStyle())
                .accessibilityLabel(Text("Rename \(summary.tag.label)", comment: "VoiceOver label of a tag's Rename button in Edit mode. The placeholder is the tag, such as \"#home\"."))
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: Design.Spacing.rowMin, minHeight: Design.Spacing.rowMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // An alert, not a confirmation dialog: on iOS 26 a dialog from a button is a popover
                // with no Cancel shown, and deleting is too easy to tap by mistake for that.
                .alert(
                    Text("Delete \(summary.tag.label)?", comment: "Tags: title of the question that asks before deleting a tag. The placeholder is the tag, such as \"#home\"."),
                    isPresented: $isConfirmingDelete
                ) {
                    Button(role: .cancel) {
                    } label: {
                        Text("Cancel", comment: "Keeps the tag instead of deleting it.")
                    }
                    Button(role: .destructive, action: delete) {
                        Text("Delete", comment: "Tags: confirms deleting the tag. The reminders that have it are kept.")
                    }
                } message: {
                    Text(summary.deleteMessage)
                }
                .foregroundStyle(Color.negative)
                .accessibilityLabel(Text("Delete \(summary.tag.label)", comment: "VoiceOver label of a tag's Delete button in Edit mode. The placeholder is the tag, such as \"#home\"."))
            }
        }
    }
}
