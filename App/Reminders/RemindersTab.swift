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
/// The sheet's filters and the search are screen state, so a launch resets them and Back from
/// details keeps them.
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
    @State private var keptOrder = RemindersKeptOrder()
    /// What's applied from the filter sheet.
    @State private var choices = RemindersFilterChoices()
    @State private var isFiltering = false
    /// Apply was tapped, so the count takes VoiceOver when the sheet has closed.
    @State private var wasApplied = false
    /// Each one puts VoiceOver on the count.
    @State private var countFocusRequests = 0
    /// What's in the search field, spaces included. `filter` holds it trimmed, so a space typed after
    /// a word doesn't change the list's inputs.
    @State private var searchText = ""
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                            keptOrder: keptOrder.ids(for: sort.wrappedValue, filter: filter)
                        )
                    }
                    if let screen, screen.emptyState != .noReminders {
                        RemindersListView(
                            screen: screen,
                            filter: filter,
                            countFocusRequests: countFocusRequests,
                            clearFilters: clearSearchAndFilter,
                            openDetails: { path.append(OpenedReminder(id: $0)) },
                            markDone: { model?.markDone($0) },
                            delete: { model?.delete($0) }
                        )
                    } else {
                        noReminders
                    }
                }
            }
            .modifier(ListSearchField(
                isShown: hasReminders,
                text: searchField,
                prompt: Text("Search titles and notes", comment: "Reminders tab: the search field's prompt.")
            ))
            // The field and the Filter button go with the last reminder, and an old search or filter
            // mustn't hide the next one made. The sort stays: it persists by design.
            .onChange(of: hasReminders) {
                if !hasReminders { clearSearchAndFilter() }
            }
            .navigationTitle(Text(AppTab.reminders.title))
            .reminderDetailsDestination()
            .toolbar {
                if hasReminders {
                    ToolbarItem(placement: .topBarTrailing) {
                        FilterButton(
                            sectionsInUse: appliedChoices.sectionsInUse,
                            showsBadge: !dynamicTypeSize.isAccessibilitySize,
                            open: { isFiltering = true },
                            clear: {
                                apply(RemindersFilterChoices())
                                countFocusRequests += 1
                            }
                        )
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        RemindersSortButton(sort: sort.transaction(Self.noAnimation))
                    }
                    // Filter and Sort share a glass group, and New stands apart (Brian, #113).
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
            // Closing the sheet moves VoiceOver to the bar's New button, which cut an announcement of
            // the count off (seen on the iPhone), so it goes to the count, as Clear Filters does.
            .sheet(isPresented: $isFiltering, onDismiss: {
                if wasApplied { countFocusRequests += 1 }
                wasApplied = false
            }) {
                if let engine {
                    RemindersFilterSheetView(engine: engine, applied: appliedChoices, search: searchText) {
                        apply($0)
                        wasApplied = true
                    }
                }
            }
        }
        .onAppear { keepOrder(for: .appeared(keptOrderInputs)) }
        .onChange(of: keptOrderInputs) { old, new in keepOrder(for: .changed(from: old, to: new)) }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    private var hasReminders: Bool {
        engine?.reminders.isEmpty == false
    }

    /// What's applied, without tags deleted since.
    private var appliedChoices: RemindersFilterChoices {
        keepingExistingTags(choices)
    }

    private func keepingExistingTags(_ filter: RemindersFilterChoices) -> RemindersFilterChoices {
        filter.keeping(tagsIn: Set(engine?.tags.map(\.id) ?? []))
    }

    /// What narrows the list: the sheet's filters and the search, together.
    private var filter: RemindersFilter {
        appliedChoices.narrowing(search: searchText)
    }

    private func clearSearchAndFilter() {
        searchText = ""
        choices = RemindersFilterChoices()
    }

    /// Apply and Clear All Filters: the list redraws at once. The search stays as it is.
    private func apply(_ new: RemindersFilterChoices) {
        withTransaction(Self.noAnimation) { choices = new }
    }

    /// A filter or a Sort choice redraws the list at once, as the mockup does. Only a row a state
    /// change takes out animates.
    private static let noAnimation = {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        return transaction
    }()

    /// Typing redraws the list at once.
    private var searchField: Binding<String> {
        $searchText.transaction(Self.noAnimation)
    }

    /// The model's, which outlives a relaunch, or the previews' own.
    private var sort: Binding<RemindersSort> {
        if let model {
            Binding { model.remindersSort } set: { model.remindersSort = $0 }
        } else {
            $previewSort
        }
    }

    private var keptOrderInputs: RemindersKeptOrder.Inputs {
        RemindersKeptOrder.Inputs(isChosen: isChosen, sort: sort.wrappedValue, filter: filter, state: state)
    }

    /// Keeps the rows' order again when the change calls for it, from the rows the screen shows.
    private func keepOrder(for change: RemindersKeptOrder.Change) {
        keptOrder.respond(to: change) { sort, filter in
            engine.map { RemindersScreen(engine: $0, sort: sort, filter: filter) }
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
    let filter: RemindersFilter
    /// Each new value puts VoiceOver on the count, which reads the result itself.
    let countFocusRequests: Int
    let clearFilters: () -> Void
    let openDetails: (Reminder.ID) -> Void
    let markDone: (Reminder.ID) -> Void
    let delete: (Reminder.ID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var countFocused: Bool

    var body: some View {
        SearchResultsContainer(countFocus: $countFocused) { didClear in
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
                            // Asks VoiceOver to go to the count; iOS picks where it lands (SearchResultsContainer).
                            didClear()
                        }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    // Above the rows' group, not in a cell, as the mockup draws it. It stays above the
                    // no-match empty state.
                    CountHeaderRow(count: screen.countText, countFocus: $countFocused)
                        .textCase(nil)
                }
            }
        }
        .onChange(of: countFocusRequests) { countFocused = true }
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
        ReminderRowLayout(openDetails: openDetails, minHeight: Design.Size.swipeRowContentHeight) {
            TimeColumn(time: row.time, day: row.day)
        } main: {
            Text(verbatim: row.title)
                .font(.body)
            if !row.tags.isEmpty {
                Text(tagLine)
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

    /// Tokens, joined by spaces: they are not a sentence. The filter's are bold (DESIGN.md).
    private var tagLine: AttributedString {
        var line = AttributedString()
        for (index, tag) in row.tags.enumerated() {
            var text = AttributedString(index == 0 ? tag.text : " " + tag.text)
            if tag.isChosen { text.inlinePresentationIntent = .stronglyEmphasized }
            line += text
        }
        return line
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
        let tags = row.tags.map(\.text).formatted(.list(type: .and))
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

#Preview("No match, filters") {
    List {
        RemindersNoMatchView(filter: RemindersFilter(statuses: [.nudging, .paused])) {}
            .listRowBackground(Color.clear)
    }
}

#Preview("No match, search") {
    List {
        RemindersNoMatchView(filter: RemindersFilter(search: "zebra")) {}
            .listRowBackground(Color.clear)
    }
}

#Preview("No match, search and filters") {
    List {
        RemindersNoMatchView(filter: RemindersFilter(statuses: [.missed], search: "zebra")) {}
            .listRowBackground(Color.clear)
    }
}
#endif
