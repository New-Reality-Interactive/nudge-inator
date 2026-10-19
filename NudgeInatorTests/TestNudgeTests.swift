import Foundation
import NudgeEngine
import Testing
import UserNotifications
@testable import NudgeInator

/// Settings' Send a Test Nudge and Delete All Data's clear-out (ticket 30), at the notification
/// adapter: one ordinary notification that is no reminder's, and a cancel of everything.
@MainActor
struct TestNudgeTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 19, 9))
    let center = FakeNotificationCenter()

    func adapter() -> NotificationAdapter {
        NotificationAdapter(center: center, clock: clock)
    }

    @Test func sendingATestNudgeSchedulesOneOrdinaryNotificationAFewSecondsAway() async throws {
        let adapter = adapter()

        await adapter.sendTestNudge()

        let request = try #require(center.pending.first)
        #expect(center.pending.count == 1)
        #expect(request.identifier == NotificationAdapter.testNudgeIdentifier)
        #expect(request.content.title == "Test nudge")
        #expect(request.content.body == "Nudges will look like this.")
        #expect(request.content.interruptionLevel == .active)
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 5)
        #expect(trigger.repeats == false)
    }

    @Test func aPlanAppliedAfterwardsLeavesTheTestNudgePending() async throws {
        let adapter = adapter()
        await adapter.sendTestNudge()

        adapter.apply(SchedulePlan(items: []))
        await adapter.waitUntilApplied()

        #expect(center.pending.map(\.identifier) == [NotificationAdapter.testNudgeIdentifier])
    }

    /// The system takes a notification out of Notification Center when its action is chosen. The
    /// test nudge offers Done, and its Done names no reminder, so it reaches the app model as
    /// nothing.
    @Test func theTestNudgeOffersDoneAndAChosenDoneReachesNoReminder() async throws {
        let adapter = adapter()
        let events = FakeNotificationEvents()
        adapter.events = events
        await adapter.sendTestNudge()
        let request = try #require(center.pending.first)
        // What the center's delegate would read from the delivered request: no nudge, so a chosen
        // Done has no reminder to close.
        #expect(NotificationAdapter.deliveredNudge(in: request.content.userInfo) == nil)

        await adapter.handleResponse(
            actionIdentifier: NotificationAdapter.doneActionIdentifier,
            nudge: NotificationAdapter.deliveredNudge(in: request.content.userInfo)
        )

        #expect(request.content.categoryIdentifier == NotificationAdapter.categoryIdentifier)
        #expect(events.dones.isEmpty)
    }

    @Test func aRefusedTestNudgeIsReportedLikeAnyRefusedRequest() async throws {
        let adapter = adapter()
        let events = FakeNotificationEvents()
        adapter.events = events
        center.addError = UNError(.notificationsNotAllowed)

        await adapter.sendTestNudge()

        #expect(events.schedulingErrors.count == 1)
        #expect(center.pending.isEmpty)
    }

    @Test func cancellingEverythingRemovesTheNudgesTheTestNudgeAndWhatWasDelivered() async throws {
        let adapter = adapter()
        adapter.apply(SchedulePlan(items: [
            SchedulePlan.Item(
                reminderID: UUID(), nudgeNumber: 1, nudgesInAll: 20,
                fireTime: NewYork.local(2026, 10, 19, 9, 30), urgency: .normal,
                title: "Take the pills", deliveryKind: .notification
            ),
        ]))
        await adapter.sendTestNudge()

        await adapter.cancelAll()

        #expect(center.pending.isEmpty)
        #expect(center.removedAllDeliveredCount == 1)
    }
}
