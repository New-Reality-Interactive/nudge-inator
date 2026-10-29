import AlarmKit
import AppIntents
import CryptoKit
import Foundation
import NudgeEngine
import NudgeShared
import os
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
    /// The intent the alert's Open button runs for a nudge and its alarm's ID: ticket 20's. Without
    /// one there is no Open button, only the system Stop: a button with no intent would do nothing,
    /// and ticket 02 showed that Open without `stop(id:)` can leave a locked phone ringing.
    private let openIntent: (SchedulePlan.Item, Alarm.ID) -> (any LiveActivityIntent)?
    /// The intent the alert's Stop runs: ticket 87's, which only refreshes the badge. Without one,
    /// Stop is the system's alone. Either way it only silences the ring (ADR 0001).
    private let stopIntent: () -> (any LiveActivityIntent)?
    /// The latest apply. The manager's `schedule` is async but `apply(_:)` isn't, so each apply
    /// runs in a task that waits for the one before, and plans reach the manager in the order given.
    private var applying: Task<Void, Never>?
    /// The number of the latest plan handed to `apply(_:)`, so a waiting apply can tell it's been
    /// replaced.
    private var latestPlanNumber = 0

    weak var events: (any AlarmAdapterEvents)?

    /// AlarmKit's authorization, as the adapter last learned it: read before any prompt, taken
    /// from the prompt's answer and from AlarmKit's updates, and read again each time the app
    /// comes forward (`refreshAuthorization()`), since the updates didn't report a change made in
    /// Settings while the app was suspended (ticket 30's device check, iOS 27.0.1). Reading it
    /// around a prompt froze the iPhone (see `SystemAlarmManager.readAuthorizationState()`).
    /// `nil` until then, or if that read didn't answer in time.
    private var authorization: AlarmManager.AuthorizationState?
    /// How many times an update or the prompt's answer has set `authorization`, so a read that
    /// began before one can tell it is older and leave it alone.
    private var authorizationChanges = 0
    /// A read is under way, and may still be after its time limit: AlarmKit's call can't be
    /// cancelled and once didn't answer. No second read starts while one is.
    private var isReadingAuthorization = false
    /// The first read, which every caller waits for.
    private var authorizationRead: Task<AlarmManager.AuthorizationState?, Never>?
    /// How long launch waits for that read before going on without it.
    private let authorizationReadLimit: Duration

    init(
        manager: any AlarmManaging,
        clock: any EngineClock,
        openIntent: @escaping (SchedulePlan.Item, Alarm.ID) -> (any LiveActivityIntent)? = { _, _ in nil },
        stopIntent: @escaping () -> (any LiveActivityIntent)? = { nil },
        authorizationReadLimit: Duration = .seconds(2)
    ) {
        self.manager = manager
        self.clock = clock
        self.openIntent = openIntent
        self.stopIntent = stopIntent
        self.authorizationReadLimit = authorizationReadLimit
        let updates = manager.authorizationUpdates()
        // Weak, so the observation doesn't keep the adapter alive. The app keeps one adapter for
        // its whole life (ticket 21), so the task isn't cancelled.
        Task { [weak self] in
            for await state in updates {
                // Which path carries a change made in Settings: this or App opened's re-read
                // (ticket 32's device check).
                Self.logger.notice("AlarmKit's authorization update: \(String(describing: state), privacy: .public)")
                self?.authorization = state
                self?.authorizationChanges += 1
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
            switch await currentAuthorization() {
            case .denied:
                if !missing.isEmpty {
                    firstError = firstError ?? AlarmAdapterError.alarmsNotAllowed
                }
            // AlarmKit would prompt by itself on the first `schedule`, in the middle of a plan.
            // Onboarding asks instead (ticket 31), and its answer re-plans these alarms.
            case .notDetermined:
                break
            default:
                if let error = await schedule(missing, planNumber: planNumber) {
                    firstError = firstError ?? error
                }
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
            let intent = openIntent(item, id)
            do {
                try await manager.schedule(
                    id: id,
                    schedule: .fixed(item.fireTime),
                    attributes: Self.attributes(for: item, hasOpenButton: intent != nil),
                    stopIntent: stopIntent(),
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

    /// Cancels the alarms yet to ring of the reminder's occurrence due at `dueTime`, for a Done
    /// chosen while the store can't be read (ticket 32): an alarm's ID names its occurrence, so no
    /// plan is needed. As in a re-plan, an alarm that is ringing is left to the person's Stop or
    /// Open. After the plans handed over so far.
    func cancelNudges(of reminderID: Reminder.ID, dueAt dueTime: Date) async {
        let previous = applying
        let cancelling = Task {
            await previous?.value
            let occurrence = Self.occurrenceBytes(of: reminderID, dueAt: dueTime)
            do {
                for alarm in try manager.alarms() where alarm.state == .scheduled && Self.occurrenceBytes(in: alarm.id) == occurrence {
                    try manager.cancel(id: alarm.id)
                }
            } catch {
                Self.logger.error("An occurrence's alarms couldn't be cancelled: \(error, privacy: .public)")
            }
        }
        applying = cancelling
        await cancelling.value
    }

    /// Silences a ringing alarm. The Open button doesn't (ticket 02 B), so the Open intent calls
    /// this. A nudge is a one-shot, which AlarmKit then deletes.
    func stop(_ alarmID: Alarm.ID) throws {
        try manager.stop(id: alarmID)
    }

    /// `states` with the alarms field read from AlarmKit. Notifications and Time Sensitive are the
    /// notification adapter's, so ticket 21 chains the two:
    /// `await notifications.permissions(updating: alarms.permissions(updating: states))`.
    func permissions(updating states: PermissionStates) async -> PermissionStates {
        var states = states
        switch await currentAuthorization() {
        case .authorized:
            states.alarms = .allowed
        case .denied:
            states.alarms = .denied
        // The engine plans it as allowed (ticket 14), and onboarding asks before any alarm is
        // scheduled (ticket 31), or AlarmKit would prompt by itself mid-plan. A read that didn't
        // answer counts as not asked yet, until an update says otherwise.
        case .notDetermined, nil:
            states.alarms = .notDetermined
        @unknown default:
            states.alarms = .notDetermined
        }
        return states
    }

    /// Whether AlarmKit is known not to have asked yet. A read that didn't answer in time counts as
    /// not asked for the plan, but isn't known to be, so it doesn't bring onboarding back.
    func isKnownNotAskedYet() async -> Bool {
        await currentAuthorization() == .notDetermined
    }

    /// The state as last learned, or the one read's answer if nothing has been learned yet.
    private func currentAuthorization() async -> AlarmManager.AuthorizationState? {
        if let authorization { return authorization }
        let read = authorizationRead ?? Task { await readAuthorizationWithinLimit() }
        authorizationRead = read
        let answer = await read.value
        // An update or the prompt's answer may have come while the read waited; it is newer.
        if authorization == nil { authorization = answer }
        return authorization
    }

    /// The read, or `nil` if it doesn't answer within the limit, or if an earlier read is still
    /// outstanding, in which case none starts. The read's own task is left running: AlarmKit's call
    /// can't be cancelled.
    private func readAuthorizationWithinLimit() async -> AlarmManager.AuthorizationState? {
        guard !isReadingAuthorization else { return nil }
        isReadingAuthorization = true
        let manager = manager
        let limit = authorizationReadLimit
        return await withCheckedContinuation { continuation in
            let first = FirstAnswer(continuation)
            Task {
                let state = await manager.readAuthorizationState()
                isReadingAuthorization = false
                first.resume(with: state)
            }
            Task {
                try? await Task.sleep(for: limit)
                first.resume(with: nil)
            }
        }
    }

    /// Reads AlarmKit's state again, for App opened (ticket 30): a change made in Settings while the
    /// app was suspended came through no update on the iPhone (iOS 27.0.1), though a read off the
    /// main thread answered at once. The answer is kept unless an update or the prompt's answer
    /// came while it waited, which is newer, or it didn't answer in time.
    func refreshAuthorization() async {
        let changesBefore = authorizationChanges
        guard let answer = await readAuthorizationWithinLimit(), changesBefore == authorizationChanges else { return }
        Self.logger.notice("App opened's authorization re-read: \(String(describing: answer), privacy: .public), was \(String(describing: self.authorization), privacy: .public)")
        authorization = answer
    }

    /// Shows the AlarmKit prompt, when onboarding asks (ticket 31). Returns whether the person
    /// allowed alarms. Apple: it asks only "if it hasn't been requested before".
    /// The answer becomes the state, with no read after it: that read is what froze the iPhone.
    func requestAuthorization() async throws -> Bool {
        let answer = try await manager.requestAuthorization()
        authorization = answer
        authorizationChanges += 1
        return answer == .authorized
    }

    /// Returns once every plan handed to `apply(_:)` so far has reached the manager, including
    /// those handed over while waiting, such as the engine's answer to a limit report.
    func waitUntilApplied() async {
        while let task = applying {
            await task.value
            if applying == task { return }
        }
    }

    /// A UUID (RFC 9562 version 8, custom) built from two name hashes, so the same nudge always
    /// gets the same ID, even after a relaunch, and the diff needs no saved record. The first half
    /// names the occurrence, the reminder and its due time, so a Done chosen before the store can
    /// be read finds the occurrence's alarms by ID alone (ticket 32): AlarmKit lists only IDs,
    /// schedules and states. The second half names the nudge. The fire time, not the nudge number,
    /// does: a plan can hold two ladders for one reminder (ticket 15). The title is in it because
    /// AlarmKit can't say what an alarm shows: a title Edit gives a new ID, so the old alarm is
    /// cancelled and the new one scheduled.
    static func alarmID(for item: SchedulePlan.Item) -> Alarm.ID {
        let nudge = nameHash("nudge.\(milliseconds(of: item.fireTime)).\(item.title)")
        var bytes = occurrenceBytes(of: item.reminderID, dueAt: item.dueTime) + nudge
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // RFC 9562 variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// The first 8 bytes of the alarm IDs of the reminder's occurrence due at `dueTime`, version
    /// bits included. 60 bits of hash, so two occurrences sharing them is out of reach.
    private static func occurrenceBytes(of reminderID: Reminder.ID, dueAt dueTime: Date) -> [UInt8] {
        var bytes = nameHash("occurrence.\(reminderID.uuidString).\(milliseconds(of: dueTime))")
        bytes[6] = (bytes[6] & 0x0F) | 0x80  // version 8
        return bytes
    }

    private static func occurrenceBytes(in alarmID: Alarm.ID) -> [UInt8] {
        withUnsafeBytes(of: alarmID.uuid) { Array($0.prefix(8)) }
    }

    /// The first 8 bytes of the SHA-1 of the namespace and the name.
    private static func nameHash(_ name: String) -> [UInt8] {
        Array(Insecure.SHA1.hash(data: Data(alarmIDNamespace + Array(name.utf8))).prefix(8))
    }

    private static func milliseconds(of date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    /// The namespace for nudge alarm IDs, 3B0F6C2E-8D1A-4E57-9A64-2C7B5E9D1F80: a fixed random UUID,
    /// so no other hashed name clashes with them.
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

extension AlarmAdapter {
    static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "AlarmAdapter")
}

/// Resumes a continuation with whichever answer comes first, once.
@MainActor
private final class FirstAnswer<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resume(with value: Value) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
