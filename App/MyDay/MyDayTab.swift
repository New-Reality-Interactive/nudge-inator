import NudgeEngine
import SwiftUI

/// My Day: a day's occurrences in time order with the Done, Nudging, Missed and Left counts, which
/// filter the list when tapped, and a tag filter. They change as time passes with no change to the
/// engine (a nudge fires, an occurrence falls due), so the list is read again at the start of
/// every minute. Previous Day and Next Day move between days, and Today comes back (#375). The filter and the day live here: they survive switching tabs, not a relaunch.
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
    /// The day shown, from the page read each minute, since the bar sits outside that read.
    @State private var shown: MyDayShownDay?
    @State private var isFiltering = false
    /// Whether the Filter button shows, from the page read each minute, since the bar sits outside
    /// that read.
    @State private var offersFilter = false

    var body: some View {
        // In compact height (landscape) the date moves into the bar as the title's subtitle, as in
        // the mockup, leaving the room to the list.
        let compact = verticalSizeClass == .compact
        NavigationStack(path: $path) {
            // Each page centers its own list: the column's margins on the row of pages made them
            // narrower than the screen in landscape, so the next day showed and a turn of the
            // phone left it between two days (the phone, 2026-11-23).
            TabScreen(state: state, centersInReadableColumn: false) {
                VStack(spacing: 0) {
                    // Above the pages, so it stays still while they move, as in the mockup.
                    if !compact, let shown {
                        MyDayDayRow(shown: shown) { move($0) }
                            .padding(.horizontal, Design.Spacing.margin)
                            .frame(maxWidth: Design.Spacing.readableWidth)
                            .padding(.bottom, Design.Spacing.s2)
                    }
                    pages
                }
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .navigationTitle(Text(AppTab.myDay.title))
            .navigationSubtitle(compact ? dayLabel : Text(verbatim: ""))
            .reminderDetailsDestination()
            .toolbar {
                // Today, on the leading side, only while another day is showing.
                if let shown, !shown.isToday, state == .ready {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            move(to: nil)
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
            // Previous Day, Next Day and Today change the day asked for; the clock
            // passing midnight doesn't, so it isn't announced.
            .onChange(of: askedDay) { announceDay() }
        }
    }

    /// The days side by side, a page each, which slide to the day the buttons pick. Each page reads
    /// its day again at the start of every minute.
    @ViewBuilder private var pages: some View {
        if let engine {
            let selected = selectedDay(engine)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(MyDayShownDay.days(of: engine), id: \.self) { day in
                        page(day, engine: engine, isSelected: day == selected)
                            .containerRelativeFrame(.horizontal)
                            .id(day)
                            // Only the page on screen is reachable with VoiceOver.
                            .accessibilityHidden(day != selected)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: position(engine))
            .scrollIndicators(.hidden)
            // No swipe between days: Previous Day, Next Day and Today move them, and the pages
            // slide (the developer's call on the phone, 2026-11-23). With iOS's paging, a sideways
            // drag on a Nudging row moved the day and never opened the row's Done swipe, and a
            // paged TabView pages whatever `scrollDisabled` says. A scroll view takes it (Apple's
            // docs), and passes it down to every scroll view below, so each page's list turns its
            // own scrolling back on.
            .scrollDisabled(true)
            // A page is the full width, so the snapping matches the pages; each list keeps to the
            // safe area through its own column margins.
            .ignoresSafeArea(.container, edges: .horizontal)
            // Turning the phone changes the page width but not the scroll offset, so the row is
            // made again, starting on the day shown.
            .id(verticalSizeClass)
        } else {
            TimelineView(.everyMinute) { context in
                list(MyDayScreen(filter: filter, now: context.date), now: context.date)
                    .quietHoursHolding(model, at: context.date)
            }
        }
    }

    private func page(_ day: CalendarDay, engine: Engine, isSelected: Bool) -> some View {
        TimelineView(.everyMinute) { context in
            let screen = MyDayScreen(engine: engine, filter: filter, now: context.date, senders: model?.senders ?? Senders(), day: day)
            list(screen, now: context.date)
                // The bar and the filter follow the page on screen. With the Filter button gone (an
                // empty day at midnight, the last tag deleted) the tag filter goes too, but not when
                // the person moved day (#375): it keeps applying from day to day. Only a move
                // changes the day asked for; the clock doesn't.
                .onChange(of: FilterOffer(asked: askedDay, offers: screen.offersFilter, isSelected: isSelected), initial: true) { old, new in
                    guard new.isSelected else { return }
                    offersFilter = new.offers
                    filter.update(offersFilter: new.offers, afterMovingDay: old.asked != new.asked)
                }
                .onChange(of: isSelected ? screen.shown : nil, initial: true) { _, day in
                    if let day { shown = day }
                }
                .quietHoursHolding(model, at: context.date)
        }
    }

    private func list(_ screen: MyDayScreen, now: Date) -> some View {
        MyDayList(
            screen: screen,
            reach: engine?.reach,
            now: now,
            tapCount: { filter.tap($0) },
            removeToken: remove,
            openFilter: { isFiltering = true },
            openDetails: { path.append(OpenedReminder(id: $0)) },
            markDone: { model?.markDone($0) }
        )
        .environment(\.isScrollEnabled, true)
        .centeredInReadableColumn()
    }

    /// The day on screen: the one asked for, kept inside the range, or today.
    private func selectedDay(_ engine: Engine) -> CalendarDay {
        MyDayShownDay(engine: engine, asked: askedDay).day ?? engine.today
    }

    /// The page scrolled to: the day on screen. Moving the day moves it, animated as the move is.
    private func position(_ engine: Engine) -> Binding<CalendarDay?> {
        Binding {
            selectedDay(engine)
        } set: { day in
            if let day { askedDay = day == engine.today ? nil : day }
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

    /// The bar's subtitle in landscape: the day label, or today's date before the first read.
    private var dayLabel: Text {
        shown?.labelText ?? todayText(.now)
    }

    /// Previous Day and Next Day. Nothing moves past the range's ends.
    private func move(_ move: MyDayMove) {
        guard let shown, let target = move.target(from: shown) else { return }
        self.move(to: target)
    }

    /// Shows `day`, today if `nil`: the pages slide to it.
    private func move(to day: CalendarDay?) {
        withAnimation(reduceMotion ? nil : .default) {
            askedDay = day == engine?.today ? nil : day
        }
    }

    /// Says the new day to VoiceOver: the day and how many are due. VoiceOver's focus is left where
    /// iOS puts it (#276, #221).
    private func announceDay() {
        guard let engine else { return }
        let shown = MyDayShownDay(engine: engine, asked: askedDay)
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
    /// Only the page on screen speaks for the bar.
    var isSelected: Bool
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
    let tapCount: (MyDayCount) -> Void
    let removeToken: (MyDayScreen.FilterToken) -> Void
    let openFilter: () -> Void
    let openDetails: (Reminder.ID) -> Void
    let markDone: (Reminder.ID) -> Void

    @Environment(\.quietHoursHoldingDetail) private var holdingDetail
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        List {
            // A header only with a banner in it: with the date moved above the pages (#375), an
            // empty header was a VoiceOver stop with nothing to read (the phone, 2026-11-23).
            if hasBanner {
                Section {
                    controls
                } header: {
                    VStack(alignment: .leading, spacing: Design.Spacing.s3) {
                        if let reach {
                            PermissionBanners(reach: reach)
                        }
                        QuietHoursBannerView()
                    }
                }
            } else {
                Section {
                    controls
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

    /// A permission banner or the quiet hours banner shows.
    private var hasBanner: Bool {
        holdingDetail != nil || reach.map { !PermissionBanner.banners(for: $0).isEmpty } ?? false
    }

    /// The filter tokens, the counts, and "Showing only" while a count is chosen.
    @ViewBuilder private var controls: some View {
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
