import AlarmKit
import AppIntents
import CryptoKit
import Foundation
import NudgeEngine
import NudgeShared
import SwiftUI

/// What the alarm adapter reports to the app model, which owns the engine (ticket 21).
@MainActor
protocol AlarmAdapterEvents: AnyObject {
    /// AlarmKit turned the nudge's alarm down with `maximumLimitReached`. Send it on with
    /// `Engine.markAlarmLimitReached(_:firingAt:)`; the plan the engine hands back reaches this
    /// adapter through `apply(_:)` with that nudge as a notification (ticket 15).
    func markAlarmLimitReached(_ reminderID: Reminder.ID, firingAt fireTime: Date)
    /// AlarmKit turned an alarm down for another reason, or the plan holds alarms while alarms are
    /// denied. Read `permissions(updating:)` again and hand them to the engine.
    func schedulingFailed(_ error: any Error)
    /// The person changed the app's alarm permission, in Settings or at the prompt. Read
    /// `permissions(updating:)` again and hand them to the engine.
    func alarmAuthorizationChanged()
}

/// Why the adapter didn't schedule a plan's alarms.
enum AlarmAdapterError: Error, Equatable {
    /// AlarmKit's authorization is denied. Apple: "If a person using your app denies
    /// authorization, all attempts to schedule alarms fail."
    case alarmsNotAllowed
}

/// Applies the plan's alarm items through AlarmKit.
@MainActor
final class AlarmAdapter: @MainActor SchedulerAdapter {
    private let manager: any AlarmManaging
    private let clock: any EngineClock
    /// The intent the alert's Open button runs for a nudge: ticket 20's. Without one there is no
    /// Open button, only the system Stop: a button with no intent would do nothing, and ticket 02
    /// showed that Open without `stop(id:)` can leave a locked phone ringing.
    private let openIntent: (SchedulePlan.Item) -> (any LiveActivityIntent)?
    /// The latest apply. The manager's `schedule` is async but `apply(_:)` isn't, so each apply
    /// runs in a task that waits for the one before, and plans reach the manager in the order given.
    private var applying: Task<Void, Never>?
    /// The number of the latest plan handed to `apply(_:)`, so a waiting apply can tell it's been
    /// replaced.
    private var latestPlanNumber = 0

    weak var events: (any AlarmAdapterEvents)?

    init(
        manager: any AlarmManaging,
        clock: any EngineClock,
        openIntent: @escaping (SchedulePlan.Item) -> (any LiveActivityIntent)? = { _ in nil }
    ) {
        self.manager = manager
        self.clock = clock
        self.openIntent = openIntent
        let updates = manager.authorizationUpdates()
        // Weak, so the observation doesn't keep the adapter alive. The app keeps one adapter for
        // its whole life (ticket 21), so the task isn't cancelled.
        Task { [weak self] in
            for await _ in updates {
                self?.events?.alarmAuthorizationChanged()
            }
        }
    }

    func apply(_ plan: SchedulePlan) {
        let previous = applying
        latestPlanNumber += 1
        let planNumber = latestPlanNumber
        applying = Task {
            await previous?.value
            // A newer plan came while this one waited, so it would only redo work the newer one
            // undoes: each limit report re-plans, and without this the plans it supersedes would
            // try every overflowing alarm again (ticket 02's bulk-scheduling caution).
            guard planNumber == latestPlanNumber else { return }
            let alarms: [AlarmSnapshot]
            do {
                alarms = try manager.alarms()
            } catch {
                events?.schedulingFailed(error)
                return
            }
            let existing = Set(alarms.map(\.id))
            let now = clock.now
            let planned = plan.items.filter { $0.deliveryKind == .alarm }
            // The plan's passed nudges count as kept too: at its fire time an alarm can read
            // `scheduled` for a moment before it rings, and cancelling it then would lose it.
            let plannedIDs = Set(planned.map(Self.alarmID(for:)))
            // One report per plan: a refusal would otherwise come once for each alarm.
            var firstError: (any Error)?
            // Only alarms yet to ring: a re-plan must never silence one that is ringing. Stop and
            // Open end a ring, and a one-shot deletes itself once stopped.
            for alarm in alarms where alarm.state == .scheduled && !plannedIDs.contains(alarm.id) {
                do {
                    try manager.cancel(id: alarm.id)
                } catch {
                    firstError = firstError ?? error
                }
            }
            // Passed nudges were delivered (ticket 13). The same nudge twice is one alarm.
            var seen: Set<Alarm.ID> = []
            let missing = planned
                .filter { $0.fireTime > now }
                .sorted { ($0.fireTime, $0.reminderID.uuidString) < ($1.fireTime, $1.reminderID.uuidString) }
                .map { (item: $0, id: Self.alarmID(for: $0)) }
                .filter { seen.insert($0.id).inserted && !existing.contains($0.id) }
            if manager.authorizationState == .denied {
                if !missing.isEmpty {
                    firstError = firstError ?? AlarmAdapterError.alarmsNotAllowed
                }
            } else if let error = await schedule(missing, planNumber: planNumber) {
                firstError = firstError ?? error
            }
            if let firstError {
                events?.schedulingFailed(firstError)
            }
        }
    }

