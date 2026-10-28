import Foundation
import Testing
import UserNotifications
@testable import NudgeInator

/// Ticket 84's device check: whether a stamped badge applies for a calendar trigger as well as a
/// time-interval one (spec #80, criterion 6). Nudges use only time-interval triggers, so the
/// calendar request exists just for this run. The person locks the phone and reads the icon after
/// each fires: 5 after the interval one, then 3 after the calendar one. It removes its own
/// requests and deliveries even when it fails (AGENTS.md: tests on the iPhone leave it as they
/// found it). The badge can't be read back, so the person opens the app once afterwards.
@MainActor
@Suite(.enabled(if: DeviceCheck.isPhysicalDevice, "Needs the real notification center on an iPhone"))
final class BadgeTriggerDeviceCheck {
    /// Unique to this run, so the check finds and removes only what it added.
    let identifiers: [String] = {
        let run = UUID().uuidString
        return ["device-check.\(run).interval", "device-check.\(run).calendar"]
    }()

    deinit {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    @Test func intervalAndCalendarTriggersBothStampTheirBadge() async throws {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        try #require(status == .authorized || status == .provisional, "Allow notifications for Nudge-inator")

        let intervalDelay: TimeInterval = 60
        var fire = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: .now.addingTimeInterval(150))
        fire.second = 0
        let fireDate = try #require(Calendar.current.date(from: fire))

        try await center.add(request(identifiers[0], badge: 5, trigger: UNTimeIntervalNotificationTrigger(timeInterval: intervalDelay, repeats: false)))
        try await center.add(request(identifiers[1], badge: 3, trigger: UNCalendarNotificationTrigger(dateMatching: fire, repeats: false)))
        print("Device check: interval trigger (badge 5) at \(Date.now.addingTimeInterval(intervalDelay).formatted(date: .omitted, time: .standard)); calendar trigger (badge 3) at \(fireDate.formatted(date: .omitted, time: .standard))")

        let pending = Set(await center.pendingNotificationRequests().map(\.identifier)).intersection(identifiers)
        #expect(pending == Set(identifiers))

        // Both have fired, plus a minute to read the icon.
        try await Task.sleep(for: .seconds(fireDate.timeIntervalSinceNow + 60))
        let delivered = Set(await center.deliveredNotifications().map(\.request.identifier)).intersection(identifiers)
        print("Device check: delivered \(delivered.sorted())")
    }

    /// Spec #80, criterion 6: a Time Sensitive notification, stamped 7 so it can't be mistaken for
    /// the app's own count. The person locks the phone and reads the icon once it has fired.
    @Test func timeSensitiveNotificationStampsItsBadge() async throws {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        try #require(status == .authorized || status == .provisional, "Allow notifications for Nudge-inator")

        let content = UNMutableNotificationContent()
        content.title = "Nudge-inator device check"
        content.badge = 7
        content.interruptionLevel = .timeSensitive
        try await center.add(UNNotificationRequest(identifier: identifiers[0], content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)))
        print("Device check: Time Sensitive notification (badge 7) at \(Date.now.addingTimeInterval(60).formatted(date: .omitted, time: .standard))")

        try await Task.sleep(for: .seconds(150))
        let delivered = Set(await center.deliveredNotifications().map(\.request.identifier)).intersection(identifiers)
        print("Device check: delivered \(delivered.sorted())")
    }

    private func request(_ identifier: String, badge: Int, trigger: UNNotificationTrigger) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Nudge-inator device check"
        content.badge = NSNumber(value: badge)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
