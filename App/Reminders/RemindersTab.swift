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
///
/// With sharing (ticket 201), a Mine | Sent control chooses between this person's own reminders,
/// received ones included, and what they sent (`SentList`). It is screen state too, so a launch
/// starts on Mine. The shipped app has no sharing until #216, so it has no control.
struct RemindersTab: View {
    let state: ScreenState
    /// What is pushed on Reminders: reminders' details from Mine, sent reminders' from Sent.
    @Binding var path: NavigationPath
    /// Whether Reminders is the chosen tab. Choosing it again sorts again; `onAppear` isn't relied
    /// on for that, since the docs don't say a tab's content appears again on each return.
    var isChosen = true
    /// Manage People on Sent with no one connected: Settings › Connections (ticket 202).
    var manageConnections: () -> Void = {}
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?
    @State private var keptOrder = RemindersKeptOrder()
    /// What's applied from the filter sheet.
    @State private var choices = RemindersFilterChoices()
    /// The filter sheet open, Mine's or Sent's: the side chosen when it opened, so the sheet can't
    /// turn into the other side's under the person.
    @State private var openFilterSheet: MineOrSent?
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
    /// Mine or Sent (ticket 201).
    @State private var mineOrSentChoice = MineOrSent.mine
    /// Sent's own search, Sort and Filter (tickets 328 and 329), apart from Mine's.
    @State private var sentTools = SentTools()
    /// The edit form a row's Edit opened (#429): a Mine row's, or a Sent row's.
    @State private var editForm: ReminderForm?

    /// The Mine | Sent control's choices.
    enum MineOrSent: Hashable, CaseIterable, Identifiable {
        case mine
        case sent

        var id: Self { self }

