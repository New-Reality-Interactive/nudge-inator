import SwiftUI

/// Settings › Connections (ticket 194): Invite Someone, then the people connected and the people
/// invited, or with no one, an empty state that offers only Invite. The mockup's `viewConnections`.
struct ConnectionsPage: View {
    let sharing: SharingModel

    @State private var isInviting = false

    var body: some View {
        let list = sharing.connectionsList(calendar: .autoupdatingCurrent)
        Group {
            if list.isEmpty {
                ScrollView {
                    ContentUnavailableView {
                        Label {
                            Text("No Connections", comment: "Connections: title of the empty state, with no one connected or invited.")
                        } icon: {
                            Image(systemName: "person.2")
                        }
                    } description: {
                        Text("Invite someone you trust, and you can send each other reminders.", comment: "Connections: under \"No Connections\".")
                    } actions: {
                        Button {
                            isInviting = true
                        } label: {
                            InviteSomeoneLabel()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
            } else {
                List {
                    Section {
                        Button {
                            isInviting = true
                        } label: {
                            InviteSomeoneLabel()
                        }
                    }
                    if !list.connected.isEmpty {
                        Section {
                            ForEach(list.connected, id: \.id) { connection in
                                NavigationLink(value: SharingPage.connection(connection.id)) {
                                    PersonRow(name: connection.name, lines: [
                                        Text("Connected", comment: "Connections: under a connected person's name."),
                                    ])
                                }
                            }
                        } header: {
                            Text("Connected", comment: "Connections: header of the people connected.")
                        }
                    }
                    if !list.invited.isEmpty {
                        Section {
                            ForEach(list.invited) { row in
                                NavigationLink {
                                    InvitePage(sharing: sharing, connection: row.connection)
                                } label: {
                                    PersonRow(name: row.connection.name, lines: Self.lines(for: row))
                                }
                            }
                        } header: {
                            Text("Invited", comment: "Connections: header of the people invited who haven't accepted yet.")
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("Connections", comment: "Connections: the page's title, and the Settings row that opens it."))
        .navigationBarTitleDisplayMode(.inline)
        .inviteFlow(sharing: sharing, isPresented: $isInviting)
        #if DEBUG
        .standInSharingControls()
        #endif
    }

    private static func lines(for row: ConnectionsList.InvitedRow) -> [Text] {
        var lines = [InvitePage.waitingText]
        if row.showsMismatchHelp {
            lines.append(Text("Didn't open for them? Check the address.", comment: "Connections: under an invite 2 days old or more, which may have gone to an address that isn't their Apple Account."))
        }
        return lines
    }
}

extension View {
    /// Where Settings' sharing pages go (ticket 196): Connections, and a connected person's page.
    /// Nothing without a sharing model, which has no links to them either.
    func settingsPages(sharing: SharingModel?) -> some View {
        navigationDestination(for: SharingPage.self) { page in
            if let sharing {
                switch page {
                case .connections: ConnectionsPage(sharing: sharing)
                case .connection(let id): ConnectionPage(sharing: sharing, connectionID: id)
                }
            }
        }
    }
}

/// Invite Someone with its icon, as the page's first row and the empty state's button.
private struct InviteSomeoneLabel: View {
    var body: some View {
        Label {
            Text("Invite Someone", comment: "Connections: starts an invite to one person.")
        } icon: {
            Image(systemName: "person.badge.plus")
        }
    }
}

/// A person's row: the round person tile, their name, and lines under it. VoiceOver reads them as
/// one element. Stacked at accessibility sizes, as a tag's row is.
private struct PersonRow: View {
    let name: String
    let lines: [Text]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = Design.Size.settingsTile

    private var tile: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? min(tileSize, Design.Spacing.rowMin) : tileSize
    }

    var body: some View {
        SizeAdaptiveStack(rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s2) {
            RoundTile(symbol: "person", size: tile)
            VStack(alignment: .leading, spacing: Design.Spacing.line) {
                Text(verbatim: name)
                    .font(.body)
                ForEach(lines.indices, id: \.self) { index in
                    lines[index]
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("People") {
    let sharing = StandInSharing.previewModel()
    NavigationStack { ConnectionsPage(sharing: sharing).settingsPages(sharing: sharing) }
}

#Preview("No one") {
    NavigationStack { ConnectionsPage(sharing: StandInSharing.previewModel(seeded: false)) }
}

#Preview("People, largest text") {
    NavigationStack { ConnectionsPage(sharing: StandInSharing.previewModel()) }
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    NavigationStack { ConnectionsPage(sharing: StandInSharing.previewModel()) }
}
#endif
