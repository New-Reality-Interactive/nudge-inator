import SwiftUI

extension View {
    /// What came of an invite the person tapped (ticket 195), over whatever screen is showing,
    /// since iCloud hands the app the invite wherever it is: the "Connected" sheet, the mockup's
    /// `acceptedSheet`, or a message that it's unavailable or couldn't be accepted. Nothing without
    /// a sharing model.
    /// `changeThese` opens the connection's page, for Change These (ticket 196).
    func inviteAcceptance(sharing: SharingModel?, changeThese: @escaping (UUID) -> Void) -> some View {
        modifier(InviteAcceptancePresenter(sharing: sharing, changeThese: changeThese))
    }
}

private struct InviteAcceptancePresenter: ViewModifier {
    let sharing: SharingModel?
    let changeThese: (UUID) -> Void

    func body(content: Content) -> some View {
        let acceptance = sharing?.acceptance
        content
            .sheet(item: Binding { acceptance?.connection } set: { if $0 == nil { sharing?.dismissAcceptance() } }) { connection in
                AcceptedInviteSheet(connection: connection) {
                    sharing?.dismissAcceptance()
                } onChangeThese: {
                    sharing?.dismissAcceptance()
                    changeThese(connection.id)
                }
            }
            .alert(
                Text("Invite Unavailable", comment: "Accepting an invite: title of the message shown when the invite no longer works for this person."),
                isPresented: isShowing(.unavailable)
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Accepting an invite: dismisses the Invite Unavailable message.")
                }
            } message: {
                Text("Someone else accepted it first, or it was canceled. Ask them to invite you again.", comment: "Accepting an invite: under Invite Unavailable.")
            }
            .alert(
                Text("Couldn't Accept the Invite", comment: "Accepting an invite: title of the message shown when the invite couldn't be accepted now."),
                isPresented: isShowing(.failed)
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Accepting an invite: dismisses the Couldn't Accept the Invite message.")
                }
            } message: {
                Text("Check that you're online, then tap the invite again.", comment: "Accepting an invite: under Couldn't Accept the Invite.")
            }
    }

    private func isShowing(_ shown: SharingModel.InviteAcceptance) -> Binding<Bool> {
        Binding { sharing?.acceptance == shown } set: { if !$0 { sharing?.dismissAcceptance() } }
    }
}

private extension SharingModel.InviteAcceptance {
    var connection: SharingConnection? {
        if case .connected(let connection) = self { connection } else { nil }
    }
}

/// "You're Connected with <name>", once the invited person has accepted, with this person's Status
/// Sharing and Delivery Mode for reminders from them, and Change These, which opens the
/// connection's page (ticket 196).
private struct AcceptedInviteSheet: View {
    let connection: SharingConnection
    let onDone: () -> Void
    let onChangeThese: () -> Void

    var body: some View {
        NavigationStack {
            List {
                // Laid out as the app's empty states are, but by hand: `ContentUnavailableView` as a
                // list row keeps its title to one line, which cut a whole name off (phone check).
                Section {
                    VStack(spacing: Design.Spacing.s3) {
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .imageScale(.large)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .accessibilityHidden(true)
                        // The whole name: Foundation reads "Alex Morgan" as one given name (#194).
                        Text("You're Connected with \(connection.name)", comment: "Accepting an invite: title of the sheet once connected. The argument is the name of the person who sent the invite, such as \"Alex Morgan\".")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("You can each send the other reminders now.", comment: "Accepting an invite: under \"You're Connected with\".")
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, Design.Spacing.s5)
                }
                .listRowBackground(Color.clear)
                Section {
                    ConnectionChoiceRows(choices: connection.mine)
                } footer: {
                    Text("These are your choices for reminders from \(connection.name). You can change them at any time in Settings › Connections.", comment: "Accepting an invite: under Status Sharing and Delivery Mode on the Connected sheet. The argument is the name of the person who sent the invite, such as \"Alex Morgan\".")
                }
                Section {
                    VStack(spacing: Design.Spacing.s3) {
                        Button(action: onDone) {
                            Text("Done", comment: "Accepting an invite: closes the Connected sheet.")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Button(action: onChangeThese) {
                            Text("Change These", comment: "Accepting an invite: on the Connected sheet, opens the connection's page in Settings to change Status Sharing and Delivery Mode.")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .navigationTitle(Text("Connected", comment: "Accepting an invite: title of the sheet once connected."))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
#Preview("Connected") {
    AcceptedInviteSheet(connection: SharingConnection(id: UUID(), name: "Alex Morgan", state: .connected)) {} onChangeThese: {}
}

#Preview("Connected, largest text") {
    AcceptedInviteSheet(connection: SharingConnection(id: UUID(), name: "Alex Morgan", state: .connected)) {} onChangeThese: {}
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
