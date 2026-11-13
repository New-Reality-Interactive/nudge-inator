#if DEBUG
import Foundation
import NudgeEngine
import os
import SwiftUI
import UIKit

/// Sharing for the phone check of Connections (ticket 194), until the CloudKit adapter (#216) gives
/// the app a real sharing model: a launch with `NUDGE_SHARING_STANDIN=seeded` (a connection and two
/// invites, one 3 days old), `=sent` (those, and two reminders already delivered to Riley, ticket
/// 207) or `=empty` gets a stand-in adapter over an in-memory sharing store. A
/// launch without the variable gets no sharing, as the shipped app. Nothing it holds outlives the
/// launch, so a launch without the variable is its cleanup. Debug builds only:
/// `scripts/check-release-has-no-seed.sh` checks Release builds hold none of it.
@MainActor
enum StandInSharing {
    static let variable = "NUDGE_SHARING_STANDIN"
    /// The latest stand-in adapter made, for the stand-in controls on Connections (ticket 195).
    /// The model holds it; this doesn't.
    private(set) static weak var current: StandInSharingAdapter?

    static func modelIfAsked(clock: any EngineClock, environment: [String: String] = ProcessInfo.processInfo.environment) -> SharingModel? {
        var seed: SharingData
        switch environment[variable] {
        case "seeded": seed = seeded(now: clock.now)
        case "sent":
            seed = seeded(now: clock.now)
            let (reminders, copies) = sentToRiley(now: clock.now)
            seed.sentReminders = reminders
            seed.sentCopies = copies
        case "empty": seed = SharingData()
        case .none: return nil
        case .some(let other):
            logger.error("No stand-in sharing called \(other, privacy: .public): use seeded, sent or empty")
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
        ])
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
            SentCopy(connectionID: SeedSet.standInConnectionID, reminderID: reminder.id, createdAt: now.addingTimeInterval(Double(index - 2) * 60), receipt: .started, statusRecord: nil, waitingToSync: false)
        }
        return ([SentReminder(reminder: pills, revision: 0), SentReminder(reminder: call, revision: 0)], copies)
    }

    fileprivate static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "StandInSharing")
}

extension View {
    /// A Stand-in menu in the toolbar for the phone check (ticket 195), only under the stand-in:
    /// receiving an invite, one that's unavailable, with `invited`, that person accepting, and with
    /// `connected`, that person changing their Status sharing or Delivery mode (ticket 196), sending
    /// a reminder (ticket 198), getting what was sent to them (ticket 201), accepting what waits for
    /// them (ticket 203), reporting how what you sent is going (ticket 206), changing what they sent
    /// (ticket 204), deleting it (ticket 205) or disconnecting (ticket 197). Without either, on
    /// Connections, it also chooses the iCloud account the stand-in reports (ticket 210).
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
                                adapter.theyChoose(ConnectionChoices(sharesStatus: !theirs.sharesStatus, deliveryMode: theirs.deliveryMode), for: connected.id)
                            } label: {
                                Text(verbatim: "\(connected.name) Turns Status Sharing \(theirs.sharesStatus ? "Off" : "On")")
                            }
                            Button {
                                let other: DeliveryMode = theirs.deliveryMode == .askMeFirst ? .startRightAway : .askMeFirst
                                adapter.theyChoose(ConnectionChoices(sharesStatus: theirs.sharesStatus, deliveryMode: other), for: connected.id)
                            } label: {
                                Text(verbatim: "\(connected.name) Chooses \(theirs.deliveryMode == .askMeFirst ? "Start right away" : "Ask me first")")
                            }
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

    func submit(_ change: SharingChange) {
        StandInSharing.logger.notice("Stand-in: not sending a \(String(describing: change.kind), privacy: .public) change")
        if change.kind == .send, let reminderID = change.reminderID {
            undelivered.append((reminderID, change.connectionID))
            sentThrough[change.connectionID, default: []].append(reminderID)
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

    func accountState() async -> SharingAccountState {
        account
    }

    func invite(_ connectionID: UUID) async throws -> InvitedPerson? {
        // `present` reports no failure, and the alert's buttons are what resume the wait, so it
        // presents only where it surely shows: otherwise the invite would wait for good.
        guard let presenter = Self.topViewController(), !presenter.isBeingDismissed, presenter.presentedViewController == nil else {
            StandInSharing.logger.error("Stand-in: nowhere to show the sharing sheet")
            return nil
        }
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: "Add People (stand-in)", message: "iOS draws this sheet with the real adapter.", preferredStyle: .alert)
            alert.addTextField { $0.placeholder = "Name (optional)" }
            alert.addTextField {
                $0.placeholder = "Email or phone"
                $0.keyboardType = .emailAddress
                $0.autocapitalizationType = .none
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in continuation.resume(returning: nil) })
            alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak alert] _ in
                let name = alert?.textFields?[0].text?.trimmingCharacters(in: .whitespaces) ?? ""
                let address = alert?.textFields?[1].text?.trimmingCharacters(in: .whitespaces) ?? ""
                guard !address.isEmpty else { return continuation.resume(returning: nil) }
                continuation.resume(returning: InvitedPerson(name: name.isEmpty ? address : name, address: address))
            })
            presenter.present(alert, animated: true)
        }
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

    /// Stands in for the other person changing their choices for the connection with `connectionID`
    /// (ticket 196): their settings arrive, as through iCloud.
    func theyChoose(_ choices: ConnectionChoices, for connectionID: UUID) {
        Task { try? await events?.received(.settings(.init(choices), for: connectionID)) }
    }

    /// Stands in for the other person sending a reminder of `strength` through the connection with
    /// `connectionID` (ticket 198): their send arrives, as through iCloud, due at the start of the
    /// minute 2 minutes from now, and the app keeps the copy as their Delivery mode says.
    /// `NUDGE_SEED=clean` removes what the stand-in's Riley Park sent.
    func theySend(_ strength: Strength, through connectionID: UUID) {
        let due = Self.startOfMinute(minutesFromNow: 2)
        let title = strength == .relentless ? "Take the medicine" : "Bring the umbrella"
        let sent = SentReminder(reminder: Reminder(title: title, notes: SeedSet.standInSentNotes, dueTime: due, strength: strength), revision: 0)
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

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
#endif
