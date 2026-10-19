import NudgeEngine
import SwiftUI

/// My Day: today's occurrences in time order with the Done, Nudging, Missed and Left counts, which
/// filter the list when tapped, and a tag filter. They change as time passes with no change to the
/// engine (a nudge fires, an occurrence falls due), so the list is read again at the start of
/// every minute. The filter lives here: it survives switching tabs, not a relaunch.
struct MyDayTab: View {
    let state: ScreenState
    /// The reminders whose details are pushed on My Day.
    @Binding var path: [OpenedReminder]
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var filter = MyDayFilter()
    @State private var isFiltering = false

    var body: some View {
        // In compact height (landscape) the date moves into the bar as the title's subtitle and
        // the filter button into the bar's trailing buttons, as in the mockup, leaving the room
        // to the list.
        let compact = verticalSizeClass == .compact
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                TimelineView(.everyMinute) { context in
                    let screen = screen(at: context.date)
                    MyDayList(
                        screen: screen,
                        reach: engine?.reach,
                        now: context.date,
                        showsDateAndFilter: !compact,
                        tapCount: { filter.tap($0) },
                        removeToken: remove,
                        clearTokens: { filter.clearTags() },
                        openFilter: { isFiltering = true },
                        openDetails: { path.append(OpenedReminder(id: $0)) },
                        markDone: { model?.markDone($0) }
                    )
                }
            }
            .navigationTitle(Text(AppTab.myDay.title))
            .navigationSubtitle(compact ? todayText(.now) : Text(verbatim: ""))
            .reminderDetailsDestination()
            .toolbar {
                if compact {
                    ToolbarItem(placement: .topBarTrailing) {
                        MyDayFilterButton(chosen: checkedCount, style: .bar) { isFiltering = true }
                    }
                }
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
            .sheet(isPresented: $isFiltering) {
                if let engine {
                    MyDayFilterSheetView(engine: engine, filter: $filter)
                }
            }
        }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    /// How many tags, or No Tags, the filter has, without those that were deleted.
    private var checkedCount: Int {
        guard let engine else { return 0 }
        return filter.keeping(tagsIn: Set(engine.tags.map(\.id))).checkedCount
    }

    private func screen(at now: Date) -> MyDayScreen {
        engine.map { MyDayScreen(engine: $0, filter: filter, now: now) } ?? MyDayScreen(filter: filter, now: now)
    }

    private func remove(_ token: MyDayScreen.FilterToken) {
        switch token.kind {
        case .tag(let tagID): filter.toggle(tagID)
        case .noTags: filter.toggleNoTags()
        }
    }
}

/// The date as the mockup writes it under the title: "Sunday, October 18".
private func todayText(_ date: Date) -> Text {
    Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
}

private struct MyDayList: View {
    let screen: MyDayScreen
    /// What can still reach the person, for the permission banners at the top of the list (the
    /// mockup's `permBanner`).
    let reach: Reach?
    let now: Date
    /// Portrait shows the date and the Filter button in the content; landscape has them in the bar.
    let showsDateAndFilter: Bool
    let tapCount: (MyDayCount) -> Void
    let removeToken: (MyDayScreen.FilterToken) -> Void
    let clearTokens: () -> Void
    let openFilter: () -> Void
    let openDetails: (Reminder.ID) -> Void
    let markDone: (Reminder.ID) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        List {
            Section {
                if showsDateAndFilter {
                    plainRow {
                        // The full width, so the label wraps at accessibility sizes instead of
                        // being cut off.
                        MyDayFilterButton(chosen: screen.filterTokens.count, style: .content, open: openFilter)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !screen.filterTokens.isEmpty {
                    plainRow {
                        MyDayFilterTokens(tokens: screen.filterTokens, summary: screen.filterSummary, remove: removeToken, clear: clearTokens)
                    }
                }
                plainRow {
                    MyDayCounts(counts: screen.counts, tap: tapCount)
                }
                if let chosen = screen.counts.first(where: \.isChosen) {
                    plainRow { showingOnlyBar(chosen.kind) }
                }
            } header: {
                VStack(alignment: .leading, spacing: Design.Spacing.s3) {
                    if showsDateAndFilter {
                        todayText(now)
                            .subheadStyle()
                            .textCase(nil)
                    }
                    if let reach {
                        PermissionBanners(reach: reach)
                    }
                }
            }
            Section {
                if screen.rows.isEmpty {
                    EmptyRow(text: Text(screen.emptyMessage))
                } else {
                    ForEach(screen.rows) { row in
                        switch row {
                        case .item(let item):
                            MyDayRowView(item: item, now: now, openDetails: { openDetails(item.reminder.id) }, markDone: { markDone(item.reminder.id) })
                        case .now(let time):
                            NowMarkerView(time: time)
                                .listRowInsets(EdgeInsets(top: Design.Spacing.s1, leading: Design.Spacing.margin, bottom: Design.Spacing.s1, trailing: Design.Spacing.margin))
                        }
                    }
                }
            }
        }
    }

    /// A row of the screen's controls: on the list's background, not in a cell.
    private func plainRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Design.Spacing.s1, leading: 0, bottom: Design.Spacing.s1, trailing: 0))
    }

    /// "Showing only Missed" and Show All, stacked at accessibility sizes.
    private func showingOnlyBar(_ count: MyDayCount) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
        return layout {
            Text(count.showingOnly)
                .subheadStyle()
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Button {
                tapCount(count)
            } label: {
                Text("Show All", comment: "My Day: the button that clears the chosen count and shows every row.")
                    .frame(minHeight: Design.Spacing.rowMin)
            }
        }
    }
}

#Preview("Light") {
    MyDayTab(state: .ready, path: .constant([]), previewEngine: .myDayPreview())
}

#Preview("Dark") {
    MyDayTab(state: .ready, path: .constant([]), previewEngine: .myDayPreview())
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    MyDayTab(state: .ready, path: .constant([]), previewEngine: .myDayPreview())
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    MyDayTab(state: .ready, path: .constant([]), previewEngine: .myDayPreview())
}

#Preview("Empty") {
    MyDayTab(state: .ready, path: .constant([]))
}
