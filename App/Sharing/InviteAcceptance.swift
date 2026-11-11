import SwiftUI

extension View {
    /// What came of an invite the person tapped (ticket 195), over whatever screen is showing,
    /// since iCloud hands the app the invite wherever it is: the "Connected" sheet, the mockup's
    /// `acceptedSheet`, or a message that it's unavailable or couldn't be accepted. Nothing without
    /// a sharing model.
    func inviteAcceptance(sharing: SharingModel?) -> some View {
        modifier(InviteAcceptancePresenter(sharing: sharing))
    }
}

private struct InviteAcceptancePresenter: ViewModifier {
    let sharing: SharingModel?

    func body(content: Content) -> some View {
        let acceptance = sharing?.acceptance
        content
            .sheet(item: Binding { acceptance?.connection } set: { if $0 == nil { sharing?.dismissAcceptance() } }) { connection in
                AcceptedInviteSheet(connection: connection) {
                    sharing?.dismissAcceptance()
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

/// "You're Connected with <name>", once the invited person has accepted. The mockup's Status
/// Sharing and Delivery Mode rows and Change These come with those settings and the connection's
/// page (#196).
private struct AcceptedInviteSheet: View {
    let connection: SharingConnection
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                ContentUnavailableView {
                    Label {
                        // The whole name: Foundation reads "Alex Morgan" as one given name (#194).
                        Text("You're Connected with \(connection.name)", comment: "Accepting an invite: title of the sheet once connected. The argument is the name of the person who sent the invite, such as \"Alex Morgan\".")
                    } icon: {
                        Image(systemName: "person.2")
                    }
                } description: {
                    Text("You can each send the other reminders now.", comment: "Accepting an invite: under \"You're Connected with\".")
                } actions: {
                    Button(action: onDone) {
                        Text("Done", comment: "Accepting an invite: closes the Connected sheet.")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle(Text("Connected", comment: "Accepting an invite: title of the sheet once connected."))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
#Preview("Connected") {
    AcceptedInviteSheet(connection: SharingConnection(id: UUID(), name: "Alex Morgan", state: .connected, sharesStatus: true)) {}
}

#Preview("Connected, largest text") {
    AcceptedInviteSheet(connection: SharingConnection(id: UUID(), name: "Alex Morgan", state: .connected, sharesStatus: true)) {}
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
