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

    var body: some View {
        TimelineView(.everyMinute) { _ in
            Group {
                if let engine = model?.engine ?? previewEngine, let screen = TagDetailsScreen(engine: engine, tagID: tagID) {
                    TagDetailsList(screen: screen)
                } else {
                    TagDeletedView()
                }
            }
        }
        // The bar holds only its Back button: the hero carries the name.
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TagDetailsList: View {
    let screen: TagDetailsScreen

    var body: some View {
        List {
            Section {
                TagDetailsHero(summary: screen.summary)
            }
            Section {
                NavigationLink(value: OpenedTagReminders(id: screen.tag.id)) {
                    Text("Reminders", comment: "A tag's details page: the row that opens the tag's reminders.")
                }
                .frame(minHeight: Design.Size.swipeRowContentHeight)
            }
        }
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
                    .accessibilityAddTraits(.isHeader)
                Text(summary.styledCounts)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
        .padding(.vertical, Design.Spacing.s1)
        .accessibilityElement(children: .combine)
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
