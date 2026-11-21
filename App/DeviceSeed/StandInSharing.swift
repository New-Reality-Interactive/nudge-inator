#if DEBUG
import Foundation
import NudgeEngine
import os
import SwiftUI

/// Sharing for the phone check of Connections (ticket 194), in place of the CloudKit adapter: a
/// launch with `NUDGE_SHARING_STANDIN=seeded` (a connection and two invites, one 3 days old),
/// `=sent` (those, and two reminders already delivered to Riley, ticket 207), `=names` (four connected
/// people, one a reminder sent to each, whose names show the locale's order, #335) or `=empty` gets a
/// stand-in adapter over an in-memory sharing store. `=off` (#389) is `empty` with Sharing off
/// until the person turns it on; each such launch first sets the Sharing switch off, so a launch with
/// `=off` is also the cleanup of a check that turned it on. A launch without the variable shares through
/// iCloud (#216). Nothing the stand-in holds outlives the launch, so a launch without the variable
/// is its cleanup. Debug builds only:
/// `scripts/check-release-has-no-seed.sh` checks Release builds hold none of it.
@MainActor
enum StandInSharing {
    static let variable = "NUDGE_SHARING_STANDIN"
    /// The latest stand-in adapter made, for the stand-in controls on Connections (ticket 195).
    /// The model holds it; this doesn't.
    private(set) static weak var current: StandInSharingAdapter?

    /// Whether this launch has Sharing off, with the stand-in standing by to be turned on (#389).
    static func launchesWithSharingOff(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment[variable] == "off"
    }

    /// The phone's Sharing switch record, set off first when `=off` asks for it, so such a launch
    /// starts with Sharing off whatever an earlier check left, and is also that check's cleanup.
    static func switchRecordResetIfOff(environment: [String: String] = ProcessInfo.processInfo.environment) -> SharingSwitchRecord {
        let record = SharingSwitchRecord.standard
        if launchesWithSharingOff(environment: environment) { record.reset() }
        return record
    }

    /// How Sharing Works' seen-flag (#424), set unseen first when `=off` asks for it, so such a
    /// launch opens the tutorial the first time Sharing is turned on, and is also that check's
    /// cleanup.
    static func tutorialRecordResetIfOff(environment: [String: String] = ProcessInfo.processInfo.environment) -> SharingTutorialRecord {
        let record = SharingTutorialRecord.standard
        if launchesWithSharingOff(environment: environment) { record.reset() }
        return record
    }

    static func modelIfAsked(clock: any EngineClock, environment: [String: String] = ProcessInfo.processInfo.environment) -> SharingModel? {
        var seed: SharingData
        switch environment[variable] {
        case "seeded": seed = seeded(now: clock.now)
        case "sent":
            seed = seeded(now: clock.now)
            let (reminders, copies) = sentToRiley(now: clock.now)
            seed.sentReminders = reminders
            seed.sentCopies = copies
        case "names": seed = namesSeeded(now: clock.now)
        case "empty", "off": seed = SharingData()
        case .none: return nil
        case .some(let other):
            logger.error("No stand-in sharing called \(other, privacy: .public): use seeded, sent, names, empty or off")
            return nil
        }
        var opened: SharingStore?
        let adapter = StandInSharingAdapter()
        for copy in seed.sentCopies {
            adapter.knowDelivered(copy.reminderID, through: copy.connectionID)
        }
        current = adapter
        return SharingModel(adapter: adapter, clock: clock) {
            if let opened { return opened }
            let store = try SharingStore(location: .inMemory)
            try store.save(seed)
            opened = store
            return store
        }
    }

    /// A model for previews: the mockup's people, or with `seeded` false, no one.
    static func previewModel(seeded: Bool = true) -> SharingModel {
        let clock = SystemClock()
        // Launched by `refreshAccountState`, which reads the store, as the app model's launch does.
        let model = modelIfAsked(clock: clock, environment: [variable: seeded ? "seeded" : "empty"])!
        model.refreshAccountState()
        return model
    }

