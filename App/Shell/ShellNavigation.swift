import Foundation
import NudgeEngine
import SwiftUI

/// A reminder's details pushed on a navigation stack. A type of its own, not the bare ID: a tag's
/// ID is a `UUID` too, so a stack that pushes both would have two destinations for one type.
struct OpenedReminder: Hashable {
    var id: Reminder.ID
}

/// A sent reminder's details pushed on Reminders from the Sent view (ticket 201). A type of its own:
/// the sharing store keeps it, not the engine, so it has a screen of its own.
struct OpenedSentReminder: Hashable {
    var id: Reminder.ID
}

/// A tag's screen pushed on the Tags tab. Like `OpenedReminder`, a type of its own, not the bare
/// ID.
struct OpenedTag: Hashable {
    var id: Tag.ID
}

/// A sharing page pushed on Settings (ticket 196): Connections, then a connected person's page.
/// Values, so Change These on the "Connected" sheet can push them from outside Settings.
enum SharingPage: Hashable {
    case connections
    case connection(UUID)
}

/// Where the tab shell is: the selected tab, and the reminders pushed on Now, My Day and
/// Reminders. A route from outside the screens (the alarm's Open) and a tap on a card or row both
/// end up here, so they push the same details.
struct ShellNavigation {
    var selection: AppTab
    /// The reminder details pushed on Now, oldest first.
    var nowPath: [OpenedReminder] = []
    /// The reminder details pushed on My Day. A route never sets it: Open goes to Now.
    var dayPath: [OpenedReminder] = []
    /// What is pushed on Reminders: a reminder's details from Mine, or a sent reminder's from Sent.
    /// A route never sets it.
    var remindersPath = NavigationPath()

    /// What is pushed on Tags: a tag's screen, then a reminder's details from it. A route never
    /// sets it.
    var tagPath = NavigationPath()

    /// The sharing pages pushed on Settings. Change These and Sent's Manage People set it from outside.
    var settingsPath: [SharingPage] = []

    init(selection: AppTab = .now) {
        self.selection = selection
    }

    /// Change These on the "Connected" sheet: Settings, with the connection's page over
    /// Connections, so Back goes to the list.
    mutating func openConnection(_ connectionID: UUID) {
        selection = .settings
        settingsPath = [.connections, .connection(connectionID)]
    }

    /// Manage People on Sent's empty state (ticket 202): Settings, with Connections pushed, so Back
    /// goes to Settings.
    mutating func openConnections() {
        selection = .settings
        settingsPath = [.connections]
    }

    mutating func follow(_ route: AppModel.Route) {
        selection = AppTab(route: route)
        switch route {
        case .now: nowPath = []
        case .reminderDetails(let id): nowPath = [OpenedReminder(id: id)]
        }
    }
}
