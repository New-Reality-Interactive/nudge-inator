import NudgeEngine
import SwiftUI

/// An invited person's page (ticket 194): when the invite was sent and to whom, the help for an
/// invite that didn't open for them, Invite Again and Cancel Invite. The mockup's `viewInvite`.
/// Canceling it goes back to Connections; Invite Again stays, showing the new invite.
///
/// It shows the invite it was opened with, not a lookup: a lookup would turn into another view as
/// the invite is canceled or replaced, taking the dialogs and the invite flow with it.
struct InvitePage: View {
    let sharing: SharingModel
    @State var connection: SharingConnection

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingCancel = false
    @State private var isInvitingAgain = false
    @State private var cancelFailed = false

    /// Under an invited person's name, here and on their Connections row.
    static let waitingText = Text("Invited · Waiting for them to accept", comment: "Connections and an invited person's page: under the name of someone invited who hasn't accepted yet.")

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                    Text(verbatim: connection.name)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Self.waitingText
                        .font(.body)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                .padding(.vertical, Design.Spacing.s1)
            }
            Section {
                if let invitedAt = connection.invitedAt {
                    LabeledContent {
                        Text("\(dayLabel(of: invitedAt)) at \(timeOfDay(of: invitedAt))", comment: "An invited person's page: when the invite was sent. 1: \"Today\", \"Yesterday\" or a short date. 2: the time, such as \"7:40 AM\".")
                    } label: {
                        Text("Sent", comment: "An invited person's page: when the invite was sent.")
                    }
                }
                if let address = connection.address {
                    LabeledContent {
                        Text(verbatim: address)
                    } label: {
                        Text("To", comment: "An invited person's page: the email address or phone number the invite was sent to.")
                    }
                }
            }
            Section {
                HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s3) {
                    // No color: the help isn't "needs you now" (DESIGN.md, Notes on a received reminder).
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                        Text("Didn't open for them?", comment: "An invited person's page: heading of the help for an invite that went to the wrong Apple Account.")
                            .font(.body.weight(.semibold))
                        Text("An invite opens only for the Apple Account it was sent to. Check the email address or phone number of their Apple Account, then invite them again.", comment: "An invited person's page: the help under \"Didn't open for them?\".")
                            .font(.subheadline)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Section {
                Button {
                    isInvitingAgain = true
                } label: {
                    Label {
                        Text("Invite Again", comment: "An invited person's page: sends a new invite in place of this one.")
                    } icon: {
                        Image(systemName: "person.badge.plus")
                    }
                    .switchedOffLooksSecondary()
                }
                // No invite can be made without iCloud (ticket 210), as the mockup's `viewInvite`.
                .disabled(sharing.pause != nil)
                Button(role: .destructive) {
                    isConfirmingCancel = true
                } label: {
                    Label {
                        Text("Cancel Invite", comment: "An invited person's page: opens the question that asks before canceling the invite.")
                    } icon: {
                        Image(systemName: "xmark")
                    }
                }
            } footer: {
                Text("Canceling stops the invite from working.", comment: "An invited person's page: under Cancel Invite.")
            }
        }
        .navigationTitle(Text(verbatim: connection.name))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            Text("Cancel the invite to \(connection.name)?", comment: "An invited person's page: the question asked before canceling the invite. The argument is the person's name, such as \"Jordan Lee\", or the address they were invited at."),
            isPresented: $isConfirmingCancel,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                cancel()
            } label: {
                Text("Cancel Invite", comment: "The question before canceling an invite: cancels it.")
            }
            Button(role: .cancel) {
            } label: {
                Text("Keep Invite", comment: "The question before canceling an invite: keeps it.")
            }
        } message: {
            Text("It stops working, even if they've already got it.", comment: "The question before canceling an invite: under its title.")
        }
        .alert(
            Text("Couldn't Cancel the Invite", comment: "An invited person's page: title of the message shown when canceling the invite failed."),
            isPresented: $cancelFailed
        ) {
            Button {
            } label: {
                Text("OK", comment: "An invited person's page: dismisses the message that canceling failed.")
            }
        } message: {
            Text("The invite still works. Try again.", comment: "An invited person's page: under Couldn't Cancel the Invite.")
        }
        .inviteFlow(sharing: sharing, isPresented: $isInvitingAgain, replacing: connection.id) { again in
            connection = again
        }
        // Accepted while open: they're connected now, so back to Connections, which lists them so.
        .onChange(of: sharing.isConnected(connection.id)) { _, accepted in
            if accepted { dismiss() }
        }
        #if DEBUG
        .standInSharingControls(invited: connection)
        #endif
    }

    private func cancel() {
        do {
            try sharing.cancelInvite(connection.id)
            dismiss()
        } catch {
            cancelFailed = true
        }
    }

    /// "Today", "Yesterday" or a short date, from the engine as the details page has it.
    private func dayLabel(of date: Date) -> String {
        model?.engine.dayLabel(of: date) ?? date.formatted(date: .abbreviated, time: .omitted)
    }

    private func timeOfDay(of date: Date) -> String {
        model?.engine.timeOfDay(of: date) ?? date.formatted(date: .omitted, time: .shortened)
    }
}

#if DEBUG
private let previewInvite = SharingConnection(id: UUID(), name: "Priya Shah", state: .invited, address: "+1 (555) 010-4477", invitedAt: .now.addingTimeInterval(-3 * 24 * 60 * 60))

#Preview("Invite") {
    NavigationStack { InvitePage(sharing: StandInSharing.previewModel(), connection: previewInvite) }
}

#Preview("Invite, largest text") {
    NavigationStack { InvitePage(sharing: StandInSharing.previewModel(), connection: previewInvite) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
