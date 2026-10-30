import NudgeEngine
import SwiftUI

/// Reminders: every reminder once, in any state, oldest created first, each opening its details.
/// A row's status and due time change as time passes with no change to the engine (a due time
/// passes, an occurrence gives up), so the list is read again at the start of every minute.
struct RemindersTab: View {
    let state: ScreenState
    /// The reminders whose details are pushed on Reminders.
    @Binding var path: [OpenedReminder]
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?

    var body: some View {
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                TimelineView(.everyMinute) { _ in
                    let screen = engine.map { RemindersScreen(engine: $0) }
                    if let screen, screen.emptyState == nil {
                        RemindersListView(screen: screen, openDetails: { path.append(OpenedReminder(id: $0)) })
                    } else {
                        noRemindersYet
                    }
                }
            }
            .navigationTitle(Text(AppTab.reminders.title))
            .reminderDetailsDestination()
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
        }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    /// Centered when it fits; at the largest text sizes it scrolls, so New Reminder can be reached
    /// above the tab bar.
    private var noRemindersYet: some View {
        ViewThatFits(in: .vertical) {
            noRemindersYetContent
            ScrollView { noRemindersYetContent }
        }
    }

    private var noRemindersYetContent: some View {
        ContentUnavailableView {
            Label {
                Text("No Reminders Yet", comment: "Reminders tab: title when there are no reminders at all.")
            } icon: {
                Image(systemName: AppTab.reminders.systemImage)
            }
        } description: {
            Text("Every reminder you make shows here, whatever its state.", comment: "Reminders tab: under the title when there are no reminders at all.")
        } actions: {
            NewReminderButton()
                .labelStyle(.titleAndIcon)
                .buttonStyle(SmallBorderedButtonStyle())
        }
    }
}

private struct RemindersListView: View {
    let screen: RemindersScreen
    let openDetails: (Reminder.ID) -> Void

    var body: some View {
        List {
            ForEach(screen.rows) { row in
                RemindersRowView(row: row, openDetails: { openDetails(row.id) })
            }
        }
    }
}

/// A Reminders row, the mockup's `remListRow`: the due time and its day, the title with its tags,
/// and the status label. It opens the reminder's details. VoiceOver reads the title first, then
/// the status, the due time and the tags.
private struct RemindersRowView: View {
    let row: RemindersScreen.Row
    let openDetails: () -> Void

    var body: some View {
        ReminderRowLayout(openDetails: openDetails) {
            TimeColumn(time: row.time, day: row.day)
        } main: {
            Text(verbatim: row.title)
                .font(.body)
            if !row.tags.isEmpty {
                // Tokens, joined by spaces: they are not a sentence.
                Text(verbatim: row.tags.joined(separator: " "))
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        } trailing: {
            ReminderStatusLabel(status: row.status)
        }
        .accessibilityLabel(Text(voiceOverLabel))
    }

    private var voiceOverLabel: LocalizedStringResource {
        let status = String(localized: row.status.name)
        guard !row.tags.isEmpty else {
            return LocalizedStringResource("\(row.title), \(status), \(row.day), \(row.time)", comment: "VoiceOver label of a Reminders tab row with no tags. 1: the reminder's title. 2: its status, such as \"Nudging\". 3: its due day, such as \"Today\". 4: its due time, such as \"9:00 AM\".")
        }
        let tags = row.tags.formatted(.list(type: .and))
        return LocalizedStringResource("\(row.title), \(status), \(row.day), \(row.time), tags: \(tags)", comment: "VoiceOver label of a Reminders tab row. 1: the reminder's title. 2: its status, such as \"Nudging\". 3: its due day, such as \"Today\". 4: its due time, such as \"9:00 AM\". 5: its tags, such as \"#home and #errands\".")
    }
}

#if DEBUG
#Preview("Light") {
    RemindersTab(state: .ready, path: .constant([]), previewEngine: .myDayPreview())
}

#Preview("Dark") {
    RemindersTab(state: .ready, path: .constant([]), previewEngine: .myDayPreview())
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    RemindersTab(state: .ready, path: .constant([]), previewEngine: .myDayPreview())
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    RemindersTab(state: .ready, path: .constant([]), previewEngine: .myDayPreview())
}

#Preview("Empty") {
    RemindersTab(state: .ready, path: .constant([]))
}
#endif