    /// The mockup's people: Riley connected (at riley.park@icloud.com), Jordan invited today and
    /// Priya 3 days ago.
    private static func seeded(now: Date) -> SharingData {
        SharingData(connections: [
            // With an address, so a check can invite it under another name and see "Already Connected".
            // The connection `NUDGE_SEED=received`'s reminders came through (ticket 197).
            SharingConnection(id: SeedSet.standInConnectionID, name: "Riley Park", state: .connected, address: "riley.park@icloud.com", connectedAt: now.addingTimeInterval(-44 * 24 * 60 * 60)),
            SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited, address: "jordan.lee@icloud.com", invitedAt: now.addingTimeInterval(-20 * 60)),
            SharingConnection(id: UUID(), name: "Priya Shah", state: .invited, address: "+1 (555) 010-4477", invitedAt: now.addingTimeInterval(-3 * 24 * 60 * 60)),
        ], activity: activity(now: now))
    }

    /// Four connected people for the check of Sent's name order (#335), each sent one reminder: Zoe
    /// Adams, Riley Park, Ana Ortiz and Émile Roy. In English Émile sits between Ana and Riley; by
    /// code point it would come last.
    private static func namesSeeded(now: Date) -> SharingData {
        let people = ["Zoe Adams", "Riley Park", "Ana Ortiz", "Émile Roy"]
        var data = SharingData(connections: people.map {
            SharingConnection(id: UUID(), name: $0, state: .connected, address: nil, connectedAt: now.addingTimeInterval(-10 * 24 * 60 * 60))
        })
        for (index, connection) in data.connections.enumerated() {
            let reminder = Reminder(title: "Note for \(connection.name)", dueTime: now.addingTimeInterval(Double(index + 1) * 24 * 60 * 60), strength: .gentle)
            data.sentReminders.append(SentReminder(reminder: reminder, revision: 0))
            data.sentCopies.append(SentCopy(connectionID: connection.id, reminderID: reminder.id, createdAt: now.addingTimeInterval(Double(index - 5) * 60), receipt: .started, statusRecord: nil))
        }
        return data
    }

    /// The Share Activity record for the phone check of its page (#397), oldest first: an entry of
    /// each event and each refused change, from a change of Apple Account 30 days ago, naming three people, to a refused
    /// send 20 minutes ago.
    private static func activity(now: Date) -> [ShareActivityEntry] {
        let day: TimeInterval = 24 * 60 * 60
        return [
            ShareActivityEntry(at: now.addingTimeInterval(-30 * day), connectionNames: ["Chris Nolan", "Pat Rivera", "Dana Kim"], event: .accountChanged),
            ShareActivityEntry(at: now.addingTimeInterval(-14 * day), connectionNames: ["Alex Morgan"], event: .otherPersonLeft),
            ShareActivityEntry(at: now.addingTimeInterval(-7 * day), connectionNames: ["Robin Vega"], event: .connectionLost),
            ShareActivityEntry(at: now.addingTimeInterval(-4 * day), connectionNames: ["Riley Park"], event: .changeGivenUp(.revise)),
            ShareActivityEntry(at: now.addingTimeInterval(-3 * day), connectionNames: ["Alex Morgan"], event: .changeGivenUp(.disconnect)),
            ShareActivityEntry(at: now.addingTimeInterval(-2 * day), connectionNames: ["Riley Park"], event: .changeGivenUp(.settings)),
            ShareActivityEntry(at: now.addingTimeInterval(-day - 3 * 60 * 60), connectionNames: ["Alex Morgan"], event: .changeGivenUp(.cancel)),
            ShareActivityEntry(at: now.addingTimeInterval(-day), connectionNames: ["Riley Park"], event: .changeGivenUp(.status)),
            ShareActivityEntry(at: now.addingTimeInterval(-20 * 60), connectionNames: ["Riley Park"], event: .changeGivenUp(.send)),
        ]
    }

    /// Two reminders Riley already has, started (ticket 207): "Take the pills" every day at 9:00
    /// since 8 days ago, and "Call the clinic" once, tomorrow at 10:00. The sender's app doesn't
    /// nudge them, so nothing rings.
    private static func sentToRiley(now: Date) -> ([SentReminder], [SentCopy]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let pillsStart = calendar.date(byAdding: DateComponents(day: -8, hour: 9), to: today) ?? now
        let callDue = calendar.date(byAdding: DateComponents(day: 1, hour: 10), to: today) ?? now
        let pills = Reminder(title: "Take the pills", dueTime: pillsStart, repeatRule: .everyDay, strength: .firm)
        let call = Reminder(title: "Call the clinic", dueTime: callDue, strength: .gentle)
        let copies = [pills, call].enumerated().map { index, reminder in
            SentCopy(connectionID: SeedSet.standInConnectionID, reminderID: reminder.id, createdAt: now.addingTimeInterval(Double(index - 2) * 60), receipt: .started, statusRecord: nil)
        }
        return ([SentReminder(reminder: pills, revision: 0), SentReminder(reminder: call, revision: 0)], copies)
    }

    fileprivate static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "StandInSharing")
}

