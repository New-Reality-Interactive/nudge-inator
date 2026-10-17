import Foundation
import NudgeEngine
import Observation
import os

/// The composition root the screens bind to: it owns the engine, the store and both adapters.
/// Every event goes through it, and it saves what the engine holds after each one.
@MainActor
@Observable
final class AppModel {
    /// The screens read everything from the engine's read-outs. Only the model changes it.
    private(set) var engine: Engine
    private(set) var launchState = LaunchState.launching
    /// Why the latest save failed, or `nil` if it worked. Each save writes everything, so the
    /// next one that works makes up for it. The event itself stands: its plan has already
    /// reached the adapters.
    private(set) var saveError: (any Error)?

    enum LaunchState {
        case launching
        case ready
        /// The store couldn't be read (ticket 17's `StoreError.unreadable`, or the file wouldn't
        /// open). The model then leaves everything alone: a save would replace the file with
        /// nothing, and an empty plan would cancel the nudges already pending, which are better
        /// left to come. The screens say so (ticket 22).
        case storeUnreadable(any Error)
    }

    private let clock: any EngineClock
    /// What opening the store gave: the app delegate opens it, and a file that won't open is
    /// reported at launch like one that can't be read.
    private let store: Result<ReminderStore, any Error>
    private let notifications: NotificationAdapter
    private let alarms: AlarmAdapter
    private let scheduler: CombinedSchedulerAdapter
    private let timeZone: TimeZone

    init(
        clock: any EngineClock,
        store: Result<ReminderStore, any Error>,
        notifications: NotificationAdapter,
        alarms: AlarmAdapter,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.clock = clock
        self.store = store
        self.notifications = notifications
        self.alarms = alarms
        self.timeZone = timeZone
        scheduler = CombinedSchedulerAdapter(adapters: [notifications, alarms])
        // Never handed an event before `launch()` replaces it, so it never applies a plan.
        engine = Engine(clock: clock, scheduler: scheduler, timeZone: timeZone)
    }

    /// The one launch, which the app delegate starts and App opened waits for.
    private var launching: Task<Void, Never>?

    /// Reads the store and the permissions, then plans once (ticket 17's order). It runs once;
    /// later calls wait for that run.
    func launch() async {
        if launching == nil {
            launching = Task { await load() }
        }
        await launching?.value
    }

