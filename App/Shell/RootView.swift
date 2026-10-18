import SwiftUI

/// The tab shell: Now, My Day, Tags and Settings, in the system tab bar. It follows the model's
/// route (the alarm's Open) and shows each tab's content for the launch state. Without a model
/// (the app hosting tests, and previews) every tab shows its empty state.
struct RootView: View {
    @Environment(AppModel.self) private var model: AppModel?
    @State private var navigation = ShellNavigation()
    /// The start of the current minute, ticked by `tickEveryMinute()`. The badge counts what's
    /// nudging, which changes as time passes with no change to the engine, so reading this in
    /// `body` redraws the badge each minute, as Now's list is redrawn.
    @State private var minute = Date.now

    var body: some View {
        let state = ScreenState(model: model)
        // Not a TimelineView around the TabView: in the test host that held up main-actor work
        // until each minute's start.
        TabView(selection: $navigation.selection) {
            Tab(AppTab.now.title, systemImage: AppTab.now.systemImage, value: .now) {
                NowTab(state: state, path: $navigation.nowPath)
            }
            .badge(nowBadge(in: state, at: minute))
            Tab(AppTab.myDay.title, systemImage: AppTab.myDay.systemImage, value: .myDay) {
                MyDayTab(state: state)
            }
            Tab(AppTab.tags.title, systemImage: AppTab.tags.systemImage, value: .tags) {
                TagsTab(state: state)
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
                SettingsTab()
            }
        }
        // The mockup shrinks the tab bar while scrolling down (iOS 26). Ticket 23 records what it
        // does in portrait and landscape.
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { await tickEveryMinute() }
        // `initial`, so a route set before the shell appeared (Open launching the app) is followed.
        .onChange(of: model?.route, initial: true) {
            guard let route = model?.takeRoute() else { return }
            navigation.follow(route)
        }
    }

    /// How many reminders are nudging, once the store has been read. Zero hides the badge. The
    /// engine reads its own clock; `minute` is taken so the badge is redrawn when it ticks.
    private func nowBadge(in state: ScreenState, at minute: Date) -> Int {
        guard state == .ready, let model else { return 0 }
        return NowScreen.badgeCount(of: model.engine)
    }

    /// Sets `minute` at the start of each minute until the view goes away.
    private func tickEveryMinute() async {
        while (try? await EveryMinute.sleepUntilNext()) != nil {
            minute = .now
        }
    }
}

#Preview("Light") {
    RootView()
}

#Preview("Dark") {
    RootView()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    RootView()
        .environment(\.dynamicTypeSize, .accessibility5)
}