extension View {
    /// A Stand-in menu in Settings' toolbar for the phone check of opening an invite while Sharing is
    /// off (#389), only under `NUDGE_SHARING_STANDIN=off`: it hands the app an invite as the system
    /// does, wherever the switch is.
    func standInInviteWhileSharingOff(model: AppModel?) -> some View {
        toolbar {
            if StandInSharing.launchesWithSharingOff(), let model {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            model.receiveInvite(from: "Sam Rivera") { StandInSharing.current?.receiveInvite(from: "Sam Rivera") }
                        } label: {
                            Text(verbatim: "Open an Invite from Sam Rivera")
                        }
                    } label: {
                        Label { Text(verbatim: "Stand-in") } icon: { Image(systemName: "hammer") }
                    }
                }
            }
        }
    }

    /// A Stand-in menu in the toolbar for the phone check (ticket 195), only under the stand-in:
    /// receiving an invite, one that's unavailable, with `invited`, that person accepting, and with
    /// `connected`, that person changing their Status sharing or Delivery mode (ticket 196), going
    /// Quiet or syncing again (#436), sending a reminder (ticket 198), getting what was sent to them
    /// (ticket 201), accepting what waits for them (ticket 203), reporting how what you sent is
    /// going (ticket 206), changing what they sent (ticket 204), deleting it (ticket 205) or
    /// disconnecting (ticket 197). Without either, on Connections, it also chooses the iCloud account
    /// the stand-in reports (ticket 210), and whether it says the iPhone is online (ticket 211).
    func standInSharingControls(invited: SharingConnection? = nil, connected: SharingConnection? = nil) -> some View {
        toolbar {
            if let adapter = StandInSharing.current {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let invited {
                            Button { adapter.acceptedByThem(invited.id) } label: { Text(verbatim: "\(invited.name) Accepts") }
                        } else if let connected {
                            let theirs = connected.theirs
                            Button {
                                Task { await adapter.theyChoose(ConnectionChoices(sharesStatus: !theirs.sharesStatus, deliveryMode: theirs.deliveryMode), for: connected) }
                            } label: {
                                Text(verbatim: "\(connected.name) Turns Status Sharing \(theirs.sharesStatus ? "Off" : "On")")
                            }
                            Button {
                                let other: DeliveryMode = theirs.deliveryMode == .askMeFirst ? .startRightAway : .askMeFirst
                                Task { await adapter.theyChoose(ConnectionChoices(sharesStatus: theirs.sharesStatus, deliveryMode: other), for: connected) }
                            } label: {
                                Text(verbatim: "\(connected.name) Chooses \(theirs.deliveryMode == .askMeFirst ? "Start right away" : "Ask me first")")
                            }
                            Button { Task { await adapter.theyGoQuiet(connected) } } label: { Text(verbatim: "\(connected.name) Goes Quiet") }
                            Button { Task { await adapter.theySync(connected) } } label: { Text(verbatim: "\(connected.name) Syncs Again") }
                            Button { adapter.theySend(.gentle, through: connected.id) } label: { Text(verbatim: "\(connected.name) Sends a Gentle Reminder") }
                            Button { adapter.theySend(.relentless, through: connected.id) } label: { Text(verbatim: "\(connected.name) Sends a Relentless Reminder") }
                            Button { adapter.theySendAChange(through: connected.id) } label: { Text(verbatim: "\(connected.name) Sends a Change") }
                            Button { adapter.theyCancel(through: connected.id) } label: { Text(verbatim: "\(connected.name) Cancels") }
                            Button {
                                adapter.theyGetWhatWasSent(through: connected.id, askingFirst: theirs.deliveryMode == .askMeFirst)
                            } label: {
                                Text(verbatim: "\(connected.name) Gets What You Sent")
                            }
                            Button { adapter.theyAcceptWhatWaits(through: connected.id) } label: { Text(verbatim: "\(connected.name) Accepts What You Sent") }
                            Menu {
                                Button { adapter.theyReport(.comingUp, through: connected.id) } label: { Text(verbatim: "Coming up") }
                                Button { adapter.theyReport(.nudging, through: connected.id) } label: { Text(verbatim: "Nudging") }
                                Button { adapter.theyReport(.paused, through: connected.id) } label: { Text(verbatim: "Paused") }
                                Button { adapter.theyReport(.done, through: connected.id) } label: { Text(verbatim: "Done") }
                                Button { adapter.theyReport(.missed, through: connected.id) } label: { Text(verbatim: "Missed") }
                                Button { adapter.theyReport(.skipped, through: connected.id) } label: { Text(verbatim: "Skipped") }
                                Button { adapter.theyReport(.removed, through: connected.id) } label: { Text(verbatim: "Removed") }
                                Button { adapter.theyReport(nil, through: connected.id) } label: { Text(verbatim: "Not sharing this one") }
                                Button { adapter.theyReportAWeek(today: .nudging, through: connected.id) } label: { Text(verbatim: "Nudging, with a Week of History") }
                                Button { adapter.theyReportAWeek(today: .comingUp, through: connected.id) } label: { Text(verbatim: "Coming up, with a Week of History") }
                            } label: {
                                Text(verbatim: "\(connected.name) Reports…")
                            }
                            Button { adapter.theyDisconnect(connected.id) } label: { Text(verbatim: "\(connected.name) Disconnects") }
                        } else {
                            Button { adapter.receiveInvite(from: "Sam Rivera") } label: { Text(verbatim: "Receive an Invite from Sam Rivera") }
                            Button { adapter.receiveInvite(from: "Casey Nguyen", unavailable: true) } label: { Text(verbatim: "Receive an Unavailable Invite") }
                            Picker(selection: Binding { adapter.account } set: { adapter.account = $0 }) {
                                Text(verbatim: "Available").tag(SharingAccountState.available)
                                Text(verbatim: "No iCloud Account").tag(SharingAccountState.noAccount)
                                Text(verbatim: "Restricted").tag(SharingAccountState.restricted)
                                Text(verbatim: "Temporarily Unavailable").tag(SharingAccountState.temporarilyUnavailable)
                            } label: {
                                Text(verbatim: "iCloud")
                            }
                            .pickerStyle(.menu)
                            Button { adapter.anotherAccountSignsIn() } label: { Text(verbatim: "Another Apple Account Signs In") }
                            Picker(selection: Binding { adapter.isOnline } set: { adapter.isOnline = $0 }) {
                                Text(verbatim: "Online").tag(true)
                                Text(verbatim: "Offline").tag(false)
                            } label: {
                                Text(verbatim: "Network")
                            }
                            .pickerStyle(.menu)
                        }
                    } label: {
                        Label { Text(verbatim: "Stand-in") } icon: { Image(systemName: "hammer") }
                    }
                }
            }
        }
    }
}

