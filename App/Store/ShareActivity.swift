import Foundation

/// One thing that happened to the person's sharing that they would otherwise never see (#396, spec
/// #127 Offline and iCloud): when, which connection, and what. The sharing store keeps the newest
/// `limit` of them, on this iPhone only (GLOSSARY.md, Share Activity).
struct ShareActivityEntry: Equatable, Identifiable {
    /// How many entries the record keeps: the oldest go first.
    static let limit = 300

    let id: UUID
    let at: Date
    /// The names of the connections it concerns, as the person knew them: one for most events,
    /// each one removed for a change of Apple Account, and none when the app no longer had the
    /// connection to name (the person may have removed it since the change was refused). Kept as
    /// names, not as a sentence, so the page makes its list in the person's language.
    var connectionNames: [String]
    var event: Event

    init(id: UUID = UUID(), at: Date, connectionNames: [String], event: Event) {
        self.id = id
        self.at = at
        self.connectionNames = connectionNames
        self.event = event
    }

    /// What happened. The entry keeps this, not a sentence, so the page shows it in the person's
    /// language whenever they open it.
    enum Event: Equatable {
        /// iCloud refused a change this person made for good, so it was given up. The kind says what it was.
        case changeGivenUp(OutboxChange.Kind)
        /// The connection ended because iCloud lost it: for example after an iCloud Keychain reset,
        /// or the person's data in iCloud being purged.
        case connectionLost
        /// The other person disconnected.
        case otherPersonLeft
        /// A different Apple Account signed in, which removed the old account's sharing.
        case accountChanged
    }
}

extension ShareActivityEntry.Event {
    /// What happened, in plain words, as the Share Activity page says it.
    var text: LocalizedStringResource {
        switch self {
        case .changeGivenUp(.send):
            LocalizedStringResource("iCloud refused a reminder you sent, so it wasn't delivered.", comment: "Share Activity: an entry for a reminder the person sent that iCloud refused for good.")
        case .changeGivenUp(.revise):
            LocalizedStringResource("iCloud refused a change to a reminder you sent, so it wasn't delivered.", comment: "Share Activity: an entry for a change to a sent reminder that iCloud refused for good.")
        case .changeGivenUp(.cancel):
            LocalizedStringResource("iCloud refused deleting a reminder you sent, so their copy wasn't removed.", comment: "Share Activity: an entry for deleting a sent reminder, which iCloud refused for good, so the other person's copy stayed.")
        case .changeGivenUp(.receipt), .changeGivenUp(.status):
            LocalizedStringResource("iCloud refused an update about a reminder they sent you, so it wasn't delivered.", comment: "Share Activity: an entry for a receipt or status about a received reminder that iCloud refused for good.")
        case .changeGivenUp(.settings):
            LocalizedStringResource("iCloud refused a change to your sharing choices, so it wasn't delivered.", comment: "Share Activity: an entry for a change to the person's Status sharing or Delivery mode that iCloud refused for good.")
        case .changeGivenUp(.disconnect):
            LocalizedStringResource("iCloud refused part of disconnecting, so it didn't finish.", comment: "Share Activity: an entry for a disconnect that iCloud refused for good.")
        case .connectionLost:
            LocalizedStringResource("iCloud lost the connection, so it ended. It can happen after an iCloud Keychain reset, or after removing the app's data from iCloud in Settings.", comment: "Share Activity: an entry for a connection that ended because iCloud deleted its data, not because the other person disconnected.")
        case .otherPersonLeft:
            LocalizedStringResource("They disconnected, so the connection ended.", comment: "Share Activity: an entry for a connection the other person ended by disconnecting.")
        case .accountChanged:
            LocalizedStringResource("A different Apple Account signed in, so sharing from the old one was removed.", comment: "Share Activity: an entry for a change of Apple Account, which removed the old account's connections.")
        }
    }
}

extension SharingData {
    /// Adds `entry` as the newest, and drops the oldest past `ShareActivityEntry.limit`.
    mutating func record(_ entry: ShareActivityEntry) {
        activity.append(entry)
        if activity.count > ShareActivityEntry.limit {
            activity.removeFirst(activity.count - ShareActivityEntry.limit)
        }
    }
}