    /// Schedules soonest first, and returns the first error other than the alarm limit. Stops if a
    /// newer plan arrives meanwhile, such as the engine's answer to a limit report or a Done, so it
    /// doesn't schedule what that plan has dropped.
    private func schedule(_ alarms: [(item: SchedulePlan.Item, id: Alarm.ID)], planNumber: Int) async -> (any Error)? {
        var firstError: (any Error)?
        for (item, id) in alarms {
            guard planNumber == latestPlanNumber else { break }
            let intent = openIntent(item)
            do {
                try await manager.schedule(
                    id: id,
                    schedule: .fixed(item.fireTime),
                    attributes: Self.attributes(for: item, hasOpenButton: intent != nil),
                    secondaryIntent: intent
                )
            } catch AlarmManager.AlarmError.maximumLimitReached {
                // Each one: a slot can free up between alarms if another app's go.
                events?.markAlarmLimitReached(item.reminderID, firingAt: item.fireTime)
            } catch {
                firstError = firstError ?? error
            }
        }
        return firstError
    }

    /// `states` with the alarms field read from AlarmKit. Notifications and Time Sensitive are the
    /// notification adapter's, so ticket 21 chains the two:
    /// `await notifications.permissions(updating: alarms.permissions(updating: states))`.
    func permissions(updating states: PermissionStates) -> PermissionStates {
        var states = states
        switch manager.authorizationState {
        case .authorized:
            states.alarms = .allowed
        case .denied:
            states.alarms = .denied
        // The engine plans it as allowed (ticket 14), and onboarding asks before any alarm is
        // scheduled (ticket 31), or AlarmKit would prompt by itself mid-plan.
        case .notDetermined:
            states.alarms = .notDetermined
        @unknown default:
            states.alarms = .notDetermined
        }
        return states
    }

    /// Shows the AlarmKit prompt, when onboarding asks (ticket 31). Returns whether the person
    /// allowed alarms. Apple: it asks only "if it hasn't been requested before".
    func requestAuthorization() async throws -> Bool {
        try await manager.requestAuthorization() == .authorized
    }

    /// Returns once every plan handed to `apply(_:)` so far has reached the manager, including
    /// those handed over while waiting, such as the engine's answer to a limit report.
    func waitUntilApplied() async {
        while let task = applying {
            await task.value
            if applying == task { return }
        }
    }

    /// A name-based UUID (RFC 9562 version 5) of the reminder, the fire time and the title, so the
    /// same nudge always gets the same ID, even after a relaunch, and the diff needs no saved
    /// record. The fire time, not the nudge number, names the nudge: a plan can hold two ladders for
    /// one reminder (ticket 15). The title is in the name because AlarmKit can't say what an alarm
    /// shows: a title Edit gives a new ID, so the old alarm is cancelled and the new one scheduled.
    static func alarmID(for item: SchedulePlan.Item) -> Alarm.ID {
        let milliseconds = Int64((item.fireTime.timeIntervalSince1970 * 1000).rounded())
        let name = "nudge.\(item.reminderID.uuidString).\(milliseconds).\(item.title)"
        var bytes = Array(Insecure.SHA1.hash(data: Data(alarmIDNamespace + Array(name.utf8))).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50  // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // RFC 9562 variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// The namespace for nudge alarm IDs, 3B0F6C2E-8D1A-4E57-9A64-2C7B5E9D1F80: a fixed random UUID,
    /// so no other name-based UUID clashes with them.
    private static let alarmIDNamespace: [UInt8] = [
        0x3B, 0x0F, 0x6C, 0x2E, 0x8D, 0x1A, 0x4E, 0x57, 0x9A, 0x64, 0x2C, 0x7B, 0x5E, 0x9D, 0x1F, 0x80,
    ]

    /// DESIGN.md's `alarm-tint`: `accent-dark`, #07DDE6, the one colour pinned to a single variant. The
    /// alert draws it on the title and Open button whatever the appearance. It is the `AccentColor`
    /// set's dark, standard-contrast value, resolved here into a plain colour: the system draws the
    /// alert in its own process, and the docs don't say a named colour from the app's catalog
    /// resolves there. `ColorSetTests` guards the set, so the fallback never applies.
    static let alarmTint: Color = {
        let pinned = UITraitCollection {
            $0.userInterfaceStyle = .dark
            $0.accessibilityContrast = .normal
        }
        guard let accent = UIColor(named: "AccentColor", in: .main, compatibleWith: pinned) else { return .accentColor }
        return Color(uiColor: accent.resolvedColor(with: pinned))
    }()

    /// Unlocked, the alert shows only the symbol; locked, the full-width button shows the text too
    /// (ticket 02 E). Black is DESIGN.md's `on-accent-dark`, the text colour on the tint.
    private static let openButton = AlarmButton(text: LocalizedStringResource("Open", comment: "Alarm button: opens the app on the reminder, where Done is. Shown on the Lock Screen; keep it short."), textColor: .black, systemImageName: "arrow.up.forward.app")

    /// The title only (Privacy) and the system Stop button, which `Alert(title:secondaryButton:...)`
    /// supplies (iOS 26.1+). No countdown or paused presentation.
    private static func attributes(for item: SchedulePlan.Item, hasOpenButton: Bool) -> AlarmAttributes<NudgeAlarmMetadata> {
        // Interpolated, so the title is an argument and never looked up as a localization key. Its
        // own table, Untranslated.xcstrings, marks the "%@" it extracts as not to be translated,
        // which leaves "%@" in the main table free for strings that are.
        let title = LocalizedStringResource("\(item.title)", table: "Untranslated", comment: "The alarm's title: the reminder's own title, shown as the person wrote it. Not translated.")
        let alert = hasOpenButton
            ? AlarmPresentation.Alert(title: title, secondaryButton: openButton, secondaryButtonBehavior: .custom)
            : AlarmPresentation.Alert(title: title)
        return AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: NudgeAlarmMetadata(), tintColor: alarmTint)
    }
}