/// Stands in for the CloudKit adapter: the sharing sheet is an alert asking for a name and an
/// address, as the mockup's stand-in sheet does, and nothing goes anywhere. Its strings are English
/// only, on purpose: it never ships.
@MainActor
final class StandInSharingAdapter: SharingAdapter {
    weak var events: (any SharingAdapterEvents)?

    /// Nothing to start: the stand-in never asks iCloud.
    func start() {}

    func stop() {}

    /// The stand-in sends nothing.
    func heartbeat(for choices: [UUID: ConnectionChoices], at now: Date) {}

    /// The stand-in sends nothing, so nothing waits.
    var hasUnsentDisconnects: Bool { false }

    /// The stand-in makes no share, so none is left over.
    var holdsLeftoverInvite: Bool { false }

    func submit(_ change: SharingChange) {
        StandInSharing.logger.notice("Stand-in: not sending a \(String(describing: change.kind), privacy: .public) change")
        if change.kind == .send, let reminderID = change.reminderID {
            undelivered.append((reminderID, change.connectionID))
            sentThrough[change.connectionID, default: []].append(reminderID)
        }
        if isOnline {
            reportSent([change.entry.id])
        } else {
            unsent.append(change.entry.id)
        }
    }

    /// Whether the stand-in says the iPhone can reach iCloud (ticket 211), chosen from the Stand-in
    /// menu on Connections. Offline, what the app submits waits as Waiting to sync; back online, it
    /// is reported sent, as through iCloud. A change tells the app model, as the real adapter will.
    var isOnline = true {
        didSet {
            guard isOnline != oldValue else { return }
            events?.connectivityChanged()
            guard isOnline else { return }
            let held = unsent
            unsent = []
            reportSent(held)
        }
    }

