import Foundation
import UserNotifications
import NudgeEngine

/// What the notification adapter reports to the app model, which owns the engine (ticket 21).
@MainActor
protocol NotificationAdapterEvents: AnyObject {
    /// The person chose Done on a nudge's notification.
    func markDone(_ reminderID: Reminder.ID)
    /// The center turned a request down. `notificationsNotAllowed` means the person turned
    /// notifications off, so the permissions are worth reading again.
    func schedulingFailed(_ error: any Error)
}

/// Applies the plan's notification items through the user notification center.
@MainActor
final class NotificationAdapter: @MainActor SchedulerAdapter {
    /// How many of the adapter's requests may be pending. Apple documents that the system keeps
    /// "the soonest-firing 64 notifications ... and discards the rest", but only on the deprecated
    /// `UILocalNotification` page, so a device check confirms it (ticket 18). The rest wait for the
    /// next apply; the app refills on foreground (ticket 21).
    static let pendingLimit = 64

    private let center: any UserNotificationCenter
    private let clock: any EngineClock
    /// The latest apply. The center's calls are async but `apply(_:)` isn't, so each apply runs in
    /// a task that waits for the one before, and plans reach the center in the order given.
    private var applying: Task<Void, Never>?
    weak var events: (any NotificationAdapterEvents)?
    /// Kept here because the center holds its delegate weakly.
    private let responder = NotificationResponder()

    init(center: any UserNotificationCenter, clock: any EngineClock) {
        self.center = center
        self.clock = clock
        // Empty options: .foreground would open the app and .authenticationRequired would need an
        // unlocked phone, and Done should run from the Lock Screen. One action, since the system
        // shows only two when space is short.
        let done = UNNotificationAction(identifier: Self.doneActionIdentifier, title: "Done", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryIdentifier, actions: [done], intentIdentifiers: []),
        ])
        responder.adapter = self
        center.setDelegate(responder)
    }

    static let categoryIdentifier = "nudge"
    static let doneActionIdentifier = "done"
    /// Where a request keeps its reminder's ID, so Done needn't parse the identifier.
    nonisolated private static let reminderIDKey = "reminderID"

    /// The reminder ID a request's `userInfo` carries. Nonisolated so the delegate can read it
    /// before hopping to the main actor: `userInfo` isn't `Sendable`, the string is.
    nonisolated static func reminderID(in userInfo: [AnyHashable: Any]) -> String? {
        userInfo[reminderIDKey] as? String
    }

    func apply(_ plan: SchedulePlan) {
        let previous = applying
        applying = Task {
            await previous?.value
            // One reading of the clock for the filter and the triggers: an interval trigger
            // raises an exception for an interval that isn't above zero.
            let now = clock.now
            let wanted = plan.items
                .filter { $0.deliveryKind != .alarm && $0.fireTime > now }
                .sorted { ($0.fireTime, $0.reminderID.uuidString) < ($1.fireTime, $1.reminderID.uuidString) }
                .prefix(Self.pendingLimit)
                .map { request(for: $0, now: now) }
            let wantedIdentifiers = Set(wanted.map(\.identifier))
            let pending = await center.pendingNotificationRequests().filter { Self.isNudge($0.identifier) }
            let stale = pending.map(\.identifier).filter { !wantedIdentifiers.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            // The identifier fixes the reminder and fire time, but a title Edit or a permission
            // change alters the content, and adding under the same identifier replaces it.
            let pendingByIdentifier = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
            // The rest are still tried, but one report per plan: a refusal such as
            // `notificationsNotAllowed` would otherwise come once for each of 64 requests.
            var firstError: (any Error)?
            for request in wanted where !Self.hasSameContent(request, pendingByIdentifier[request.identifier]) {
                do {
                    try await center.add(request)
                } catch {
                    firstError = firstError ?? error
                }
            }
            if let firstError {
                events?.schedulingFailed(firstError)
            }
        }
    }

    /// `states` with the notifications and Time Sensitive fields read from the center. Alarms are
    /// the alarm adapter's (ticket 19). Read at launch and on every foreground: the person can turn
    /// Time Sensitive off after the first one arrives.
    func permissions(updating states: PermissionStates) async -> PermissionStates {
        let settings = await center.notificationSettings()
        var states = states
        switch settings.authorizationStatus {
        case .denied:
            states.notifications = .denied
        // Not determined plans as allowed (see `NotificationPermission`). Provisional and
        // ephemeral both let the app schedule.
        case .notDetermined, .authorized, .provisional, .ephemeral:
            states.notifications = .allowed
        @unknown default:
            states.notifications = .allowed
        }
        switch (settings.authorizationStatus, settings.timeSensitiveSetting) {
        // Before the prompt the setting means nothing yet, so it reads as a fresh install's.
        case (.notDetermined, _), (_, .enabled):
            states.timeSensitive = .on
        default:
            states.timeSensitive = .off
        }
        return states
    }

    /// Shows the notification prompt, when onboarding asks (ticket 31). Returns whether the
    /// person allowed notifications.
    func requestAuthorization() async throws -> Bool {
        // Not .timeSensitive, which is deprecated: the entitlement and each request's
        // interruption level make a nudge Time Sensitive, so it isn't part of the prompt.
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    /// The person's response to a delivered notification, from the center's delegate.
    func handleResponse(actionIdentifier: String, reminderID text: String?) {
        guard actionIdentifier == Self.doneActionIdentifier,
              let text,
              let reminderID = UUID(uuidString: text)
        else { return }
        events?.markDone(reminderID)
    }

    /// Returns once every plan handed to `apply(_:)` so far has reached the center.
    func waitUntilApplied() async {
        await applying?.value
    }

    private func request(for item: SchedulePlan.Item, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.interruptionLevel = item.deliveryKind == .timeSensitiveNotification ? .timeSensitive : .active
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [Self.reminderIDKey: item.reminderID.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: item.fireTime.timeIntervalSince(now),
            repeats: false
        )
        return UNNotificationRequest(identifier: Self.identifier(for: item), content: content, trigger: trigger)
    }

    /// The fire time, not the nudge number, names the nudge: a plan can hold two ladders for one
    /// reminder (ticket 15). Milliseconds, so two nudges can't share an identifier.
    static func identifier(for item: SchedulePlan.Item) -> String {
        let milliseconds = Int64((item.fireTime.timeIntervalSince1970 * 1000).rounded())
        return "\(identifierPrefix)\(item.reminderID.uuidString).\(milliseconds)"
    }

    /// Marks the adapter's own requests, so a plan never removes one it didn't make, such as
    /// Settings' Send a Test Nudge (ticket 30).
    private static let identifierPrefix = "nudge."

    private static func hasSameContent(_ request: UNNotificationRequest, _ pending: UNNotificationRequest?) -> Bool {
        guard let pending else { return false }
        return request.content.title == pending.content.title
            && request.content.body == pending.content.body
            && request.content.interruptionLevel == pending.content.interruptionLevel
    }

    private static func isNudge(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }
}

/// The center's delegate. Apple: it must be set before the app finishes launching, and without
/// `didReceive` "your app never responds to custom actions". Not the adapter itself, because the
/// center may call it off the main actor.
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    weak var adapter: NotificationAdapter?

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let actionIdentifier = response.actionIdentifier
        let reminderID = NotificationAdapter.reminderID(in: response.notification.request.content.userInfo)
        await adapter?.handleResponse(actionIdentifier: actionIdentifier, reminderID: reminderID)
    }

    /// Without this, a nudge that fires while the app is open isn't shown at all.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
