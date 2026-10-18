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

    /// The alarm's Open for a reminder whose details are already on screen leaves one copy, not a
    /// second push on top.
    @Test func aRouteToTheReminderAlreadyOpenLeavesOneCopy() {
        let id = UUID()
        var navigation = ShellNavigation()
        navigation.nowPath = [OpenedReminder(id: id)]

        navigation.follow(.reminderDetails(id))

        #expect(navigation.nowPath == [OpenedReminder(id: id)])
    }

    /// An ID the engine doesn't hold still pushes, and the pushed screen says "not found": the
    /// route carries whatever ID it is given, `AppModel.showReminder`'s unknown IDs included.
    @Test func aRouteToAnyIDPushesItsDetailsScreen() {
        let id = UUID()
        var navigation = ShellNavigation()

        navigation.follow(.reminderDetails(id))

        #expect(navigation.nowPath == [OpenedReminder(id: id)])
    }
}