    /// What was submitted offline, waiting to be reported sent.
    private var unsent: [OutboxChange.ID] = []

    private func reportSent(_ changeIDs: [OutboxChange.ID]) {
        Task {
            for changeID in changeIDs {
                do {
                    try await events?.sent(changeID)
                } catch {
                    StandInSharing.logger.error("Stand-in: a change sent couldn't be kept: \(error, privacy: .public)")
                }
            }
        }
    }

    /// Every reminder sent through each connection, which `theyReport` reports on (ticket 206).
    private var sentThrough: [UUID: [Reminder.ID]] = [:]

    /// A reminder the launch's store already holds as delivered through the connection with
    /// `connectionID` (`NUDGE_SHARING_STANDIN=sent`), so `theyReport` reports on it too.
    func knowDelivered(_ reminderID: Reminder.ID, through connectionID: UUID) {
        sentThrough[connectionID, default: []].append(reminderID)
    }

    /// Stands in for the other person's app reporting how each copy sent through the connection with
    /// `connectionID` is going (ticket 206): `status` arrives as through iCloud for each, or with
    /// `nil` the flag that they keep this one from the sender ("Not sharing this one"). Nothing
    /// arrives for a copy not yet delivered: the status comes with the receipt.
    func theyReport(_ status: ReportedStatus?, through connectionID: UUID) {
        send(status.map { SentCopy.StatusRecord(report: StatusReport(label: $0, occurrences: []), notSharingThisOne: false) } ?? .heldBack, through: connectionID)
    }

