import Foundation
import NudgeEngine

/// A change of Apple Account (ticket 212, spec #127 decision A13): which account the sharing kept
/// on this iPhone belongs to, and what a different one signing in removes.
extension SharingModel {
    /// What a different Apple Account signing in removed: the Apple Account Changed note's, shown
    /// until the person dismisses it, or `nil` when there's nothing to tell them.
    var accountChangeNote: AccountChangeNote? {
        data.accountChangeNote
    }

    /// The person has seen the Apple Account Changed note. Throws if the store can't keep that, and
    /// the note then shows again.
    func dismissAccountChangeNote() throws {
        var kept = try currentData()
        guard kept.accountChangeNote != nil else { return }
        kept.accountChangeNote = nil
        try keep(kept)
    }

    /// Takes the account the adapter reported. One with no ID (unavailable, or not asked yet)
    /// changes nothing. One that couldn't be recorded is logged, and tried again on the next read:
    /// App opened, or the adapter's next account event.
    func record(_ account: SharingAccount) {
        guard let id = account.id else { return }
        do {
            try record(id)
        } catch {
            Self.logger.error("The account change couldn't be applied: \(error, privacy: .public)")
        }
    }

    /// Records `id` as the Apple Account the sharing kept here belongs to. The first ID reported is
    /// recorded and removes nothing. A different one removes the old account's sharing from this
    /// iPhone: its connections and invites, what it sent, its unsent changes and `CKSyncEngine`'s
    /// saved state, and what it received, with their nudges and alarms; personal reminders stay.
    /// The note of what went is kept until `dismissAccountChangeNote()`, joined to one the person
    /// hasn't seen yet. The sharing store goes first, as Disconnect's does, so one that won't keep
    /// it removes nothing. Throws, changing nothing, if the reminders haven't been read or the store
    /// can't keep it.
    private func record(_ id: AppleAccountID) throws {
        var kept = try currentData()
        guard kept.accountID != id else { return }
        guard kept.accountID != nil else {
            kept.accountID = id
            return try keep(kept)
        }
        guard let receivedReminders else { throw ReceivedRemindersNotReady() }
        let received = try receivedReminders.everyReceived()
        let removed = AccountChangeNote(old: kept, received: received)
        let note = kept.accountChangeNote.map { unseen in removed.map(unseen.adding) ?? unseen } ?? removed
        try keep(SharingData(accountID: id, accountChangeNote: note))
        receivedReminders.removeEveryReceived()
    }
}

extension AccountChangeNote {
    /// What a change of account removes of `old`, the sharing kept for the old account, and of
    /// `received`, the reminders it received; `nil` when there was nothing to remove.
    fileprivate init?(old: SharingData, received: [Reminder]) {
        let sendingIDs = Set(received.compactMap(\.receivedThrough))
        self.init(
            receivedCount: received.count,
            senders: old.connections.filter { sendingIDs.contains($0.id) }.map(\.name),
            connections: old.connections.map(\.name),
            sentCount: old.sentReminders.count
        )
        guard receivedCount > 0 || !connections.isEmpty || sentCount > 0 else { return nil }
    }

    /// This note with `later`'s added, for a second change of account before the person has seen
    /// the first note, so nothing removed goes unmentioned: the counts added up, and the names of
    /// both, each once, this note's first.
    func adding(_ later: AccountChangeNote) -> AccountChangeNote {
        AccountChangeNote(
            receivedCount: receivedCount + later.receivedCount,
            senders: senders + later.senders.filter { !senders.contains($0) },
            connections: connections + later.connections.filter { !connections.contains($0) },
            sentCount: sentCount + later.sentCount
        )
    }
}
