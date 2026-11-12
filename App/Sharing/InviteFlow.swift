import SwiftUI

extension View {
    /// Invite Someone, or Invite Again for the invite with `replacing` (ticket 194): the hint
    /// first, then on Continue the adapter's sharing sheet (the system's, with the real adapter,
    /// #217), then what came of it. Invite Again skips the hint: the invited person's page already
    /// shows its advice. `onInvited` gets the person listed once an invite is sent.
    func inviteFlow(sharing: SharingModel, isPresented: Binding<Bool>, replacing: UUID? = nil, onInvited: @escaping (SharingConnection) -> Void = { _ in }) -> some View {
        modifier(InviteFlow(sharing: sharing, isPresented: isPresented, replacing: replacing, onInvited: onInvited))
    }

    /// Invite Someone where there may be no sharing model (previews, and the form without sharing):
    /// the flow when there is one, nothing otherwise.
    @ViewBuilder
    func inviteFlow(sharing: SharingModel?, isPresented: Binding<Bool>) -> some View {
        if let sharing {
            inviteFlow(sharing: sharing, isPresented: isPresented)
        } else {
            self
        }
    }
}

private struct InviteFlow: ViewModifier {
    let sharing: SharingModel
    @Binding var isPresented: Bool
    let replacing: UUID?
    let onInvited: (SharingConnection) -> Void

    /// Set by Continue, so the sharing sheet starts once the hint has gone: one sheet can't be
    /// shown while another is still leaving.
    @State private var continues = false
    @State private var alreadyConnected: SharingConnection?
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: showsHint, onDismiss: startIfContinued) {
                InviteHintSheet {
                    continues = true
                    isPresented = false
                }
            }
            .onChange(of: isPresented) { _, presented in
                guard presented, replacing != nil else { return }
                isPresented = false
                continues = true
                startIfContinued()
            }
            .alert(
                Text("Already Connected", comment: "Invite: title of the message shown when the person invited is already connected."),
                isPresented: Binding { alreadyConnected != nil } set: { if !$0 { alreadyConnected = nil } },
                presenting: alreadyConnected
            ) { _ in
                Button {
                } label: {
                    Text("OK", comment: "Invite: dismisses the Already Connected message.")
                }
            } message: { connection in
                Text("You and \(connection.name) are already connected.", comment: "Invite: under Already Connected. The argument is the person's name, such as \"Riley Park\".")
            }
            .alert(
                Text("Couldn't Send the Invite", comment: "Invite: title of the message shown when the invite couldn't be made."),
                isPresented: $failed
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Invite: dismisses the message that the invite couldn't be made.")
                }
            } message: {
                Text("Nothing was sent. Try again.", comment: "Invite: under Couldn't Send the Invite.")
            }
    }

    private var showsHint: Binding<Bool> {
        Binding { isPresented && replacing == nil } set: { isPresented = $0 }
    }

    private func startIfContinued() {
        guard continues else { return }
        continues = false
        Task {
            do {
                switch try await sharing.invite(replacing: replacing) {
                case .invited(let connection): onInvited(connection)
                case .alreadyConnected(let connection): alreadyConnected = connection
                case .canceled: break
                }
            } catch {
                failed = true
            }
        }
    }
}

/// The hint before the sharing sheet: invite one person, at their Apple Account. The mockup's
/// `inviteSheet`, hint step.
private struct InviteHintSheet: View {
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                ContentUnavailableView {
                    Label {
                        Text("Invite One Person", comment: "Invite hint: the title.")
                    } icon: {
                        Image(systemName: "person.badge.plus")
                    }
                } description: {
                    Text("Use the email address or phone number of their Apple Account, or the invite won't open for them.", comment: "Invite hint: under \"Invite One Person\", before the system's sharing sheet.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onContinue) {
                    Text("Continue", comment: "Invite hint: opens the system's sharing sheet to send the invite.")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(Design.Spacing.s4)
            }
            .navigationTitle(Text("Invite Someone", comment: "Invite hint: the sheet's title."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DiscardingCancelButton(hasChanges: false)
                }
            }
        }
    }
}

#Preview("Invite hint") {
    InviteHintSheet {}
}

#Preview("Invite hint, largest text") {
    InviteHintSheet {}
        .environment(\.dynamicTypeSize, .accessibility5)
}
