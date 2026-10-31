import NudgeEngine
import SwiftUI

/// Reminders: every reminder once, in any state, in the Sort menu's order, each opening its
/// details. A row's status and due time change as time passes with no change to the engine (a due
/// time passes, an occurrence gives up), so the list is read again at the start of every minute.
///
/// The rows keep the order they had when the tab was chosen, the sort changed or the store was
/// read, so Done or going Missed doesn't move a row sorted by Due Date. Pushing details keeps it;
/// leaving the tab and coming back sorts again.
struct RemindersTab: View {
    let state: ScreenState
    /// The reminders whose details are pushed on Reminders.
    @Binding var path: [OpenedReminder]
    /// Whether Reminders is the chosen tab. Choosing it again sorts again; `onAppear` isn't relied
    /// on for that, since the docs don't say a tab's content appears again on each return.
    var isChosen = true
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?
    @State private var keptOrder: KeptOrder?
    /// The sort previews show, since they have no app model to keep it.
    @State private var previewSort = RemindersSort.createdOldestFirst

    var body: some View {
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                TimelineView(.everyMinute) { _ in
                    let screen = engine.map { RemindersScreen(engine: $0, sort: sort.wrappedValue, keptOrder: keptOrder?.ids(for: sort.wrappedValue)) }
                    if let screen, screen.emptyState == nil {
                        RemindersListView(
                            screen: screen,
                            sort: sort,
                            openDetails: { path.append(OpenedReminder(id: $0)) },
                            markDone: { model?.markDone($0) },
                            delete: { id in withAnimation { model?.delete(id) } }
                        )
                    } else {
                        noReminders
                    }
                }
            }
            .navigationTitle(Text(AppTab.reminders.title))
            .reminderDetailsDestination()
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
        }
        .onAppear(perform: keepOrder)
        .onChange(of: isChosen) { if isChosen { keepOrder() } }
        .onChange(of: sort.wrappedValue) { keepOrder() }
        .onChange(of: state) { keepOrder() }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    /// The model's, which outlives a relaunch, or the previews' own.
    private var sort: Binding<RemindersSort> {
        if let model {
            Binding { model.remindersSort } set: { model.remindersSort = $0 }
        } else {
            $previewSort
        }
    }

    /// The rows' order as the engine sorts them now, kept until the list's inputs next change.
    private func keepOrder() {
        let sort = sort.wrappedValue
        keptOrder = engine.map { KeptOrder(sort: sort, ids: $0.remindersList(sortedBy: sort).items.map(\.reminder.id)) }
    }

    /// An order kept for one sort. Until `onChange` keeps one for a new sort, the first frame
    /// drawn with it sorts afresh rather than show the old sort's order.
    private struct KeptOrder {
        let sort: RemindersSort
        let ids: [Reminder.ID]

        func ids(for sort: RemindersSort) -> [Reminder.ID]? {
            sort == self.sort ? ids : nil
        }
    }

    /// As Tags': the text points to the toolbar's +, with no button of its own.
    private var noReminders: some View {
        ContentUnavailableView {
            Label {
                Text("No Reminders", comment: "Reminders tab: title when there are no reminders at all.")
            } icon: {
                Image(systemName: AppTab.reminders.systemImage)
            }
        } description: {
            Text("Tap + to make one. Every reminder you make shows here, whatever its state.", comment: "Reminders tab: under the title when there are no reminders at all.")
        }
    }
}

private struct RemindersListView: View {
    let screen: RemindersScreen
    @Binding var sort: RemindersSort
    let openDetails: (Reminder.ID) -> Void
    let markDone: (Reminder.ID) -> Void
    let delete: (Reminder.ID) -> Void

    var body: some View {
        List {
            Section {
                ForEach(screen.rows) { row in
                    RemindersRowView(
                        row: row,
                        openDetails: { openDetails(row.id) },
                        markDone: { markDone(row.id) },
                        delete: { delete(row.id) }
                    )
                }
            } header: {
                // Above the rows' group, not in a cell, as the mockup draws it.
                RemindersHeaderRow(count: screen.countText, sort: $sort)
                    .textCase(nil)
            }
        }
    }
}

/// A Reminders row, the mockup's `remListRow`: the due time and its day, the title with its tags,
/// and the status label. It opens the reminder's details. VoiceOver reads the title first, then
/// the status, the due time and the tags.
///
/// The trailing swipe offers Done while Nudging, at the edge, and Delete on every row, which asks
/// first. Nothing is on the leading edge and there's no full swipe (ADR 0001). VoiceOver gets
/// the same as the row's own actions, since the row has no Done button.
private struct RemindersRowView: View {
    let row: RemindersScreen.Row
    let openDetails: () -> Void
    let markDone: () -> Void
    let delete: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var isConfirmingDelete = false

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
        .accessibilityActions {
            if row.offersDone {
                Button(action: markDone) { doneLabel }
            }
            Button { isConfirmingDelete = true } label: { deleteLabel }
        }
        // Not while VoiceOver is running: it lists a row's swipe actions among its actions
        // (My Day's rows showed it on the phone), so each would be offered twice.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !voiceOverEnabled {
                if row.offersDone {
                    SwipeDoneTile(label: doneLabel, action: markDone)
                }
                SwipeDeleteTile(label: deleteLabel) { isConfirmingDelete = true }
            }
        }
        .deleteReminderConfirmation(title: row.title, isPresented: $isConfirmingDelete, confirm: delete)
    }

    private var doneLabel: Text {
        Text("Done", comment: "Reminders tab: a Nudging row's swipe action and VoiceOver action that marks the reminder Done and stops its nudges.")
    }

    private var deleteLabel: Text {
        Text("Delete", comment: "Reminders tab: a row's swipe action and VoiceOver action that asks before deleting the reminder.")
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