        var title: Text {
            switch self {
            case .mine: Text("Mine", comment: "Reminders tab: the Mine | Sent control's choice that shows the person's own reminders, received ones included.")
            case .sent: Text("Sent", comment: "Reminders tab: the Mine | Sent control's choice that shows the reminders the person sent to others.")
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                TimelineView(.everyMinute) { context in
                    Group {
                        if shown == .sent, let model, let sharing = model.sharing {
                            SentList(
                                screen: SentScreen(engine: model.engine, sharing: sharing.data, tools: sentTools),
                                sharing: sharing,
                                manageConnections: manageConnections,
                                countFocusRequests: countFocusRequests,
                                openDetails: { path.append(OpenedSentReminder(id: $0)) },
                                clearSearchAndFilters: { sentTools.clearSearchAndFilter() },
                                edit: { editForm = ReminderForm(editingSent: $0, in: model) },
                                delete: { model.deleteSentLoggingFailure($0) }
                            )
                        } else {
                            mine
                        }
                    }
                    .quietHoursHolding(model, at: context.date)
                }
            }
            .modifier(ListSearchField(
                isShown: shown == .mine ? hasReminders : sentHasTools,
                text: searchField,
                prompt: Text("Search titles and notes", comment: "Reminders tab: the search field's prompt.")
            ))
            // Under the search field, which iOS keeps in the navigation bar (DESIGN.md, Mine | Sent;
            // #201), and as wide. Outside the search field's modifier, which comes and goes with Mine,
            // so choosing Sent doesn't make the control a new view under the person's finger.
            .safeAreaBar(edge: .top) {
                if offersSent { mineOrSent }
            }
            // The field and the Filter button go with the last reminder, and an old search or filter
            // mustn't hide the next one made. The sort stays: it persists by design.
            .onChange(of: hasReminders) {
                if !hasReminders { clearSearchAndFilter() }
            }
            // Sharing switched on again starts on Mine, as a launch does (#387).
            .onChange(of: offersSent) {
                if !offersSent { mineOrSentChoice = .mine }
            }
            // Sent's field and Filter go with its last reminder too.
            .onChange(of: sentHasTools) {
                if !sentHasTools { sentTools.clearSearchAndFilter() }
            }
            .navigationTitle(Text(AppTab.reminders.title))
            .sheet(item: $editForm) { ReminderFormSheet(form: $0) }
            .reminderDetailsDestination()
            .navigationDestination(for: OpenedSentReminder.self) { SentReminderDetailsView(id: $0.id) }
            .toolbar {
                if hasReminders, shown == .mine {
                    ToolbarItem(placement: .topBarTrailing) {
                        FilterButton(
                            sectionsInUse: appliedChoices.sectionsInUse,
                            showsBadge: !dynamicTypeSize.isAccessibilitySize,
                            open: { openFilterSheet = .mine },
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
                if shown == .sent, sentHasTools, let sharing = model?.sharing {
                    SentToolbarItems(
                        tools: $sentTools,
                        sharing: sharing.data,
                        showsBadge: !dynamicTypeSize.isAccessibilitySize,
                        openFilter: { openFilterSheet = .sent },
                        didClearFilters: { countFocusRequests += 1 }
                    )
                }
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
            // Closing the sheet moves VoiceOver to the bar's New button, which cut an announcement of
            // the count off (seen on the iPhone), so it goes to the count, as Clear Filters does.
            .sheet(item: $openFilterSheet, onDismiss: {
                if wasApplied { countFocusRequests += 1 }
                wasApplied = false
            }) { side in
                switch side {
                case .mine:
                    if let engine {
                        RemindersFilterSheetView(engine: engine, applied: appliedChoices, search: searchText) {
                            apply($0)
                            wasApplied = true
                        }
                    }
                case .sent:
                    if let model, let sharing = model.sharing {
                        SentFilterSheetView(engine: model.engine, sharing: sharing.data, applied: sentTools.filter, search: sentTools.search) {
                            let applied = $0
                            withTransaction(Self.noAnimation) { sentTools.filter = applied }
                            wasApplied = true
                        }
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

    /// Mine: the person's own reminders and those received, as before sharing.
    @ViewBuilder private var mine: some View {
        let screen = engine.map {
            RemindersScreen(
                engine: $0,
                sort: sort.wrappedValue,
                filter: filter,
                keptOrder: keptOrder.ids(for: sort.wrappedValue, filter: filter),
                senders: model?.senders ?? Senders()
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
                edit: { id in
                    if let model { editForm = ReminderForm(editing: id, in: model) }
                },
                delete: { model?.delete($0) }
            )
        } else {
            noReminders
        }
    }

    /// Whether the tab offers Sent: only with the sharing model.
    private var offersSent: Bool {
        model?.sharing != nil
    }

    /// Mine or Sent, as shown: Mine whenever Sent isn't offered, so Sharing switched off while Sent
    /// was chosen leaves Mine with its search, Filter and Sort (#387).
    private var shown: MineOrSent {
        offersSent ? mineOrSentChoice : .mine
    }

    /// The Mine | Sent control: the system's segmented picker, filling the content width. Two short
    /// words, so it stays segmented at the accessibility sizes (DESIGN.md). Its label is hidden, as a
    /// segmented control shows none; VoiceOver reads the choices and which one is chosen.
    private var mineOrSent: some View {
        Picker(selection: $mineOrSentChoice.transaction(Self.noAnimation)) {
            ForEach(MineOrSent.allCases, id: \.self) { $0.title.tag($0) }
        } label: {
            Text("Show", comment: "Reminders tab: the hidden label of the Mine | Sent control.")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, Design.Spacing.s4)
        .padding(.bottom, Design.Spacing.s2)
    }

    private var hasReminders: Bool {
        engine?.reminders.isEmpty == false
    }

    /// Whether Sent has anything to search and sort (`SentScreen.hasTools(in:)`).
    private var sentHasTools: Bool {
        model?.sharing.map { SentScreen.hasTools(in: $0.data) } ?? false
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
    /// change takes out animates. Sent's toolbar items use it too.
    static let noAnimation = {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        return transaction
    }()

    /// Typing redraws the list at once. Mine's text or Sent's, whichever is chosen.
    private var searchField: Binding<String> {
        (shown == .mine ? $searchText : $sentTools.search).transaction(Self.noAnimation)
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

    /// As Tags': the text points to the toolbar's +, with no button of its own. It scrolls, so the
    /// text clears the tab bar at the largest text size in landscape (#328's phone check), and is
    /// centered while it fits, as Sent's empty states are.
    private var noReminders: some View {
        // The quiet hours banner stays under the Mine | Sent picker, as the mockup has it; only the
        // empty state is centered in what is left (#379's phone check).
        ScrollView {
            noRemindersContent
        }
        .centeredWhenShort()
        .safeAreaInset(edge: .top, spacing: 0) { QuietHoursBannerAboveEmptyState() }
    }

    private var noRemindersContent: some View {
        ContentUnavailableView {
            EmptyStateLabel(systemImage: AppTab.reminders.systemImage) {
                Text("No Reminders", comment: "Reminders tab: title when there are no reminders at all.")
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
    let edit: (Reminder.ID) -> Void
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
                            edit: { edit(row.id) },
                            delete: { delete(row.id) }
                        )
                    }
                    if screen.emptyState == .noMatch {
                        RemindersNoMatchView(wording: filter) {
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
                    VStack(alignment: .leading, spacing: Design.Spacing.s3) {
                        QuietHoursBannerView()
                        CountHeaderRow(count: screen.countText, countFocus: $countFocused)
                    }
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
/// Sent shows it too, with its own wording for its filters (tickets 328 and 329).
struct RemindersNoMatchView<Wording: NoMatchWording>: View {
    let wording: Wording
    let clear: () -> Void

    var body: some View {
        ContentUnavailableView {
            EmptyStateLabel(systemImage: wording.noMatchSystemImage) {
                Text(wording.noMatchTitle)
            }
        } description: {
            if let text = wording.noMatchText {
                Text(text)
            }
        } actions: {
            Button(action: clear) {
                Text(wording.noMatchClearTitle)
            }
            .buttonStyle(.bordered)
        }
    }
}

/// A Reminders row, the mockup's `remListRow`: the due time and its day, the title with its tags,
/// who sent a received one with its strength, and the status label. It opens the reminder's
/// details. VoiceOver reads `Row.voiceOverLabel`.
///
/// The trailing swipe offers Done while Nudging, at the edge, then Edit on the person's own rows
/// (#429), and Delete on every row, which asks first. Nothing is on the leading edge and there's no
/// full swipe (ADR 0001). VoiceOver gets the same as the row's own actions, since the row has no
/// Done or Edit button.
private struct RemindersRowView: View {
    let row: RemindersScreen.Row
    let openDetails: () -> Void
    let markDone: () -> Void
    let edit: () -> Void
    let delete: () -> Void

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
            if let from = row.from {
                FromLabel(from: from, strength: row.reminder.strength)
            }
        } trailing: {
            ReminderStatusLabel(status: row.status)
        }
        .accessibilityLabel(Text(row.voiceOverLabel))
        .rowActions(actions)
        .deleteReminderConfirmation(title: row.title, kind: DeletedReminderKind(isReceived: row.reminder.isReceived), isPresented: $isConfirmingDelete, confirm: delete)
    }

    /// Done while Nudging, at the edge, then Edit on the person's own rows, then Delete.
    private var actions: [RowAction] {
        var actions: [RowAction] = []
        if row.offersDone {
            // The row stays, its status now Done, and VoiceOver on it doesn't read it again.
            actions.append(RowAction(kind: .done, label: doneLabel, action: markDone, voiceOverAction: {
                markDone()
                VoiceOverAnnouncement.post(VoiceOverAnnouncement.done(row.title))
            }))
        }
        if row.offersEdit {
            actions.append(RowAction(kind: .edit, label: editLabel, action: edit))
        }
        actions.append(RowAction(kind: .delete, label: deleteLabel, action: { isConfirmingDelete = true }))
        return actions
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

    private var editLabel: Text {
        Text("Edit", comment: "Reminders tab: a row's swipe action and VoiceOver action that opens the Edit Reminder form.")
    }

    /// Remove on a received reminder's row (ticket 200), as the mockup's swipe says it.
    private var deleteLabel: Text {
        row.reminder.isReceived
            ? Text("Remove", comment: "Reminders tab: a received reminder's swipe action and VoiceOver action that asks before removing the person's copy.")
            : Text("Delete", comment: "Reminders tab: a row's swipe action and VoiceOver action that asks before deleting the reminder.")
    }
}

#if DEBUG
#Preview("Light") {
    RemindersTab(state: .ready, path: .constant(NavigationPath()), previewEngine: .myDayPreview())
}

#Preview("Dark") {
    RemindersTab(state: .ready, path: .constant(NavigationPath()), previewEngine: .myDayPreview())
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    RemindersTab(state: .ready, path: .constant(NavigationPath()), previewEngine: .myDayPreview())
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    RemindersTab(state: .ready, path: .constant(NavigationPath()), previewEngine: .myDayPreview())
}

#Preview("Empty") {
    RemindersTab(state: .ready, path: .constant(NavigationPath()))
}

#Preview("No match, filters") {
    List {
        RemindersNoMatchView(wording: RemindersFilter(statuses: [.nudging, .paused])) {}
            .listRowBackground(Color.clear)
    }
}

#Preview("No match, search") {
    List {
        RemindersNoMatchView(wording: RemindersFilter(search: "zebra")) {}
            .listRowBackground(Color.clear)
    }
}

#Preview("No match, search and filters") {
    List {
        RemindersNoMatchView(wording: RemindersFilter(statuses: [.missed], search: "zebra")) {}
            .listRowBackground(Color.clear)
    }
}
#endif
