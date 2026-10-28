import Foundation
import Testing
import UserNotifications
@testable import NudgeInator

enum DeviceCheck {
    /// Device checks need the real system, so the simulator runs in `scripts/test.sh` skip them.
    static var isPhysicalDevice: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }
}

/// Ticket 18's device check: how many requests the real center keeps pending, and which. Apple
/// gives 64 only on the deprecated `UILocalNotification` page ("the soonest-firing 64
/// notifications ... and discards the rest"). It touches only its own requests and removes them
/// even when it fails (AGENTS.md: tests on the iPhone leave it as they found it).
@MainActor
@Suite(.enabled(if: DeviceCheck.isPhysicalDevice, "Needs the real notification center on an iPhone"))
final class PendingLimitDeviceCheck {
    /// Unique to this run, so the check finds and removes only what it added.
    let identifiers: [String] = {
        let run = UUID().uuidString
        return (0..<70).map { "device-check.\(run).\($0)" }
    }()

    deinit {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    @Test func theCenterKeepsTheSoonestSixtyFourPendingRequests() async throws {
        let center = UNUserNotificationCenter.current()
        // Only on a run that says the app wasn't installed, which uninstalls it afterwards and so
        // resets the answer (AGENTS.md › Testing).
        if await center.notificationSettings().authorizationStatus == .notDetermined,
           ProcessInfo.processInfo.environment["NUDGE_FRESH_INSTALL"] == "1" {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        let status = await center.notificationSettings().authorizationStatus
        try #require(status == .authorized || status == .provisional, "Allow notifications for Nudge-inator, or set TEST_RUNNER_NUDGE_FRESH_INSTALL=1 on a fresh install")

        // A day out, so none is delivered during the check. Added latest first, so "soonest" and
        // "first added" can't be confused.
        var refusals = 0
        for (offset, identifier) in identifiers.enumerated().reversed() {
            let content = UNMutableNotificationContent()
            content.title = "Nudge-inator device check"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86_400 + TimeInterval(offset * 60), repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            } catch {
                refusals += 1
            }
        }
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier)).intersection(identifiers)
        print("Device check: \(pending.count) of \(identifiers.count) requests pending, \(refusals) refused")

        #expect(pending.count == NotificationAdapter.pendingLimit)
        #expect(pending == Set(identifiers.prefix(NotificationAdapter.pendingLimit)))

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        // Removal runs "asynchronously ... on a secondary thread", so wait for it before the
        // check ends.
        for _ in 0..<50 where !Set(await center.pendingNotificationRequests().map(\.identifier)).isDisjoint(with: identifiers) {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(Set(await center.pendingNotificationRequests().map(\.identifier)).isDisjoint(with: identifiers))
    }
}
