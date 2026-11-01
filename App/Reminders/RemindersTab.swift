import NudgeEngine
import SwiftUI

/// Reminders: every reminder once, in any state, in the Sort menu's order, each opening its
/// details. A row's status and due time change as time passes with no change to the engine (a due
/// time passes, an occurrence gives up), so the list is read again at the start of every minute.
///
/// The rows keep the order they had when the tab was chosen, the sort or filter changed or the store
/// was read, so Done or going Missed doesn't move a row sorted by Due Date. Pushing details keeps it;
/// leaving the tab and coming back sorts again.
///
/// The filter, search included, is screen state, so a launch resets it and Back from details keeps it.
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
    @State private var filter = RemindersFilter()
    /// What's in the search field, spaces included. `filter` holds it trimmed, so a space typed after
    /// a word doesn't change the list's inputs.
    @State private var searchText = ""
    /// What the engine held when the filter last changed: `RemindersScreen.list(engine:sort:filter:knownIDs:)`.
    /// Not taken again on returning to the tab, which doesn't change the filter.
    @State private var knownIDs: Set<Reminder.ID>?
    /// Set by Clear Filters, whose result VoiceOver reads from the count once focus moves there.
    @State private var skipNextAnnouncement = false
    /// The sort previews show, since they have no app model to keep it.
    @State private var previewSort = RemindersSort.createdOldestFirst

    var body: some View {
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                TimelineView(.everyMinute) { _ in
                    let screen = engine.map {
                        RemindersScreen(
                            engine: $0,
                            sort: sort.wrappedValue,
                            filter: filter,
                            keptOrder: keptOrder?.ids(for: sort.wrappedValue, filter: filter),
                            knownIDs: knownIDs
                        )
                    }
                    if let screen, screen.emptyState != .noReminders {
                        RemindersListView(
                            screen: screen,
                            sort: sort.transaction(Self.noAnimation),
                            filter: $filter.transaction(Self.noAnimation),
                            clearFilters: {
                                // Focus goes to the count, which reads the result itself.
                                skipNextAnnouncement = true
                                searchText = ""
                                filter = RemindersFilter()
                            },
                            openDetails: { path.append(OpenedReminder(id: $0)) },
                            markDone: { model?.markDone($0) },
                            delete: { model?.delete($0) }
                        )
                    } else {
                        noReminders
                    }
                }
            }
            .modifier(RemindersSearchField(isShown: engine?.reminders.isEmpty == false, text: searchField))
            .navigationTitle(Text(AppTab.reminders.title))
            .reminderDetailsDestination()
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
        }
        .onAppear {
            if knownIDs == nil {
                takeKnownIDs()
            } else {
                keepOrder(knownIDs: knownIDs)
            }
        }
        .onChange(of: isChosen) { if isChosen { keepOrder(knownIDs: knownIDs) } }
        .onChange(of: sort.wrappedValue) { keepOrder(knownIDs: knownIDs) }
        .onChange(of: filter) { old, new in
            let list = takeKnownIDs()
            // Not on each letter typed, as the mockup doesn't: VoiceOver is reading the letters.
            let isTyping = new.search != old.search && !new.search.isEmpty
            if skipNextAnnouncement {
                skipNextAnnouncement = false
            } else if !isTyping, let list {
                announceCount(of: list)
            }
        }
        .onChange(of: state) { takeKnownIDs() }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    /// A chip or a Sort choice redraws the list at once, as the mockup does. Only a row a state
    /// change takes out animates.
    private static let noAnimation = {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        return transaction
    }()

    /// Typing redraws the list at once, as a chip does.
    private var searchField: Binding<String> {
        Binding {
            searchText
        } set: {
            searchText = $0
            filter.search = $0
        }
        .transaction(Self.noAnimation)
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
    /// `knownIDs` is passed, not read, since the docs don't say a read of `@State` sees a write
    /// made earlier in the same `onChange`.
    @discardableResult
    private func keepOrder(knownIDs: Set<Reminder.ID>?) -> RemindersList? {
        let sort = sort.wrappedValue
        let list = engine.map { RemindersScreen.list(engine: $0, sort: sort, filter: filter, knownIDs: knownIDs) }
        keptOrder = list.map { KeptOrder(sort: sort, filter: filter, ids: $0.items.map(\.reminder.id)) }
        return list
    }

    /// Takes what the engine holds now as known, and keeps the rows' order under it.
    @discardableResult
    private func takeKnownIDs() -> RemindersList? {
        let known = engine.map { Set($0.reminders.map(\.id)) }
        knownIDs = known
        return keepOrder(knownIDs: known)
    }

    /// VoiceOver stays on the chip, so it says the new count, as the mockup does. Low priority, so
    /// it follows the chip's own "selected" rather than cutting it off (WWDC23, "Build accessible
    /// apps with SwiftUI and UIKit").
    private func announceCount(of list: RemindersList) {
        var count = AttributedString(String(localized: RemindersScreen.countText(shown: list.items.count, of: list.total)))
        count.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(count).post()
    }

    /// An order kept for one sort and filter. Until `onChange` keeps one for a new one, the first
    /// frame drawn with it sorts afresh rather than show the old order.
    private struct KeptOrder {
        let sort: RemindersSort
        let filter: RemindersFilter
        let ids: [Reminder.ID]

        func ids(for sort: RemindersSort, filter: RemindersFilter) -> [Reminder.ID]? {
            sort == self.sort && filter == self.filter ? ids : nil
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

/// The search field under the title, while there's anything to search: the no-reminders empty state
/// has none, as the mockup draws it.
private struct RemindersSearchField: ViewModifier {
    let isShown: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isShown {
            content.searchable(
                text: $text,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search titles and notes", comment: "Reminders tab: the search field's prompt.")
            )
        } else {
            content
        }
    }
}

private struct RemindersListView: View {
    let screen: RemindersScreen
    @Binding var sort: RemindersSort
    @Binding var filter: RemindersFilter
    let clearFilters: () -> Void
    let openDetails: (Reminder.ID) -> Void
    let markDone: (Reminder.ID) -> Void
    let delete: (Reminder.ID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismissSearch) private var dismissSearch
    @AccessibilityFocusState private var countFocused: Bool

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
                if screen.emptyState == .noMatch {
                    RemindersNoMatchView(filter: filter) {
                        clearFilters()
                        // Ends the search too, if it's still active, so Cancel and the keyboard go with its text.
                        dismissSearch()
                        countFocused = true
                    }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } header: {
                // Above the rows' group, not in a cell, as the mockup draws it. It stays above the
                // no-match empty state, so the chip can be turned off here.
                RemindersHeaderRow(count: screen.countText, sort: $sort, filter: $filter, countFocus: $countFocused)
                    .textCase(nil)
            }
        }
        // By the rows, not `withAnimation` around Done and Delete: a row can also leave on the
        // minute, when the clock alone takes it out of the filter.
        .animation(reduceMotion ? nil : .default, value: screen.rows.map(\.id))
    }
}

/// Says nothing matches, never that there are no reminders, and names what's narrowing the list.
private struct RemindersNoMatchView: View {
    let filter: RemindersFilter
    let clear: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(filter.noMatchTitle)
            } icon: {
                Image(systemName: filter.noMatchSystemImage)
            }
        } description: {
            if let text = filter.noMatchText {
                Text(text)
            }
        } actions: {
            Button(action: clear) {
                Text(filter.noMatchClearTitle)
            }
            .buttonStyle(.bordered)
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

#Preview("No match, chip") {
    List {
        RemindersNoMatchView(filter: RemindersFilter(statuses: [.nudging])) {}
            .listRowBackground(Color.clear)
    }
}

#Preview("No match, search") {
    List {
        RemindersNoMatchView(filter: RemindersFilter(search: "zebra")) {}
            .listRowBackground(Color.clear)
    }
}

#Preview("No match, search and chip") {
    List {
        RemindersNoMatchView(filter: RemindersFilter(statuses: [.missed], search: "zebra")) {}
            .listRowBackground(Color.clear)
    }
}
#endif
