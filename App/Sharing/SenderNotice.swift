import Foundation
import NudgeEngine

/// Where the sharing model hands the notices to the sender (ticket 208), in the shape of the other
/// adapters: the app model posts them through its notification adapter.
@MainActor
protocol SenderNoticePosting: AnyObject {
    func postSenderNotice(_ notice: SenderNotice)
}

/// A notification to the sender that a copy they sent is Done, removed or Missed (ticket 208): the
/// sent reminder's title, then what happened, in the words of the mockup's notifications.
struct SenderNotice: Equatable {
    /// Names the event, so one delivered again replaces its banner: the sent reminder, the person,
    /// and what happened to which occurrence.
    var key: String
    var title: String
    var body: String

    /// The notice a status record `change` makes against what `kept` holds, or `nil`: none for another
    /// kind of change, for a connection that isn't connected or whose status sharing is off, or for a
    /// status the sender already held.
    init?(for change: SharingChange, in kept: SharingData) {
        guard case .status(let record) = change.content,
              let copy = kept.sentCopies.first(where: { $0.connectionID == change.connectionID && $0.reminderID == change.reminderID }),
              let connection = kept.connections.first(where: { $0.id == change.connectionID && $0.state == .connected }), connection.theirs.sharesStatus,
              let sent = kept.sentReminders.first(where: { $0.reminder.id == copy.reminderID }),
              let event = SenderNoticeEvent(held: copy.statusRecord, arriving: record)
        else { return nil }
        let name = connection.name
        key = "\(copy.reminderID.uuidString).\(connection.id.uuidString).\(event.token)"
        title = sent.reminder.title
        body = switch event.kind {
        case .done: String(localized: "\(name) marked it Done", comment: "Body of the notification to the sender that the person they sent a reminder to marked it Done. 1: the person's name.")
        case .removed: String(localized: "\(name) removed it", comment: "Body of the notification to the sender that the person they sent a reminder to removed it. 1: the person's name.")
        case .missed: String(localized: "Missed: \(name) didn't mark it Done", comment: "Body of the notification to the sender that the person they sent a reminder to didn't mark it Done in time. 1: the person's name.")
        }
    }
}
