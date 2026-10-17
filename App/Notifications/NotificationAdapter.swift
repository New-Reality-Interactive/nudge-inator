import Foundation
import UserNotifications
import NudgeEngine

/// What the notification adapter reports to the app model, which owns the engine (ticket 21).
@MainActor
protocol NotificationAdapterEvents: AnyObject {
    /// The person chose Done on a nudge's notification. Send it on with
    /// `Engine.markDone(_:nudgeFiredAt:)`, which ignores a banner left from an earlier occurrence.
    /// Return only once it is saved and applied: the response handler waits for it, and Apple
    /// says its return tells the system "you are done processing the user's response", after
    /// which an app the action launched in the background can be suspended.
    func markDone(_ reminderID: Reminder.ID, nudgeFiredAt fireTime: Date) async
    /// The center turned a request down. `notificationsNotAllowed` means the person turned
    /// notifications off, so read `permissions(updating:)` again and hand them to the engine.
    func schedulingFailed(_ error: any Error)
}

/// The nudge a delivered notification was for, as its request's `userInfo` carries it.
struct DeliveredNudge: Equatable, Sendable {
    var reminderID: Reminder.ID
    var fireTime: Date
}

/// Applies the plan's notification items through the user notification center.
///
/// `@MainActor`, with a main-actor conformance to `SchedulerAdapter`, because the app model that
/// owns the engine is `@MainActor`: the engine holding this adapter stays on the main actor.
@MainActor
final class NotificationAdapter: @MainActor SchedulerAdapter {
    /// How many requests may be pending, the adapter's and any others. Apple documents that the
    /// system keeps "the soonest-firing 64 notifications ... and discards the rest", but only on
    /// the deprecated `UILocalNotification` page, so a device check confirms it (ticket 18). The
    /// rest wait for the next apply; the app refills on foreground (ticket 21).
    static let pendingLimit = 64
    static let categoryIdentifier = "nudge"
    static let doneActionIdentifier = "done"
    /// Marks the adapter's own requests, so a plan never removes one it didn't make, such as
    /// Settings' Send a Test Nudge (ticket 30).
    private static let identifierPrefix = "nudge."
    /// Where a request keeps its nudge, so Done needn't parse the identifier.
    nonisolated private static let reminderIDKey = "reminderID"
    /// Seconds since 2001, `Date`'s own value, so the fire time comes back exactly. Seconds since
    /// 1970 lose a fraction of a second on the way, and the engine then read the Done as one for
    /// an earlier occurrence and ignored it (ticket 21's device check).
    nonisolated private static let fireTimeKey = "fireTime"

    private let center: any UserNotificationCenter
    private let clock: any EngineClock
    /// The latest apply. The center's calls are async but `apply(_:)` isn't, so each apply runs in
    /// a task that waits for the one before, and plans reach the center in the order given.
    private var applying: Task<Void, Never>?
    /// Kept here because the center holds its delegate weakly.
    private var responder: NotificationResponder?
    /// Dones that came before anyone listened: the Done action can launch the app in the
    /// background, and the response may beat the app model's setup.
    private var unreportedDones: [DeliveredNudge] = []

    weak var events: (any NotificationAdapterEvents)? {
        didSet { Task { await reportDones() } }
    }

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
        let responder = NotificationResponder(adapter: self)
        self.responder = responder
        center.setDelegate(responder)
    }

    /// The nudge a request's `userInfo` carries. Nonisolated so the delegate can read it before
    /// hopping to the main actor: `userInfo` isn't `Sendable`, a `DeliveredNudge` is.
    nonisolated static func deliveredNudge(in userInfo: [AnyHashable: Any]) -> DeliveredNudge? {
        guard let text = userInfo[reminderIDKey] as? String,
              let reminderID = UUID(uuidString: text),
              let seconds = userInfo[fireTimeKey] as? TimeInterval
        else { return nil }
        return DeliveredNudge(reminderID: reminderID, fireTime: Date(timeIntervalSinceReferenceDate: seconds))
    }

    func apply(_ plan: SchedulePlan) {
        let previous = applying
        applying = Task {
            await previous?.value
            let allPending = await center.pendingNotificationRequests()
            let pending = allPending.filter { Self.isNudge($0.identifier) }
            // Others count toward the system's limit too, so they take places from the plan.
            let room = max(0, Self.pendingLimit - (allPending.count - pending.count))
            // One reading of the clock, after the wait above, for the filter and the triggers: an
            // interval trigger raises an exception for an interval that isn't above zero.
            let now = clock.now
            let wanted = plan.items
                .filter { $0.deliveryKind != .alarm && $0.fireTime > now }
                .sorted { ($0.fireTime, $0.reminderID.uuidString) < ($1.fireTime, $1.reminderID.uuidString) }
                .prefix(room)
                .map { request(for: $0, now: now) }
            let wantedIdentifiers = Set(wanted.map(\.identifier))
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

    /// The person's response to a delivered notification, from the center's delegate. Returns
    /// once `events` has handled a Done, or straight away if no one is listening yet, in which
    /// case the Done waits for `events` to be set.
    func handleResponse(actionIdentifier: String, nudge: DeliveredNudge?) async {
        guard actionIdentifier == Self.doneActionIdentifier, let nudge else { return }
        unreportedDones.append(nudge)
        await reportDones()
    }

    /// Returns once every plan handed to `apply(_:)` so far has reached the center.
    func waitUntilApplied() async {
        await applying?.value
    }

    private func reportDones() async {
        guard let events else { return }
        // Taken before the first wait, so a second call meanwhile doesn't report them again.
        let dones = unreportedDones
        unreportedDones.removeAll()
        for done in dones {
            await events.markDone(done.reminderID, nudgeFiredAt: done.fireTime)
        }
    }

    private func request(for item: SchedulePlan.Item, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.interruptionLevel = item.deliveryKind == .timeSensitiveNotification ? .timeSensitive : .active
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            Self.reminderIDKey: item.reminderID.uuidString,
            Self.fireTimeKey: item.fireTime.timeIntervalSinceReferenceDate,
        ]
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
/// center may call it off the main actor; `Sendable` since its one property is a `weak let` to a
/// main-actor class.
///
/// The completion-handler forms, each calling its handler from the main actor. With the async
/// forms the handler ran on whatever thread the method returned on, and on the iPhone a nudge
/// arriving with the app in front crashed it: "Call must be made on main thread", inside UIKit
/// (ticket 21's device check). Apple's docs don't say which thread the handler needs. The async
/// forms can't be made `@MainActor` instead: the center's arguments aren't `Sendable`.
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate, Sendable {
    weak let adapter: NotificationAdapter?

    init(adapter: NotificationAdapter) {
        self.adapter = adapter
    }

    /// The handler is called only once a Done is saved and applied: Apple says it tells the
    /// system "you are done", and the app may be suspended after it.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        // Read here: `userInfo` isn't `Sendable`, these are.
        let actionIdentifier = response.actionIdentifier
        let nudge = NotificationAdapter.deliveredNudge(in: response.notification.request.content.userInfo)
        Task { @MainActor [adapter] in
            await adapter?.handleResponse(actionIdentifier: actionIdentifier, nudge: nudge)
            completionHandler()
        }
    }

    /// Without this, a nudge that fires while the app is open isn't shown at all.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            completionHandler([.banner, .list, .sound])
        }
    }
}
