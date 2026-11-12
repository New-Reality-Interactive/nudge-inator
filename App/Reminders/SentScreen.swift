import Foundation
import NudgeEngine

/// What the Reminders tab's Sent view shows (ticket 201), read from the sharing store and the
/// engine's calendar at one moment: the reminders this person sent, grouped by the connected person
/// they went to, as the engine's Sent read-out orders them. A reminder sent to several people shows
/// under each. A value, so the tests and previews read it with no view.
struct SentScreen {
    let people: [Person]
    /// What Sent shows instead of groups, or `nil` when it has some (ticket 202).
    let emptyState: EmptyState?

    /// Sent's two empty states, the mockup's `viewSentTab`.
    enum EmptyState: Equatable {
        /// No one connected, so nothing can be sent yet: Invite Someone and Manage People.
        case noOneToSendTo
        /// Someone connected, but nothing sent to anyone connected: New Reminder.
        case nothingSent
    }

    struct Person: Identifiable {
        var connectionID: UUID
        /// The person's whole name, as Connections lists them.
        var name: String
        var rows: [Row]

        var id: UUID { connectionID }
    }

    /// One sent reminder as one person has it.
    struct Row: Identifiable {
        var reminderID: Reminder.ID
        var title: String
        /// Who it went to, for VoiceOver: the group's header says it on screen.
        var personName: String
        /// The time of day of its next due time, such as "9:00 AM".
        var time: String
        /// "Today", "Tomorrow", "Yesterday" or a short date, under the time.
        var day: String
        /// Whether the copy has reached the person's iPhone, whatever their status sharing, and
        /// whether it waits there for them to accept it (ticket 203).
        var delivery: SentReadOut.Delivery

        var id: Reminder.ID { reminderID }

        var isDelivered: Bool { delivery.isDelivered }
        var detailLine: LocalizedStringResource? { delivery.detailLine }

        /// What VoiceOver reads for the row: the person, the title, whether it was delivered or
        /// waits to be accepted, and the due time.
        var voiceOverLabel: LocalizedStringResource {
            let delivery = String(localized: detailLine ?? Self.deliveredText)
            return LocalizedStringResource("\(personName), \(title), \(delivery), \(day), \(time)", comment: "VoiceOver label of a row on the Reminders tab's Sent view. 1: who it was sent to, such as \"Riley Park\". 2: the reminder's title. 3: \"Delivered\", \"Not delivered yet\" or \"Waiting for them to accept\". 4: its due day, such as \"Today\". 5: its due time, such as \"9:00 AM\".")
        }

        static let waitingText = LocalizedStringResource("Waiting for them to accept", comment: "Under a sent reminder's title on the Sent view, and under a person's name on its details: their copy has reached their iPhone, which asks them first (Ask me first), and they haven't accepted it yet.")
        static let deliveredText = LocalizedStringResource("Delivered", comment: "A sent reminder's label on the Sent view and its details: the person's copy has reached their iPhone.")
        static let notDeliveredText = LocalizedStringResource("Not delivered yet", comment: "Under a sent reminder's title on the Sent view, and under a person's name on its details: their copy hasn't reached their iPhone yet.")
    }

    /// The people the reminder with `reminderID` went to, in the screen's order, each with their row.
    func recipients(of reminderID: Reminder.ID) -> [(person: Person, row: Row)] {
        people.compactMap { person in
            person.rows.first { $0.reminderID == reminderID }.map { (person, $0) }
        }
    }

    /// Only connected people are listed, as Send To offers them. A row's due time is the sent
    /// reminder's next at or after the engine's now, or its start when none is left.
    init(engine: Engine, sharing: SharingData) {
        let connections = sharing.connections
            .filter { $0.state == .connected }
            .map { SentConnection(id: $0.id, name: $0.name, sharesStatus: $0.theirs.sharesStatus) }
        let readOut = SentReadOut(connections: connections, copies: sharing.sentCopies)
        let reminders = Dictionary(sharing.sentReminders.map { ($0.reminder.id, $0.reminder) }, uniquingKeysWith: { first, _ in first })
        people = readOut.people.map { person in
            Person(
                connectionID: person.connectionID,
                name: person.name,
                rows: person.rows.compactMap { row in
                    guard let reminder = reminders[row.reminderID] else { return nil }
                    let due = engine.upcomingDueTimes(of: reminder, count: 1).first ?? reminder.dueTime
                    return Row(
                        reminderID: reminder.id,
                        title: reminder.title,
                        personName: person.name,
                        time: engine.timeOfDay(of: due),
                        day: engine.dayLabel(of: due),
                        delivery: row.delivery
                    )
                }
            )
        }
        .filter { !$0.rows.isEmpty }
        emptyState = connections.isEmpty ? .noOneToSendTo : people.isEmpty ? .nothingSent : nil
    }
}

extension SentReadOut.Delivery {
    /// Delivered trails a Sent row and a recipient on the details once the copy is on their
    /// iPhone, waiting or started, as the mockup's `sentStatus` labels a waiting copy (ticket 203).
    var isDelivered: Bool { self != .notDelivered }

    /// Under the title of a Sent row, and under a person's name on the details: "Not delivered
    /// yet", "Waiting for them to accept", or nothing once it started.
    var detailLine: LocalizedStringResource? {
        switch self {
        case .notDelivered: SentScreen.Row.notDeliveredText
        case .waitingForAcceptance: SentScreen.Row.waitingText
        case .delivered: nil
        }
    }
}
