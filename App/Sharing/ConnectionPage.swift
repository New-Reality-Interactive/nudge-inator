import NudgeEngine
import SwiftUI

/// A connected person's page (ticket 196): this person's Status sharing and Delivery mode for what
/// they receive from them, both changeable at any time, then what the other person chose, then
/// Disconnect (ticket 197). The mockup's `viewConn`.
///
/// It looks the connection up by ID, so what the other person chooses shows as it arrives. Once
/// there's no connection with that ID, it says the connection ended, as the mockup does, and once
/// the connection has left the store (this person disconnected, or chose on Connection Ended) it
/// goes back to Connections, which no longer lists them, as the mockup's `finishDisconnect` does.
struct ConnectionPage: View {
    let sharing: SharingModel
    let connectionID: UUID

    @State private var saveFailed = false
    /// The connection Disconnect's sheet is for while it shows. Kept here rather than read from
    /// the store, since the sheet outlives the connection it ends.
    @State private var disconnecting: SharingConnection?
    /// Disconnect has ended the connection and its sheet is closing: the page goes back once it
    /// has closed, not while it closes.
    @State private var isClosingDisconnect = false
    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let connection = sharing.connection(connectionID) {
                page(connection)
            } else {
                ContentUnavailableView {
                    Label {
                        Text("Connection Ended", comment: "A connection's page: shown in place of the page once the connection no longer exists.")
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        // On the whole page, not the connected one alone, so the sheet's host outlives the
        // connection it ends.
        .sheet(item: $disconnecting) {
            isClosingDisconnect = false
            if !isInStore { dismiss() }
        } content: { connection in
            DisconnectSheet(name: connection.name, keptCount: model?.engine.keptOnDisconnect(from: connection.id) ?? 0, endedByThem: false) { choice in
                try model?.disconnect(connection.id, choosing: choice)
                isClosingDisconnect = true
                disconnecting = nil
            }
        }
        .onChange(of: isInStore) { _, inStore in
            if !inStore, !isClosingDisconnect { dismiss() }
        }
    }

    /// Whether the store still holds the connection, connected or ended by the other person.
    private var isInStore: Bool {
        sharing.data.connections.contains { $0.id == connectionID }
    }

    private func page(_ connection: SharingConnection) -> some View {
        // The whole name in sentences: Foundation reads "Alex Morgan" as one given name (#194).
        let name = connection.name
        return List {
            Section {
                VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                    Text(verbatim: name)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    if let connectedAt = connection.connectedAt {
                        Text("Connected since \(Self.day(of: connectedAt))", comment: "A connection's page: under the person's name. The argument is the day they connected, such as \"Sep 12\".")
                            .font(.body)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                }
                .padding(.vertical, Design.Spacing.s1)
            }
            statusSharingSection(connection)
            deliveryModeSection(connection)
            Section {
                ConnectionChoiceRows(choices: connection.theirs)
            } header: {
                Text("What \(name) Chose", comment: "A connection's page: header of the other person's choices for the reminders this person sends them. The argument is their name, such as \"Alex Morgan\".")
            } footer: {
                Text("\(name) sets these, for the reminders you send them.", comment: "A connection's page: under the other person's choices. The argument is their name, such as \"Alex Morgan\".")
            }
            Section {
                Button(role: .destructive) {
                    disconnecting = connection
                } label: {
                    Label {
                        Text("Disconnect", comment: "A connection's page: ends the connection, after asking what happens to the reminders received from the person.")
                    } icon: {
                        Image(systemName: "person.slash")
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: name))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            Text("Couldn't Save the Change", comment: "A connection's page: title of the message shown when a change of Status Sharing or Delivery Mode couldn't be saved."),
            isPresented: $saveFailed
        ) {
            Button {
            } label: {
                Text("OK", comment: "A connection's page: dismisses the message that a change couldn't be saved.")
            }
        } message: {
            Text("Your choices are as they were. Try again.", comment: "A connection's page: under Couldn't Save the Change.")
        }
        #if DEBUG
        .standInSharingControls(connected: connection)
        #endif
    }

    /// This person's Status sharing, with what it lets the other person see.
    private func statusSharingSection(_ connection: SharingConnection) -> some View {
        let name = connection.name
        return Section {
            Toggle(isOn: choice(\.sharesStatus, of: connection)) {
                ConnectionChoiceRows.statusSharingTitle
            }
        } header: {
            Text("Reminders from \(name)", comment: "A connection's page: header of this person's choices for what they receive. The argument is the other person's name, such as \"Alex Morgan\".")
        } footer: {
            if connection.mine.sharesStatus {
                Text("\(name) sees how the reminders they send you are going: Done, Paused, Missed or Removed, and the last 7 days of a repeating one.", comment: "A connection's page: under Status Sharing when it's on. The argument is the other person's name, such as \"Alex Morgan\".")
            } else {
                Text("\(name) sees only that a reminder was Delivered.", comment: "A connection's page: under Status Sharing when it's off. The argument is the other person's name, such as \"Alex Morgan\".")
            }
        }
    }

    /// This person's Delivery mode, with what it does to the other person's reminders.
    private func deliveryModeSection(_ connection: SharingConnection) -> some View {
        let name = connection.name
        return Section {
            deliveryModePicker(connection)
        } header: {
            ConnectionChoiceRows.deliveryModeTitle
        } footer: {
            switch connection.mine.deliveryMode {
            case .startRightAway:
                Text("Reminders from \(name) start nudging as soon as they arrive. Applies to reminders sent from now on.", comment: "A connection's page: under Delivery Mode when it's Start right away. The argument is the other person's name, such as \"Alex Morgan\".")
            case .askMeFirst:
                Text("Each reminder from \(name) waits for you to accept it, and sends no nudge until you do. Applies to reminders sent from now on.", comment: "A connection's page: under Delivery Mode when it's Ask me first. The argument is the other person's name, such as \"Alex Morgan\".")
            }
        }
    }

    /// Segmented, the glossary's words as written (DESIGN.md, Segmented choices' capitalization),
    /// or a menu at the accessibility sizes, where two segments don't fit, as the tag filter's
    /// Match does.
    @ViewBuilder
    private func deliveryModePicker(_ connection: SharingConnection) -> some View {
        let picker = Picker(selection: choice(\.deliveryMode, of: connection)) {
            ForEach(DeliveryMode.allCases, id: \.self) { mode in
                mode.text.tag(mode)
            }
        } label: {
            ConnectionChoiceRows.deliveryModeTitle
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    /// One of this person's choices, saved and sent as it changes. A change that couldn't be saved
    /// leaves the choice as it was and says so.
    private func choice<Value>(_ keyPath: WritableKeyPath<ConnectionChoices, Value>, of connection: SharingConnection) -> Binding<Value> {
        Binding {
            connection.mine[keyPath: keyPath]
        } set: { value in
            var choices = connection.mine
            choices[keyPath: keyPath] = value
            do {
                try sharing.change(choices, for: connection.id)
            } catch {
                saveFailed = true
            }
        }
    }

    /// "Sep 12", with the year when it isn't this year's.
    private static func day(of date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return calendar.isDate(date, equalTo: .now, toGranularity: .year) ? date.formatted(format) : date.formatted(format.year())
    }
}

/// Status Sharing and Delivery Mode as read-only rows: the other person's on a connection's page,
/// and this person's on the Connected sheet.
struct ConnectionChoiceRows: View {
    let choices: ConnectionChoices

    var body: some View {
        LabeledContent {
            if choices.sharesStatus {
                Text("On", comment: "A connection's page and the Connected sheet: Status Sharing is on.")
            } else {
                Text("Off", comment: "A connection's page and the Connected sheet: Status Sharing is off.")
            }
        } label: {
            Self.statusSharingTitle
        }
        LabeledContent {
            choices.deliveryMode.text
        } label: {
            Self.deliveryModeTitle
        }
    }

    /// The names of the two choices, on a connection's page and the Connected sheet.
    static let statusSharingTitle = Text("Status Sharing", comment: "A connection's page: the switch for whether the person sees how the reminders they send are going. Also the row on the Connected sheet and under \"What <name> Chose\".")
    static let deliveryModeTitle = Text("Delivery Mode", comment: "A connection's page: the choice of how a reminder from the person starts. Also the row on the Connected sheet and under \"What <name> Chose\".")
}

extension DeliveryMode {
    /// The glossary's words, as written.
    var text: Text {
        switch self {
        case .startRightAway: Text("Start right away", comment: "Delivery Mode: a reminder from this person starts nudging as soon as it arrives.")
        case .askMeFirst: Text("Ask me first", comment: "Delivery Mode: a reminder from this person waits to be accepted before it nudges.")
        }
    }
}

#if DEBUG
#Preview("Connection") {
    let sharing = StandInSharing.previewModel()
    NavigationStack {
        ConnectionPage(sharing: sharing, connectionID: sharing.data.connections.first { $0.state == .connected }?.id ?? UUID())
    }
}

#Preview("Connection, largest text") {
    let sharing = StandInSharing.previewModel()
    NavigationStack {
        ConnectionPage(sharing: sharing, connectionID: sharing.data.connections.first { $0.state == .connected }?.id ?? UUID())
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
