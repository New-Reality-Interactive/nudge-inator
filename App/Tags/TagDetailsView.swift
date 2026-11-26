import NudgeEngine
import SwiftUI

/// A tag's details page, pushed on Tags from a tag's row as a reminder's details are from
/// Reminders (the mockup's `viewTagDetails`): the tag's tile, name and counts, and a Reminders row
/// that opens the tag's reminders. It reads the engine again at every change and every minute, so
/// its counts stay true, and shows Tag Deleted if the tag goes while it is open.
struct TagDetailsView: View {
    let tagID: Tag.ID
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.dismiss) private var dismiss
    /// The Rename Tag sheet, which Edit opens. Here, so it survives the page's minute redraw.
    @State private var sheet: TagSheetKind?
    @State private var isConfirmingDelete = false
    /// What was on screen when Delete Tag was confirmed. The tag is gone from the engine at once,
    /// but the page is still sliding away, and shouldn't flash Tag Deleted while it does.
    @State private var deleted: TagDetailsScreen?

    var body: some View {
        TimelineView(.everyMinute) { _ in
            Group {
                if let screen = deleted ?? current {
                    TagDetailsList(screen: screen, isEnabled: deleted == nil) { isConfirmingDelete = true }
                        .deleteTagConfirmation(screen.summary, isPresented: $isConfirmingDelete) {
                            deleted = screen
                            model?.deleteTag(tagID)
                            dismiss()
                        }
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    sheet = .rename(screen.tag)
                                } label: {
                                    Text("Edit", comment: "A tag's details page: the toolbar button that opens the Rename Tag sheet.")
                                }
                                .accessibilityLabel(Text("Edit \(screen.tag.label)", comment: "VoiceOver label of a tag's details page's Edit button. The placeholder is the tag, such as \"#home\"."))
                                .disabled(engine == nil || deleted != nil)
                            }
                        }
                } else {
                    TagDeletedView()
                }
            }
        }
        // The bar holds only its buttons: the hero carries the name.
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { kind in
            if let engine {
                TagSheet(kind: kind, engine: engine)
            }
        }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    private var current: TagDetailsScreen? {
        engine.flatMap { TagDetailsScreen(engine: $0, tagID: tagID) }
    }
}

private struct TagDetailsList: View {
    let screen: TagDetailsScreen
    let isEnabled: Bool
    let delete: () -> Void

    var body: some View {
        List {
            Section {
                TagDetailsHero(summary: screen.summary)
            }
            Section {
                NavigationLink(value: OpenedTagReminders(id: screen.tag.id)) {
                    // The glyph and the word in the accent, as Pause Reminder is on a reminder's details.
                    // At accessibility sizes the glyph sits above the word, so the one long word keeps
                    // the row's width instead of breaking mid-word (#378's phone check).
                    SizeAdaptiveStack(rowSpacing: Design.Spacing.s2, stackedSpacing: Design.Spacing.line) {
                        Image(systemName: "list.bullet.clipboard")
                            .accessibilityHidden(true)
                        Text("Reminders", comment: "A tag's details page: the row that opens the tag's reminders.")
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
            Section {
                Button(role: .destructive, action: delete) {
                    Label {
                        Text("Delete Tag", comment: "A tag's details page: opens the question that asks before deleting the tag, as Delete Reminder does on a reminder's details.")
                    } icon: {
                        // Red with the word: a Label's glyph took the accent here (#378's phone check).
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .disabled(!isEnabled)
        .centeredInReadableColumn()
    }
}

/// The tile beside the name and counts. At accessibility sizes the tile sits above them, so the
/// text keeps its width.
private struct TagDetailsHero: View {
    let summary: TagSummary

    @ScaledMetric(relativeTo: .title2) private var tile: CGFloat = Design.Size.tagTileLarge * 2 / 3

    var body: some View {
        SizeAdaptiveStack(rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s2) {
            RoundTile(symbol: "tag", size: tile)
            VStack(alignment: .leading, spacing: Design.Spacing.line) {
                Text(verbatim: summary.tag.label)
                    .font(.title2.bold())
                Text(summary.styledCounts)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
        .padding(.vertical, Design.Spacing.s1)
        .accessibilityElement(children: .combine)
        // On the combined element, so the heading doesn't depend on how `.combine` merges traits:
        // with the bar's title empty, the hero is the page's only heading.
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TagDetailsView(tagID: Engine.myDayPreview().tags[0].id, previewEngine: .myDayPreview()) }
}

#Preview("Largest text") {
    NavigationStack { TagDetailsView(tagID: Engine.myDayPreview().tags[0].id, previewEngine: .myDayPreview()) }
        .dynamicTypeSize(.accessibility5)
}

#Preview("Deleted") {
    NavigationStack { TagDetailsView(tagID: Tag(name: "gone").id, previewEngine: .myDayPreview()) }
}
#endif
