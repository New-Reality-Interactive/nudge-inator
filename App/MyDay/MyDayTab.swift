import NudgeEngine
import SwiftUI

/// My Day: a day's occurrences in time order with the Done, Nudging, Missed and Left counts, which
/// filter the list when tapped, and a tag filter. They change as time passes with no change to the
/// engine (a nudge fires, an occurrence falls due), so the list is read again at the start of
/// every minute. A sideways swipe, Previous Day and Next Day move between days, and Today comes
/// back (#375). The filter and the day live here: they survive switching tabs, not a relaunch.
struct MyDayTab: View {
    let state: ScreenState
    /// The reminders whose details are pushed on My Day.
    @Binding var path: [OpenedReminder]
    /// What previews show, since they have no app model.
    var previewEngine: Engine?

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter = MyDayFilter()
    /// The day the person moved to, or `nil` for today, which then follows the clock past midnight.
    @State private var askedDay: CalendarDay?
    /// The day shown, from the screen read each minute, since the bar sits outside that read.
    @State private var shown: MyDayShownDay?
    /// The side the new day slides in from: the side the move came from.
    @State private var slideEdge = Edge.trailing
    @State private var isFiltering = false
    /// Whether the Filter button shows, from the screen read each minute, since the bar sits outside
    /// that read.
    @State private var offersFilter = false

    var body: some View {
        // In compact height (landscape) the date moves into the bar as the title's subtitle, as in
        // the mockup, leaving the room to the list.
        let compact = verticalSizeClass == .compact
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                TimelineView(.everyMinute) { context in
                    let screen = screen(at: context.date)
                    MyDayList(
                        screen: screen,
                        reach: engine?.reach,
                        now: context.date,
                        showsDate: !compact,
                        tapCount: { filter.tap($0) },
                        removeToken: remove,
                        openFilter: { isFiltering = true },
                        openDetails: { path.append(OpenedReminder(id: $0)) },
                        markDone: { model?.markDone($0) },
                        moveDay: { move($0) }
                    )
                    // A new list for each day, so it slides in whole and starts at its top.
                    .id(screen.shown.day)
                    .transition(reduceMotion ? .opacity : .push(from: slideEdge))
                    // With the button gone (an empty day at midnight, the last tag deleted) the tag
                    // filter goes too, but not when the person moved day (#375): the filter keeps
                    // applying from day to day. Only a move changes the day asked for; the clock
                    // doesn't.
                    .onChange(of: FilterOffer(asked: askedDay, offers: screen.offersFilter), initial: true) { old, new in
                        offersFilter = new.offers
                        filter.update(offersFilter: new.offers, afterMovingDay: old.asked != new.asked)
                    }
                    .onChange(of: screen.shown, initial: true) { _, day in shown = day }
                    .quietHoursHolding(model, at: context.date)
                }
            }
            .navigationTitle(Text(AppTab.myDay.title))
            .navigationSubtitle(compact ? dayLabel : Text(verbatim: ""))
            .reminderDetailsDestination()
            .toolbar {
                // Today, on the leading side, only while another day is showing.
                if let shown, !shown.isToday, state == .ready {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            // Today comes in from the side it lies on: from a past day, the trailing side.
                            move(to: nil, from: shown.isLater ? .leading : .trailing)
                        } label: {
                            Text("Today", comment: "My Day: the top bar's button, shown on another day, that goes back to today.")
                        }
                    }
                }
                // In landscape the day label is the bar's subtitle, so Previous Day and Next Day sit
                // in the bar, sharing one glass capsule as the tutorials' Back and Next do.
                if compact, let shown, state == .ready {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        MyDayDayButtons(shown: shown) { move($0) }
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                if offersFilter, state == .ready {
                    ToolbarItem(placement: .topBarTrailing) {
                        MyDayFilterButton(
                            chosen: checkedCount,
                            showsBadge: !dynamicTypeSize.isAccessibilitySize,
                            open: { isFiltering = true },
                            clear: { filter.clear() }
                        )
                    }
                    // The Filter button is a glass group of its own and New stands apart, as on
                    // Reminders and Tags (Decision 56).
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
            .sheet(isPresented: $isFiltering) {
                if let engine {
                    MyDayFilterSheetView(engine: engine, filter: $filter, day: shown?.day)
                }
            }
        }
    }

    private var engine: Engine? {
        model?.engine ?? previewEngine
    }

    /// How many tags, or No Tags, the filter has, without those that were deleted, and one more for
    /// From others.
    private var checkedCount: Int {
        guard let engine else { return 0 }
        return filter.keeping(tagsIn: Set(engine.tags.map(\.id))).checkedCount
    }

    private func screen(at now: Date) -> MyDayScreen {
        engine.map { MyDayScreen(engine: $0, filter: filter, now: now, senders: model?.senders ?? Senders(), day: askedDay) } ?? MyDayScreen(filter: filter, now: now)
    }

    /// The bar's subtitle in landscape: the day label, or today's date before the first read.
    private var dayLabel: Text {
        shown?.labelText ?? todayText(.now)
    }

    /// Previous Day, Next Day and the swipe. Nothing moves past the range's ends.
    private func move(_ move: MyDayMove) {
        guard let shown, let target = move.target(from: shown) else { return }
        self.move(to: target, from: move.edge)
    }

    /// Shows `day`, today if `nil`, sliding in from `edge`, and says it to VoiceOver: the day and
    /// how many are due. VoiceOver's focus is left where iOS puts it (#276, #221).
    private func move(to day: CalendarDay?, from edge: Edge) {
        let asked = day == engine?.today ? nil : day
        slideEdge = edge
        withAnimation(reduceMotion ? nil : .smooth) {
            askedDay = asked
        }
        guard let engine else { return }
        let shown = MyDayShownDay(engine: engine, asked: asked)
        let filter = filter.keeping(tagsIn: Set(engine.tags.map(\.id)))
        let due = engine.myDay(on: shown.day, tagFilter: filter.tagFilter, fromOthers: filter.fromOthers).items.count
        VoiceOverAnnouncement.post(shown.announcement(due: due, filtered: filter.isOn))
    }

    private func remove(_ token: MyDayScreen.FilterToken) {
        switch token.kind {
        case .tag(let tagID): filter.toggle(tagID)
        case .noTags: filter.toggleNoTags()
        case .fromOthers: filter.toggleFromOthers()
        }
    }
}

