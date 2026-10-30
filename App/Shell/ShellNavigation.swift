import Foundation
import NudgeEngine
import SwiftUI

/// A reminder's details pushed on a navigation stack. A type of its own, not the bare ID: a tag's
/// ID is a `UUID` too, so a stack that pushes both would have two destinations for one type.
struct OpenedReminder: Hashable {
    var id: Reminder.ID
}

/// A tag's screen pushed on the Tags tab. Like `OpenedReminder`, a type of its own, not the bare
/// ID.
struct OpenedTag: Hashable {
    var id: Tag.ID
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
    /// The reminder details pushed on Reminders. A route never sets it.
    var remindersPath: [OpenedReminder] = []

    /// What is pushed on Tags: a tag's screen, then a reminder's details from it. A route never
    /// sets it.
    var tagPath = NavigationPath()

    init(selection: AppTab = .now) {
        self.selection = selection
    }

    mutating func follow(_ route: AppModel.Route) {
        selection = AppTab(route: route)
        switch route {
        case .now: nowPath = []
        case .reminderDetails(let id): nowPath = [OpenedReminder(id: id)]
        }
    }
}
