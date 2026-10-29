import Foundation
import NudgeEngine
import NudgeShared
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
    /// What the adapters last read, for Settings' status rows (ticket 30), which show not
    /// determined. The banners (ticket 31) read `engine.reach`.
    private(set) var permissions = PermissionStates()
    /// What onboarding still has to show (ticket 31), or `nil` once it's finished.
    private(set) var onboarding: Onboarding?
    /// A second Continue while the prompts are up does nothing.
    private(set) var isAskingForPermissions = false
    /// When onboarding's prompts were answered. The App opened their closing makes comes within a
    /// moment, and leaves AlarmKit's state alone; a later return reads it again.
    private var promptsAnsweredAt: Date?

    enum Onboarding: Equatable {
        /// First launch: the welcome, then both prompts.
        case welcome
        /// Onboarding was finished but alarms were never asked for, as with data restored from a
        /// backup: only the alarm prompt, so no plan's alarm is held back for good.
        case alarmsOnly
    }

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
    /// Opens the store at launch. A file that won't open is reported like one that can't be
    /// read, and App opened tries again.
    private let openStore: () throws -> ReminderStore
    /// The store, once it has opened.
    private var store: ReminderStore?
    private let notifications: NotificationAdapter
    private let alarms: AlarmAdapter
    private let scheduler: CombinedSchedulerAdapter
    private let timeZone: TimeZone
    private let giveUpLimit: GiveUpLimit
    private let onboardingRecord: OnboardingRecord
    private let defaultPaceRecord: DefaultPaceRecord
    /// Where a Done waits while the store can't be read (ticket 32).
    private let doneQueue: DoneQueue

    /// `giveUpLimit` is the shipped one; only tests pass another, to reach a take-over.
    init(
        clock: any EngineClock,
        openStore: @escaping () throws -> ReminderStore,
        notifications: NotificationAdapter,
        alarms: AlarmAdapter,
        onboardingRecord: OnboardingRecord = .standard,
        defaultPaceRecord: DefaultPaceRecord = .standard,
        doneQueue: DoneQueue,
        timeZone: TimeZone = .autoupdatingCurrent,
        giveUpLimit: GiveUpLimit = .shipped
    ) {
        self.clock = clock
        self.openStore = openStore
        self.notifications = notifications
        self.alarms = alarms
        self.timeZone = timeZone
        self.giveUpLimit = giveUpLimit
        self.onboardingRecord = onboardingRecord
        self.defaultPaceRecord = defaultPaceRecord
        self.doneQueue = doneQueue
        onboarding = onboardingRecord.isFinished ? nil : .welcome
        scheduler = CombinedSchedulerAdapter(adapters: [notifications, alarms])
        // Never handed an event before `launch()` replaces it, so it never applies a plan.
        engine = Engine(clock: clock, scheduler: scheduler, giveUpLimit: giveUpLimit, timeZone: timeZone)
        // Here rather than after launch, so no report is missed: each one waits for launch.
        notifications.events = self
        alarms.events = self
    }

    /// Launch, after setting aside a launch that couldn't read the store. Before the first unlock
    /// after a restart, data protection keeps the store shut, and a Done action can launch the
    /// app then. Only call it once the phone is unlocked: App opened, protected data becoming
    /// available, or an Open the person authenticated for.
    private func launchTryingAnUnreadStoreAgain() async {
        if case .storeUnreadable = launchState {
            launching = nil
            launchState = .launching
        }
        await launch()
    }

    private func makeEngine(permissions: PermissionStates) -> Engine {
        Engine(clock: clock, scheduler: scheduler, giveUpLimit: giveUpLimit, timeZone: timeZone, permissions: permissions)
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
            let store = try store ?? openStore()
            self.store = store
            stored = try store.load()
        } catch {
            Self.logger.error("The store couldn't be read: \(error, privacy: .public)")
            launchState = .storeUnreadable(error)
            return
        }
        // `UserDefaults` is shut before the first unlock too, so a launch then read onboarding as
        // not finished. It reads the record again now that the store has opened.
        if onboarding == .welcome, onboardingRecord.isFinished {
            onboarding = nil
        }
        let permissions = await currentPermissions()
        self.permissions = permissions
        if onboarding == nil, await alarms.isKnownNotAskedYet() {
            onboarding = .alarmsOnly
        }
        var engine = makeEngine(permissions: permissions)
        engine.update(tags: stored.tags)
        engine.update(histories: stored.histories)
        engine.update(reminders: stored.reminders)
        let queued = loadQueuedDones()
        for done in queued {
            engine.markDone(done.reminderID, occurrenceDueAt: done.dueTime, doneAt: done.doneAt)
        }
        self.engine = engine
        launchState = .ready
        // The file goes only once its Dones are saved; until then the next launch merges them
        // again, and the engine ignores a Done for an occurrence already closed.
        if !queued.isEmpty, save() {
            removeQueuedDones()
        }
    }

    /// The Dones chosen while the store couldn't be read, after making the queue's folder for the
    /// next restart. A file that won't decode is deleted: it never will, and the occurrences it
    /// named keep nudging, so the person can choose Done again. One that couldn't be read is kept
    /// for the next launch.
    private func loadQueuedDones() -> [QueuedDone] {
        do {
            try doneQueue.makeFolder()
        } catch {
            Self.logger.error("The queue's folder couldn't be made: \(error, privacy: .public)")
        }
        do {
            return try doneQueue.dones()
        } catch is DecodingError {
            Self.logger.error("The queued Dones were unreadable and are deleted")
            removeQueuedDones()
            return []
        } catch {
            Self.logger.error("The queued Dones couldn't be read: \(error, privacy: .public)")
            return []
        }
    }

    private func removeQueuedDones() {
        do {
            try doneQueue.removeAll()
        } catch {
            Self.logger.error("The queued Dones couldn't be deleted: \(error, privacy: .public)")
        }
    }

    /// The phone was unlocked for the first time since a restart, so the store can be read
    /// (ticket 32). It is opened, if it couldn't be before, and the Dones queued meanwhile merged.
    func protectedDataBecameAvailable() async {
        await launchTryingAnUnreadStoreAgain()
    }

    /// App opened (ticket 07): permissions read again, then a fresh plan, which also refills the
    /// notifications past the 64 the system keeps pending (ticket 18).
    func appOpened() async {
        await launchTryingAnUnreadStoreAgain()
        // AlarmKit sent no update for a change made in Settings while the app was suspended
        // (ticket 30's device check), so its state is read again, off the main thread. Not
        // around onboarding's prompts, which each make an App opened: there the answer is the
        // state, and a read right after the prompt froze the iPhone (ticket 22).
        if !isAskingForPermissions, !promptsJustAnswered {
            await alarms.refreshAuthorization()
        }
        refreshPermissions()
        await permissionsRefresh?.value
        replan()
    }

    /// The tab shell's minute tick, while the app is in front. An alarm coming due, or an
    /// occurrence closing as Missed, tells the app nothing, so the Icon badge catches up with the
    /// Now badge here: a re-plan, only when the count has changed.
    func minutePassed() {
        guard engine.badgeCount != notifications.plannedBadgeCount else { return }
        replan()
    }

    /// A fresh plan from what the engine holds, for when time has moved on with no event: it
    /// refills the notifications past the 64 the system keeps pending (ticket 18), and sets the
    /// Icon badge to the live count.
    private func replan() {
        perform { $0.update(reminders: $0.reminders) }
    }

    /// Onboarding's Continue: the notification prompt, then the alarm prompt whatever the person
    /// chose, then the new permissions reach the engine, whose re-plan schedules the alarms held
    /// back until now. A prompt already answered returns at once without showing. Onboarding is
    /// finished only once both have answered, so if the app is killed in between it shows again.
    func askForPermissions() async {
        guard let step = onboarding, !isAskingForPermissions else { return }
        isAskingForPermissions = true
        defer { isAskingForPermissions = false }
        if step == .welcome {
            do {
                _ = try await notifications.requestAuthorization()
            } catch {
                Self.logger.error("The notification prompt failed: \(error, privacy: .public)")
            }
        }
        do {
            _ = try await alarms.requestAuthorization()
        } catch {
            Self.logger.error("The alarm prompt failed: \(error, privacy: .public)")
        }
        onboardingRecord.isFinished = true
        onboarding = nil
        promptsAnsweredAt = clock.now
        refreshPermissions()
        await permissionsRefresh?.value
    }

    /// Within a moment of the prompts' answer, when the App opened a prompt's closing makes
    /// comes. Two seconds, by the model's clock.
    private var promptsJustAnswered: Bool {
        promptsAnsweredAt.map { clock.now.timeIntervalSince($0) < 2 } ?? false
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
    /// details. If the app no longer holds the reminder, the details say it isn't found, so the
    /// person isn't left on Now wondering where it went (ticket 27).
    func showReminder(_ reminderID: Reminder.ID) {
        route = .reminderDetails(reminderID)
    }

    /// The alarm's Open button, through ticket 20's intent. Ticket 02 B: Open doesn't silence the
    /// ring, and C: on a locked phone it opens the app once the person authenticates, so without
    /// a stop here the ring would go on with no alert left to stop it from. The stop comes first,
    /// before anything that waits. The route waits for the store to be read, when Open is what
    /// launched the app: set sooner, the details would say "Reminder Not Found" until it was.
    func open(alarmID: UUID, reminderID: Reminder.ID) async {
        do {
            try alarms.stop(alarmID)
        } catch {
            Self.logger.error("The alarm wouldn't stop: \(error, privacy: .public)")
        }
        await launchTryingAnUnreadStoreAgain()
        showReminder(reminderID)
    }

    /// What `OpenReminderIntent` calls, registered with `AppDependencyManager` at launch. The model
    /// lives as long as the app, so holding it here keeps nothing alive that wouldn't be.
    var alarmOpener: AlarmOpener {
        AlarmOpener { [self] alarmID, reminderID in
            await open(alarmID: alarmID, reminderID: reminderID)
        }
    }

    /// The alarm's Stop, through ticket 87's intent: the Icon badge set to the live count, since a
    /// Relentless reminder that came due while the app was suspended changed nothing on the icon
    /// (icon-badge spec, decision 6). Always a re-plan, unlike the minute tick: the icon may have
    /// drifted from the last plan while the app was suspended. Nothing else: Stop only silences
    /// the ring (ADR 0001), and a re-plan never cancels an alarm that is ringing. Not the unlock
    /// retry, since the phone may be locked; before the first unlock there is no count to set.
    /// Returns once the badge is set, for the intent to wait on.
    func refreshBadge() async {
        await launch()
        replan()
        await waitUntilApplied()
    }

    /// What `RefreshBadgeIntent` calls, registered with `AppDependencyManager` at launch, as
    /// `alarmOpener` is.
    var badgeRefresher: BadgeRefresher {
        BadgeRefresher { [self] in
            await refreshBadge()
        }
    }

    /// The route, which is then cleared: the tab shell follows each one once.
    func takeRoute() -> Route? {
        defer { route = nil }
        return route
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

    /// Settings' Default Pace (ticket 09), what a new reminder starts with. Read from the record
    /// each time, not kept from launch: before the first unlock `UserDefaults` reads as empty, so
    /// a launch then would see Consistent · 10 min whatever the person chose.
    var defaultPace: DefaultPace {
        get {
            access(keyPath: \.defaultPace)
            return defaultPaceRecord.defaultPace
        }
        set {
            withMutation(keyPath: \.defaultPace) { defaultPaceRecord.defaultPace = newValue }
        }
    }

    /// Settings' Send a Test Nudge (ticket 30): one ordinary notification a few seconds away. It is
    /// no reminder's, so the engine and the store know nothing of it.
    func sendTestNudge() async {
        await notifications.sendTestNudge()
    }

    /// Settings' Delete All Data (ticket 30): the store and the Default Pace, then the engine,
    /// then everything the adapters hold, including the test nudge and the nudges already in
    /// Notification Center. Not through `perform`: the store goes first and a store that turns the
    /// delete down stops it, so the reminders and their nudges stay as they were. A disk failure
    /// is likelier than a failed cancel, and a nudge left pending for deleted data is cancelled by
    /// the next App opened, which plans from nothing. An alarm that is ringing is left to ring, as
    /// a re-plan leaves it. Before the store has been read there is nothing to delete.
    func deleteAllData() async throws {
        guard case .ready = launchState, let store else { return }
        try store.deleteAllData()
        saveError = nil
        withMutation(keyPath: \.defaultPace) { defaultPaceRecord.clear() }
        // A new engine, not emptied lists: the old one keeps a key for every history it held, and
        // its alarm-limit records. Its empty plan still reaches the adapters.
        var empty = makeEngine(permissions: permissions)
        empty.update(reminders: [])
        engine = empty
        await waitUntilApplied()
        await notifications.cancelAll()
    }

    /// Returns once both adapters have applied every plan handed to them so far, including the
    /// plan a permission change started.
    func waitUntilApplied() async {
        await permissionsRefresh?.value
        await alarms.waitUntilApplied()
        await notifications.waitUntilApplied()
    }

    /// The latest re-read of the permissions, from App opened or an adapter's report.
    private var permissionsRefresh: Task<Void, Never>?

    /// Reads both adapters' permissions again and hands them to the engine, which re-plans if
    /// they changed. Each read waits for the one before, so reads that overlap can't finish out
    /// of order and put older states back. Each waits for launch too, so a change reported
    /// while the store is read isn't dropped.
    private func refreshPermissions() {
        let previous = permissionsRefresh
        permissionsRefresh = Task {
            await previous?.value
            await launch()
            let permissions = await currentPermissions()
            self.permissions = permissions
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
        guard case .ready = launchState, store != nil else { return }
        try event(&engine)
        save(storeChange: storeChange)
    }

    /// Saves what the engine holds, after the event's own store change, if any. Returns whether
    /// the store took it.
    @discardableResult
    private func save(storeChange: ((ReminderStore) throws -> Void)? = nil) -> Bool {
        guard let store else { return false }
        do {
            try storeChange?(store)
            try store.save(StoredData(reminders: engine.reminders, tags: engine.tags, histories: engine.histories))
            saveError = nil
            return true
        } catch {
            Self.logger.error("The store turned a save down: \(error, privacy: .public)")
            saveError = error
            return false
        }
    }
}

extension AppModel {
    static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "AppModel")
}

extension AppModel: NotificationAdapterEvents, AlarmAdapterEvents {
    /// Done from a notification: the same path as Done in the app, but it closes the occurrence
    /// only if the nudge was its own (ticket 18), not a banner left from an earlier one.
    /// It launches first if it has to (the action launches the app in the background), and
    /// returns once the Done is saved and applied, for the response handler to wait on.
    /// Before the first unlock the store can't be read, so the Done is queued instead (ticket 32).
    func markDone(_ nudge: DeliveredNudge) async {
        await launch()
        if case .storeUnreadable = launchState {
            await queueDone(nudge)
            return
        }
        let open = engine.openOccurrence(for: nudge.reminderID)
        perform { $0.markDone(nudge.reminderID, nudgeFiredAt: nudge.fireTime) }
        // A Done the engine ignores applies no plan, yet the icon may be stale from occurrences
        // that came due or Missed while the app was suspended. The app is awake, so it sets the
        // live count.
        if engine.openOccurrence(for: nudge.reminderID) == open {
            replan()
        }
        await waitUntilApplied()
    }

    /// Writes the Done to the queue, to be merged once the store opens, and stops its occurrence's
    /// nudges by their identifiers, since there are no reminders to plan from. A Done that can't
    /// be written leaves the nudges to come, so what's pending still matches the store.
    private func queueDone(_ nudge: DeliveredNudge) async {
        do {
            try doneQueue.add(QueuedDone(reminderID: nudge.reminderID, dueTime: nudge.dueTime, doneAt: clock.now))
        } catch {
            Self.logger.error("A Done couldn't be queued: \(error, privacy: .public)")
            return
        }
        await notifications.cancelNudges(of: nudge.reminderID, dueAt: nudge.dueTime)
        await alarms.cancelNudges(of: nudge.reminderID, dueAt: nudge.dueTime)
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

    /// A nudge arrived with the app in front: the plan built when its occurrence was still to come
    /// counted it out, so a fresh one sets the Icon badge to match the Now badge.
    func notificationPresented() {
        replan()
    }
}
