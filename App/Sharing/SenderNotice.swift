import Foundation
import NudgeEngine

/// Where the sharing model hands the notices to the sender (ticket 208), in the shape of the other
/// adapters: the app model posts them through its notification adapter.
@MainActor
protocol SenderNoticePosting: AnyObject {
    func postSenderNotice(key: String, title: String, body: String)
}

/// A notification to the sender that a copy they sent is Done, removed or Missed (ticket 208): the
/// sent reminder's title, then what happened, in the words of the mockup's notifications.
struct SenderNotice: Equatable {
    /// Names the event, so one delivered again replaces its banner: the sent reminder, the person,
    /// and the occurrence that closed (or what happened, for a copy removed).
    var key: String
    var title: String
    var body: String

    init(of notice: SentStatusNotice, reminderID: UUID, title: String, from name: String, through connectionID: UUID) {
        let occurrence = notice.occurrence.map { String(Int($0.timeIntervalSinceReferenceDate)) } ?? String(describing: notice.kind)
        key = "\(reminderID.uuidString).\(connectionID.uuidString).\(occurrence)"
        self.title = title
        body = switch notice.kind {
        case .done: String(localized: "\(name) marked it Done", comment: "Body of the notification to the sender that the person they sent a reminder to marked it Done. 1: the person's name.")
        case .removed: String(localized: "\(name) removed it", comment: "Body of the notification to the sender that the person they sent a reminder to removed it. 1: the person's name.")
        case .missed: String(localized: "Missed: \(name) didn't mark it Done", comment: "Body of the notification to the sender that the person they sent a reminder to didn't mark it Done in time. 1: the person's name.")
        }
    }
}
