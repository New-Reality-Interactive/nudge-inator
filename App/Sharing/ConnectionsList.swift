import Foundation

/// What Settings › Connections lists (ticket 194): the people connected, then the people invited,
/// each in the order the sharing store keeps them.
struct ConnectionsList: Equatable {
    let connected: [SharingConnection]
    let invited: [InvitedRow]

    /// An invite not accepted yet, as its row shows it.
    struct InvitedRow: Equatable, Identifiable {
        let connection: SharingConnection
        /// Whether the row says "Didn't open for them?": iCloud doesn't tell the sender an invite
        /// was refused for the wrong Apple Account, so the row offers the help once the invite has
        /// waited 2 calendar days (the mockup's rule). The invite's own page always offers it.
        let showsMismatchHelp: Bool

        var id: UUID { connection.id }
    }

    /// The days an invite waits before its row offers the mismatch help.
    static let daysBeforeHelp = 2

    init(_ data: SharingData, now: Date, calendar: Calendar) {
        connected = data.connections.filter { $0.state == .connected }
        invited = data.connections.filter { $0.state == .invited }.map { connection in
            let days = connection.invitedAt.flatMap {
                calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: now)).day
            }
            return InvitedRow(connection: connection, showsMismatchHelp: (days ?? 0) >= Self.daysBeforeHelp)
        }
    }

    /// Nothing to list: the page shows only Invite Someone.
    var isEmpty: Bool { connected.isEmpty && invited.isEmpty }
}
