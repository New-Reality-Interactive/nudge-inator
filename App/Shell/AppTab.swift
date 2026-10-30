import Foundation

/// The tab bar's five tabs, in the mockup's order. Spec #104 adds no more: a sixth would put the
/// last ones under More.
enum AppTab: CaseIterable, Hashable {
    case now
    case myDay
    case reminders
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
        case .reminders: LocalizedStringResource("Reminders", comment: "Tab bar: the tab listing every reminder in any state")
        case .tags: LocalizedStringResource("Tags", comment: "Tab bar: the tab listing your tags")
        case .settings: LocalizedStringResource("Settings", comment: "Tab bar: the app's settings tab")
        }
    }

    var systemImage: String {
        switch self {
        case .now: "bell"
        case .myDay: "calendar"
        case .reminders: "list.bullet.clipboard"
        case .tags: "tag"
        case .settings: "gearshape"
        }
    }
}