/// What decides whether the filter clears: whether the Filter button shows, and the day the
/// person asked for, which only a move changes.
private struct FilterOffer: Equatable {
    var asked: CalendarDay?
    var offers: Bool
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
    /// Portrait shows the date in the content; landscape has it in the bar.
    let showsDate: Bool
    let tapCount: (MyDayCount) -> Void
    let removeToken: (MyDayScreen.FilterToken) -> Void
    let openFilter: () -> Void
    let openDetails: (Reminder.ID) -> Void
    let markDone: (Reminder.ID) -> Void
    let moveDay: (MyDayMove) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Where the Nudging rows are, so a drag that starts on one stays that row's Done swipe.
    @State private var nudgingRows = MyDayRowFrames()

    /// The list's own coordinates, which the swipe and the rows' frames share.
    private static let space = "myDayList"

    var body: some View {
        list
            .coordinateSpace(.named(Self.space))
            .modifier(MyDayDaySwipe(shown: screen.shown, nudgingRows: nudgingRows, space: Self.space, move: moveDay))
            .onChange(of: screen.items.filter(\.offersDone).map(\.id), initial: true) { _, ids in nudgingRows.keep(Set(ids)) }
    }

    private var list: some View {
        List {
            Section {
                if !screen.filterTokens.isEmpty {
                    plainRow {
                        MyDayFilterTokens(tokens: screen.filterTokens, summary: screen.filterSummary, remove: removeToken, openFilter: openFilter)
                    }
                }
                plainRow {
                    MyDayCounts(counts: screen.counts, label: screen.shown.countsLabel, tap: tapCount)
                }
                if let chosen = screen.counts.first(where: \.isChosen) {
                    plainRow { showingOnlyBar(chosen.kind) }
                }
            } header: {
                VStack(alignment: .leading, spacing: Design.Spacing.s3) {
                    if showsDate {
                        MyDayDayRow(shown: screen.shown, move: moveDay)
                    }
                    if let reach {
                        PermissionBanners(reach: reach)
                    }
                    QuietHoursBannerView()
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
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frame in
                                    nudgingRows.set(item.offersDone ? frame : nil, for: item.id)
                                }
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

#if DEBUG
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
#endif
