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

    /// Set while the invite is being made and shown, which takes a few seconds of iCloud work. The
    /// hint stays up with a spinner until the sharing sheet has come and gone.
    @State private var preparing = false
    @State private var alreadyConnected: SharingConnection?
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: showsHint) {
                InviteHintSheet(isPreparing: preparing) {
                    Task { await start() }
                }
                .interactiveDismissDisabled(preparing)
            }
            .onChange(of: isPresented) { _, presented in
                guard presented, replacing != nil else { return }
                isPresented = false
                Task { await start() }
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

    private func start() async {
        guard !preparing else { return }
        preparing = true
        defer { preparing = false }
        do {
            switch try await sharing.invite(replacing: replacing) {
            case .invited(let connection): onInvited(connection)
            case .alreadyConnected(let connection): alreadyConnected = connection
            case .canceled: break
            }
        } catch {
            failed = true
        }
        isPresented = false
    }
}

/// The hint before the sharing sheet: invite one person, at their Apple Account. The mockup's
/// `inviteSheet`, hint step.
private struct InviteHintSheet: View {
    let isPreparing: Bool
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
                    HStack(spacing: Design.Spacing.s2) {
                        if isPreparing { ProgressView() }
                        Text("Continue", comment: "Invite hint: opens the system's sharing sheet to send the invite.")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isPreparing)
                .padding(Design.Spacing.s4)
            }
            .navigationTitle(Text("Invite Someone", comment: "Invite hint: the sheet's title."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DiscardingCancelButton(hasChanges: false)
                        .disabled(isPreparing)
                }
            }
        }
    }
}

#Preview("Invite hint") {
    InviteHintSheet(isPreparing: false) {}
}

#Preview("Invite hint, largest text") {
    InviteHintSheet(isPreparing: false) {}
        .environment(\.dynamicTypeSize, .accessibility5)
}