    /// The engine is built with the real permissions, so no throwaway plan reaches the adapters
    /// first.
    private func load() async {
        let stored: StoredData
        do {
            stored = try store.get().load()
        } catch {
            Self.logger.error("The store couldn't be read: \(error, privacy: .public)")
            launchState = .storeUnreadable(error)
            return
        }
        let permissions = await currentPermissions()
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: timeZone, permissions: permissions)
        engine.update(tags: stored.tags)
        engine.update(histories: stored.histories)
        engine.update(reminders: stored.reminders)
        self.engine = engine
        launchState = .ready
        // Last, so a Done the adapter held from a background launch reaches the loaded engine.
        alarms.events = self
        notifications.events = self
    }

    /// App opened (ticket 07): permissions read again, then a fresh plan, which also refills the
    /// notifications past the 64 the system keeps pending (ticket 18).
    func appOpened() async {
        await launch()
        let permissions = await currentPermissions()
        perform {
            $0.update(permissions: permissions)
            $0.update(reminders: $0.reminders)
        }
    }

    /// Where the app was asked to go from outside its screens. The tab shell (ticket 22) follows
    /// it, and sets it back to `nil` once it has.
    var route: Route?

    enum Route: Equatable {
        case now
        /// Reminder details (ticket 27), where its occurrence's Done is.
        case reminderDetails(Reminder.ID)
    }

    /// The alarm's Open button (ticket 20's intent, which also stops the ring): the reminder's
    /// details, or Now if the app no longer holds the reminder.
    func showReminder(_ reminderID: Reminder.ID) {
        route = engine.reminders.contains { $0.id == reminderID } ? .reminderDetails(reminderID) : .now
    }

    func add(_ reminder: Reminder) {
        perform { $0.update(reminders: $0.reminders + [reminder]) }
    }

    func markDone(_ reminderID: Reminder.ID) {
        perform { $0.markDone(reminderID) }
    }

    func edit(_ edited: Reminder) throws(EditError) {
        try perform { engine throws(EditError) in try engine.edit(edited) }
    }

    func pause(_ reminderID: Reminder.ID) {
        perform { $0.pause(reminderID) }
    }

    func resume(_ reminderID: Reminder.ID) throws(ResumeError) {
        try perform { engine throws(ResumeError) in try engine.resume(reminderID) }
    }

    /// The new tag, or `nil` if the store hasn't been read (see `launchState`).
    @discardableResult
    func createTag(named name: String) throws(TagNameError) -> Tag? {
        var tag: Tag?
        try perform { engine throws(TagNameError) in tag = try engine.createTag(named: name) }
        return tag
    }

    func renameTag(_ tagID: Tag.ID, to name: String) throws(TagNameError) {
        try perform { engine throws(TagNameError) in try engine.renameTag(tagID, to: name) }
    }

    /// The tag goes from the engine and the store; its reminders stay (ticket 16).
    func deleteTag(_ tagID: Tag.ID) {
        perform({ $0.deleteTag(tagID) }, storeChange: { try $0.deleteTag(tagID) })
    }

    /// The reminder and its whole history go, from the engine and the store (ticket 12).
    func delete(_ reminderID: Reminder.ID) {
        perform({ $0.delete(reminderID) }, storeChange: { try $0.delete(reminderID) })
    }

    /// Returns once both adapters have applied every plan handed to them so far, including the
    /// plan a permission change started.
    func waitUntilApplied() async {
        await permissionsRefresh?.value
        await alarms.waitUntilApplied()
        await notifications.waitUntilApplied()
    }

    /// The latest re-read of the permissions an adapter's report started.
    private var permissionsRefresh: Task<Void, Never>?

    /// Reads both adapters' permissions again and hands them to the engine, which re-plans if
    /// they changed. Each read waits for the one before, so the latest states win.
    private func refreshPermissions() {
        let previous = permissionsRefresh
        permissionsRefresh = Task {
            await previous?.value
            let permissions = await currentPermissions()
            perform { $0.update(permissions: permissions) }
        }
    }

    /// The two adapters between them set every field, so the states they start from don't matter.
    private func currentPermissions() async -> PermissionStates {
        await notifications.permissions(updating: alarms.permissions(updating: PermissionStates()))
    }

    /// Runs an event on the engine, then saves what it holds. Before launch has read the store,
    /// or when it couldn't, the event is dropped: there's nothing loaded for it to act on.
    /// `storeChange` is the store's own half of an event that has one (ticket 17), run before the save.
    /// An event the engine turns down throws its error, and nothing is saved.
    private func perform<Failure: Error>(
        _ event: (inout Engine) throws(Failure) -> Void,
        storeChange: ((ReminderStore) throws -> Void)? = nil
    ) throws(Failure) {
        guard case .ready = launchState else { return }
        try event(&engine)
        do {
            let store = try store.get()
            try storeChange?(store)
            try store.save(StoredData(reminders: engine.reminders, tags: engine.tags, histories: engine.histories))
            saveError = nil
        } catch {
            Self.logger.error("The store turned a save down: \(error, privacy: .public)")
            saveError = error
        }
    }
}

extension AppModel {
    static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "AppModel")
}

extension AppModel: NotificationAdapterEvents, AlarmAdapterEvents {
    /// Done from a notification: the same path as Done in the app, but it closes the occurrence
    /// only if the nudge was its own (ticket 18), not a banner left from an earlier one.
    func markDone(_ reminderID: Reminder.ID, nudgeFiredAt fireTime: Date) {
        perform { $0.markDone(reminderID, nudgeFiredAt: fireTime) }
    }

    /// The plan the engine hands back reaches both adapters, with that nudge as a notification.
    func markAlarmLimitReached(_ reminderID: Reminder.ID, firingAt fireTime: Date) {
        perform { $0.markAlarmLimitReached(reminderID, firingAt: fireTime) }
    }

    /// Both adapters report through this one: a refusal usually means a permission was taken
    /// away, which the app hears of no other way for notifications.
    func schedulingFailed(_ error: any Error) {
        refreshPermissions()
    }

    func alarmAuthorizationChanged() {
        refreshPermissions()
    }
}