    /// Stands in for the other person's app reporting each copy as `today`, with a history for the 7
    /// days before today and today (ticket 207): Done, Done, Missed, nothing due (as a weekly
    /// repeat's off day), Done, Skipped, Done, and `today`, each at this hour. A one-off's row shows
    /// none of it.
    func theyReportAWeek(today: ReportedStatus, through connectionID: UUID) {
        let calendar = Calendar.current
        let now = Date.now
        let labels: [ReportedStatus?] = [.done, .done, .missed, nil, .done, .skipped, .done, today]
        let occurrences = labels.enumerated().compactMap { index, label -> StatusReport.OccurrenceStatus? in
            guard let label, let dueTime = calendar.date(byAdding: .day, value: index - 7, to: now) else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: dueTime)
            guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
            return StatusReport.OccurrenceStatus(dueTime: dueTime, day: CalendarDay(year: year, month: month, day: day), label: label)
        }
        send(SentCopy.StatusRecord(report: StatusReport(label: today, occurrences: occurrences), notSharingThisOne: false), through: connectionID)
    }

    /// Sends `record` as through iCloud for each copy delivered through the connection with
    /// `connectionID`.
    private func send(_ record: SentCopy.StatusRecord, through connectionID: UUID) {
        let delivered = (sentThrough[connectionID] ?? []).filter { reminderID in !undelivered.contains { $0.reminderID == reminderID && $0.connectionID == connectionID } }
        Task {
            for reminderID in delivered {
                try? await events?.received(.status(record, for: reminderID, from: connectionID))
            }
        }
    }

    /// The reminders sent through each connection that `theyGetWhatWasSent(through:)` hasn't
    /// delivered yet.
    private var undelivered: [(reminderID: Reminder.ID, connectionID: UUID)] = []

    /// The reminder the stand-in last sent through each connection, which `theySendAChange` changes.
    private var lastSent: [UUID: SentReminder] = [:]

    /// The reminders delivered through each connection that wait there for the other person to
    /// accept them (ticket 203).
    private var waitingThere: [(reminderID: Reminder.ID, connectionID: UUID)] = []

    /// Stands in for the other person's iPhone getting every reminder sent through the connection
    /// with `connectionID` since the last time (ticket 201): each copy's receipt arrives as through
    /// iCloud, started, so Sent shows it Delivered, or waiting when they ask first (ticket 203), so
    /// Sent shows "Waiting for them to accept" until `theyAcceptWhatWaits(through:)`.
    func theyGetWhatWasSent(through connectionID: UUID, askingFirst: Bool) {
        let arrived = undelivered.filter { $0.connectionID == connectionID }
        undelivered.removeAll { $0.connectionID == connectionID }
        if askingFirst { waitingThere += arrived }
        Task {
            for copy in arrived {
                try? await events?.received(.receipt(askingFirst ? .waitingForAcceptance : .started, for: copy.reminderID, from: connectionID))
            }
        }
    }

    /// Stands in for the other person accepting every copy waiting on their iPhone from the
    /// connection with `connectionID` (ticket 203): each one's started receipt arrives.
    func theyAcceptWhatWaits(through connectionID: UUID) {
        let accepted = waitingThere.filter { $0.connectionID == connectionID }
        waitingThere.removeAll { $0.connectionID == connectionID }
        Task {
            for copy in accepted {
                try? await events?.received(.receipt(.started, for: copy.reminderID, from: connectionID))
            }
        }
    }

    /// The iCloud account the stand-in reports (ticket 210), chosen from the Stand-in menu on
    /// Connections. A change tells the app model, as the real adapter's account change event does.
    /// It lasts until the app quits, so a check can go on to Send To and Sent.
    var account = SharingAccountState.available {
        didSet {
            guard account != oldValue else { return }
            events?.accountStateChanged()
        }
    }

    /// iCloud's ID for the stand-in's Apple Account, reported while `account` is available. The
    /// in-memory sharing store records the first one it sees, so a launch starts on it.
    private var accountID = AppleAccountID("stand-in-account")

    /// Stands in for a different Apple Account signing in on the iPhone (ticket 212), from the Stand-in
    /// menu on Connections: the account is available under a new ID, and the app model is told, so
    /// the old account's sharing leaves the phone and the Apple Account Changed note shows. What the
    /// old account held back while offline is dropped, as `CKSyncEngine` drops its pending changes.
    func anotherAccountSignsIn() {
        accountID = AppleAccountID(UUID().uuidString)
        unsent = []
        sentThrough = [:]
        undelivered = []
        lastSent = [:]
        waitingThere = []
        if account == .available {
            events?.accountStateChanged()
        } else {
            account = .available
        }
    }

    func signedInAccount() async -> SharingAccount {
        SharingAccount(state: account, idWhenAvailable: accountID)
    }

    /// The stand-in delivers nothing: the invite counts as sent, so the phone check can follow the
    /// screens that come after it.
    func invite(_ connectionID: UUID, to person: InvitedPerson, via route: InviteRoute) async throws -> Bool {
        StandInSharing.logger.notice("Stand-in: invited someone by \(String(describing: route), privacy: .public)")
        return true
    }

    func revokeInvite(_ connectionID: UUID) {
        StandInSharing.logger.notice("Stand-in: revoked an invite")
    }

    /// The invites `receiveInvite(from:unavailable:)` made unavailable.
    private var unavailable: Set<UUID> = []

    func accept(_ connectionID: UUID) async throws {
        if unavailable.contains(connectionID) { throw InviteUnavailable() }
    }

    /// The stand-in shares with no one else, so there is no one to take off.
    func keepOnly(_ participant: SharingParticipant, in connectionID: UUID) {
        StandInSharing.logger.notice("Stand-in: kept one person on an invite")
    }

    /// Stands in for tapping an invite from `name` (ticket 195): the app accepts it, or with
    /// `unavailable`, finds someone else accepted it first.
    func receiveInvite(from name: String, unavailable isUnavailable: Bool = false) {
        let invite = IncomingInvite(connectionID: UUID(), senderName: name)
        if isUnavailable { unavailable.insert(invite.connectionID) }
        Task { await events?.invited(invite) }
    }

    /// Stands in for the invited person accepting the invite to the connection with `connectionID`.
    func acceptedByThem(_ connectionID: UUID) {
        Task { try? await events?.inviteAccepted(connectionID, by: SharingParticipant(id: "stand-in")) }
    }

    /// How long before now a Quiet connection's other person last synced, under Goes Quiet: longer
    /// than `SharingConnection.quietAfter` in any build.
    static let quietLastSyncedAgo: TimeInterval = 18 * 24 * 60 * 60

    /// Stands in for the other person changing their choices for `connection` (ticket 196): their
    /// settings arrive, as through iCloud. It takes the connection, not its ID, for the Last synced
    /// they last carried, which stays while their Status sharing stays on. Turned on, they carry a
    /// fresh one, and off, none, as the heartbeat does (#435).
    func theyChoose(_ choices: ConnectionChoices, for connection: SharingConnection, at now: Date = .now) async {
        let lastSynced = choices.sharesStatus ? connection.theirLastSynced ?? now : nil
        await theirSettingsArrive(choices, lastSynced: lastSynced, for: connection)
    }

    /// Stands in for the other person's app going unopened (#436): their settings arrive with
    /// their Status sharing on and a Last synced `quietLastSyncedAgo` before `now`, so the
    /// connection is Quiet.
    func theyGoQuiet(_ connection: SharingConnection, at now: Date = .now) async {
        await theirSettingsArrive(ConnectionChoices(sharesStatus: true, deliveryMode: connection.theirs.deliveryMode), lastSynced: now.addingTimeInterval(-Self.quietLastSyncedAgo), for: connection)
    }

    /// Stands in for the other person's app syncing again (#436): their settings arrive with their
    /// Status sharing on and a Last synced of `now`, so the connection isn't Quiet.
    func theySync(_ connection: SharingConnection, at now: Date = .now) async {
        await theirSettingsArrive(ConnectionChoices(sharesStatus: true, deliveryMode: connection.theirs.deliveryMode), lastSynced: now, for: connection)
    }

    private func theirSettingsArrive(_ choices: ConnectionChoices, lastSynced: Date?, for connection: SharingConnection) async {
        try? await events?.received(.settings(.init(choices, lastSynced: lastSynced), for: connection.id))
    }

    /// Stands in for the other person sending a reminder of `strength` through the connection with
    /// `connectionID` (ticket 198): their send arrives, as through iCloud, due at the start of the
    /// minute 2 minutes from now, and the app keeps the copy as their Delivery mode says.
    /// `NUDGE_SEED=clean` removes what the stand-in's Riley Park sent.
    func theySend(_ strength: Strength, through connectionID: UUID) {
        let due = Self.startOfMinute(minutesFromNow: 2)
        let title = strength == .relentless ? "Take the medicine" : "Bring the umbrella"
        theySend(Reminder(title: title, notes: SeedSet.standInSentNotes, dueTime: due, strength: strength), through: connectionID)
    }

    /// The same send, of a reminder the caller made: the screenshots harness (#442's site shots)
    /// sends ones with titles and times of its own.
    func theySend(_ reminder: Reminder, through connectionID: UUID) {
        let sent = SentReminder(reminder: reminder, revision: 0)
        lastSent[connectionID] = sent
        Task { try? await events?.received(.send(sent, to: connectionID)) }
    }

    /// Stands in for the other person changing the reminder they last sent through the connection with
    /// `connectionID` (ticket 204): their revision arrives, as through iCloud, moving it to the start
    /// of the minute 2 minutes from now and switching its strength between Gentle and Firm, so the
    /// copy's change note has two lines, whether the copy is nudging or waiting to be accepted.
    func theySendAChange(through connectionID: UUID) {
        guard var sent = lastSent[connectionID] else { return }
        sent.reminder.dueTime = Self.startOfMinute(minutesFromNow: 2)
        sent.reminder.strength = sent.reminder.strength == .gentle ? .firm : .gentle
        sent.revision += 1
        lastSent[connectionID] = sent
        Task { try? await events?.received(.revise(sent, for: connectionID)) }
    }

    /// Stands in for the other person deleting the reminder they last sent through the connection with
    /// `connectionID` (ticket 205): their cancel arrives, as through iCloud, and the copy is Canceled,
    /// whether it is nudging or waiting to be accepted.
    func theyCancel(through connectionID: UUID) {
        guard let sent = lastSent[connectionID] else { return }
        Task { try? await events?.received(.cancel(sent.reminder.id, for: connectionID)) }
    }

    /// Stands in for the other person disconnecting the connection with `connectionID` (ticket
    /// 197): their disconnect arrives, as through iCloud, and Connection Ended shows.
    func theyDisconnect(_ connectionID: UUID) {
        Task { try? await events?.received(.disconnect(connectionID)) }
    }

    private static func startOfMinute(minutesFromNow minutes: Double) -> Date {
        let soon = Date.now.addingTimeInterval(minutes * 60)
        return Calendar.autoupdatingCurrent.dateInterval(of: .minute, for: soon)?.start ?? soon
    }
}
#endif
