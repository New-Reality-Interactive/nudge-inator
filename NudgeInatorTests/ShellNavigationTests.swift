import Foundation
import Testing
@testable import NudgeInator

/// How the tab shell follows a route (the alarm's Open) and a tap: one selection and one path on
/// Now, so both ways in push the same details.
struct ShellNavigationTests {
    @Test func aReminderRoutePushesItsDetailsOnNow() {
        let id = UUID()
        var navigation = ShellNavigation(selection: .tags)

        navigation.follow(.reminderDetails(id))

        #expect(navigation.selection == .now)
        #expect(navigation.nowPath == [OpenedReminder(id: id)])
    }

    /// Now, with no reminder, is Now's list: whatever was pushed goes.
    @Test func aNowRouteShowsNowsListAgain() {
        var navigation = ShellNavigation(selection: .settings)
        navigation.nowPath = [OpenedReminder(id: UUID()), OpenedReminder(id: UUID())]

        navigation.follow(.now)

        #expect(navigation.selection == .now)
        #expect(navigation.nowPath.isEmpty)
    }
}
