import Foundation

/// The tab bar's four tabs, in the mockup's order.
enum AppTab: CaseIterable, Hashable {
    case now
    case myDay
    case tags
    case settings

    /// The tab a route opens on. Reminder details are pushed on Now, as the mockup's Open does.
    init(route: AppModel.Route) {
        switch route {
        case .now, .reminderDetails: self = .now
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .now: LocalizedStringResource("Now", comment: "Tab bar: the tab with what's nudging you now, coming up and closed lately")
        case .myDay: LocalizedStringResource("My Day", comment: "Tab bar: the tab with today's reminders in time order")
        case .tags: LocalizedStringResource("Tags", comment: "Tab bar: the tab listing your tags")
        case .settings: LocalizedStringResource("Settings", comment: "Tab bar: the app's settings tab")
        }
    }

    var systemImage: String {
        switch self {
        case .now: "bell"
        case .myDay: "calendar"
        case .tags: "tag"
        case .settings: "gearshape"
        }
    }
}
