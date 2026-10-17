import SwiftUI

/// The tab shell: Now, My Day, Tags and Settings, in the system tab bar. It follows the model's
/// route (the alarm's Open) and shows each tab's content for the launch state. Without a model
/// (the app hosting tests, and previews) every tab shows its empty state.
struct RootView: View {
    @Environment(AppModel.self) private var model: AppModel?
    @State private var selection = AppTab.now

    var body: some View {
        let state = ScreenState(model: model)
        TabView(selection: $selection) {
            Tab(AppTab.now.title, systemImage: AppTab.now.systemImage, value: .now) {
                NowTab(state: state)
            }
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
        // `initial`, so a route set before the shell appeared (Open launching the app) is followed.
        .onChange(of: model?.route, initial: true) {
            guard let route = model?.takeRoute() else { return }
            selection = AppTab(route: route)
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
