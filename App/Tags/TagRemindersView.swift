import NudgeEngine
import SwiftUI

/// A tag's screen, pushed on Tags: the reminders with the tag in the mockup's sections, and a +
/// that starts a new reminder with the tag chosen. It reads the engine again at every change and
/// every minute.
struct TagRemindersView: View {
    let tagID: Tag.ID
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TimelineView(.everyMinute) { _ in
            if let engine = model?.engine ?? previewEngine {
                content(TagRemindersScreen(engine: engine, tagID: tagID))
            }
        }
    }

    @ViewBuilder
    private func content(_ screen: TagRemindersScreen?) -> some View {
        Group {
            if let screen {
                list(screen)
                    .navigationTitle(Text(verbatim: screen.tag.label))
                    .toolbar { ToolbarItem(placement: .primaryAction) { NewReminderButton(tagIDs: [tagID]) } }
            } else {
                ContentUnavailableView {
                    Label {
                        Text("Tag Deleted", comment: "A tag's screen after the tag was deleted.")
                    } icon: {
                        Image(systemName: "tag.slash")
                    }
                } description: {
                    Text("This tag was deleted. Its reminders are still there.", comment: "A tag's screen after the tag was deleted.")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func list(_ screen: TagRemindersScreen) -> some View {
        if screen.sections.isEmpty {
            ContentUnavailableView {
                Label {
                    Text("No Reminders", comment: "A tag's screen when no reminder has the tag.")
                } icon: {
                    Image(systemName: "tag")
                }
            } description: {
                Text("No reminder has this tag yet. Tap + to make one, or add the tag to a reminder you already have.", comment: "A tag's screen when no reminder has the tag.")
            }
        } else {
            List {
                Section {
                } header: {
                    Text("\(screen.reminderCount) reminders with \(screen.tag.label)", comment: "A tag's screen: under the title. 1: how many reminders have the tag. 2: the tag, such as \"#home\".")
                        .subheadStyle()
                        .textCase(nil)
                }
                ForEach(screen.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            TagReminderRowView(row: row)
                        }
                    } header: {
                        section.kind.title
                    }
                }
            }
            .centeredInReadableColumn()
        }
    }
}

extension TagRemindersScreen.SectionKind {
    var title: Text {
        switch self {
        case .today: Text("Today", comment: "A tag's screen: header of the reminders that are nudging or due later today.")
        case .later: Text("Later", comment: "A tag's screen: header of the reminders due after today.")
        case .paused: Text("Paused", comment: "A tag's screen: header of the paused reminders.")
        case .completed: Text("Completed", comment: "A tag's screen: header of the reminders with nothing more to come.")
        }
    }
}

/// A reminder on a tag's screen: its time and day, the title with its tags and schedule, and the
/// strength badge. A link to its details on the Tags stack.
struct TagReminderRowView: View {
    let row: TagRemindersScreen.Row

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = Design.Size.timeColumn

    var body: some View {
        NavigationLink(value: OpenedReminder(id: row.reminder.id)) {
            SizeAdaptiveStack(rowAlignment: .firstTextBaseline, rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s1) {
                timeColumn
                    .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? nil : timeWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: Design.Spacing.line) {
                    Text(verbatim: row.title)
                        .font(.body)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                StrengthBadge(strength: row.reminder.strength)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var timeColumn: some View {
        if let time = row.time, let day = row.day {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: time)
                    .font(.body)
                    .monospacedDigit()
                Text(verbatim: day)
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        } else {
            Text(verbatim: "—")
                .font(.body)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .accessibilityHidden(true)
        }
    }

    /// The tags, this screen's in bold, then the schedule.
    private var detail: AttributedString {
        var tags = AttributedString()
        for (index, tag) in row.tags.enumerated() {
            var text = AttributedString(index == 0 ? tag.text : " " + tag.text)
            if tag.isChosen { text.inlinePresentationIntent = .stronglyEmphasized }
            tags += text
        }
        guard !row.tags.isEmpty else { return AttributedString(row.schedule) }
        return AttributedString(localized: "\(tags) · \(row.schedule)", comment: "A tag's screen: under a reminder's title. 1: its tags, such as \"#home #errands\", this screen's tag in bold. 2: its schedule, such as \"Every day at 8:00 AM\".")
    }
}

#Preview("Home") {
    NavigationStack {
        let engine = Engine.myDayPreview()
        TagRemindersView(tagID: engine.tags.first { $0.name == "home" }?.id ?? UUID(), previewEngine: engine)
            .reminderDetailsDestination()
    }
}
