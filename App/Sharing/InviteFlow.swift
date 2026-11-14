import Contacts
import ContactsUI
import NudgeEngine
import SwiftUI

extension View {
    /// Invite Someone, or Invite Again for the invite with `replacing` (ticket 194, #217): the
    /// app's own sheet, where the person says who to invite and how to send the invite. Invite
    /// Again locks the person, since only the way to send is left to choose. `onInvited` gets the
    /// person listed once an invite is sent.
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

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                InviteSheet(sharing: sharing, locked: replacing.flatMap(sharing.connection), onInvited: onInvited)
            }
    }
}

extension InviteRoute {
    /// What the person taps in Send With.
    fileprivate var title: LocalizedStringResource {
        switch self {
        case .messages: LocalizedStringResource("Messages", comment: "Invite Someone: Send With, the way that opens the message screen.")
        case .mail: LocalizedStringResource("Mail", comment: "Invite Someone: Send With, the way that opens the mail screen.")
        case .copyLink: LocalizedStringResource("Copy Link", comment: "Invite Someone: Send With, the way that copies the invite's link.")
        }
    }

    /// Under Send With, for the way that is selected.
    fileprivate var explanation: LocalizedStringResource {
        switch self {
        case .messages: LocalizedStringResource("Messages opens its own screen with the invite ready, and you tap Send there. Nothing is sent until you do.", comment: "Invite Someone: under Send With while Messages is selected.")
        case .mail: LocalizedStringResource("Mail opens its own screen with the invite ready, and you tap Send there. Nothing is sent until you do.", comment: "Invite Someone: under Send With while Mail is selected.")
        case .copyLink: LocalizedStringResource("Copies the invite link, for you to send anywhere. Nothing is sent until you do.", comment: "Invite Someone: under Send With while Copy Link is selected.")
        }
    }
}

/// Invite Someone: who to invite (typed, matched from Contacts as you type, or picked with the plus),
/// how to send the invite, and Invite. The mockup is `docs/mockups/2026-11-13-custom-invite-screen/`.
private struct InviteSheet: View {
    let sharing: SharingModel
    /// The invite being sent again: its person can't be changed.
    let locked: SharingConnection?
    let onInvited: (SharingConnection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    /// A contact the person chose, which shows as a name pill.
    @State private var contact: InvitedPerson?
    /// The way to send the person picked, kept while it still fits the address.
    @State private var pick: InviteRoute?
    @State private var isPreparing = false
    @State private var isPickingContact = false
    @State private var addressChoices: [InvitedPerson] = []
    @State private var alreadyConnected: SharingConnection?
    @State private var alreadyInvited: SharingConnection?
    @State private var failed = false
    /// Set after Copy Link, so the person is told the link is on the clipboard before the sheet closes.
    @State private var copiedFor: SharingConnection?

    /// Who the invite is for, once there is a contact or an address to go on.
    private var person: InvitedPerson? {
        if let locked, let address = locked.address { return InvitedPerson(name: locked.name, address: address) }
        if let contact { return contact }
        let address = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return InviteAddressKind(address: address) == nil ? nil : InvitedPerson(name: address, address: address)
    }

    private var kind: InviteAddressKind? { person.flatMap { InviteAddressKind(address: $0.address) } }

    /// The ways that fit the address and this iPhone can do.
    private var routes: [InviteRoute] { kind?.routes.filter(SystemInviteDelivery.canDeliver) ?? [] }

    /// The way in use: the pick while it fits, else the natural one, else the first that can work.
    private var route: InviteRoute? {
        guard let kind else { return nil }
        let wanted = kind.route(preferring: pick)
        return routes.contains(wanted) ? wanted : routes.first
    }

    private var isChosen: Bool { contact != nil || locked != nil }

    /// Apple: the contact access button is for an app with limited access, or not asked yet. With
    /// full access it shows nothing, and when access was denied it only offers a prompt that can't help.
    private var contactAccessButtonApplies: Bool {
        [.limited, .notDetermined].contains(CNContactStore.authorizationStatus(for: .contacts))
    }

    var body: some View {
        NavigationStack {
            Form {
                whoSection
                if locked == nil, contact == nil, !text.isEmpty, contactAccessButtonApplies {
                    Section {
                        ContactAccessButton(queryString: text) { identifiers in
                            Task { await choose(from: identifiers) }
                        }
                    }
                }
                if let route {
                    Section {
                        ForEach(routes, id: \.self) { candidate in
                            Button {
                                pick = candidate
                            } label: {
                                HStack {
                                    Text(candidate.title)
                                    Spacer()
                                    if candidate == route { Image(systemName: "checkmark").accessibilityHidden(true) }
                                }
                            }
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(candidate == route ? .isSelected : [])
                        }
                    } header: {
                        Text("Send With", comment: "Invite Someone: heading of the list of ways to send the invite.")
                    } footer: {
                        Text(route.explanation)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await invite() }
                } label: {
                    HStack(spacing: Design.Spacing.s2) {
                        if isPreparing { ProgressView() }
                        Text("Invite", comment: "Invite Someone: sends the invite to the person chosen.")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(person == nil || route == nil || isPreparing)
                .padding(Design.Spacing.s4)
            }
            .navigationTitle(locked == nil
                ? Text("Invite Someone", comment: "Invite Someone: the sheet's title.")
                : Text("Invite Again", comment: "Invite Again: the sheet's title, opened from an invited person's page."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DiscardingCancelButton(hasChanges: false)
                        .disabled(isPreparing)
                }
            }
        }
        .interactiveDismissDisabled(isPreparing)
        .sheet(isPresented: $isPickingContact) {
            ContactPicker { picked in
                contact = picked
                isPickingContact = false
            }
            .ignoresSafeArea()
        }
        .confirmationDialog(
            Text("Choose an address", comment: "Invite Someone: title of the choice between a contact's email addresses and phone numbers."),
            isPresented: Binding { !addressChoices.isEmpty } set: { if !$0 { addressChoices = [] } },
            titleVisibility: .visible
        ) {
            ForEach(addressChoices, id: \.address) { choice in
                Button(choice.address) { contact = choice }
            }
        } message: {
            Text("Use the one that is their Apple Account.", comment: "Invite Someone: under the choice between a contact's addresses.")
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
            Text("Already Invited", comment: "Invite: title of the question shown when the person invited has an invite waiting."),
            isPresented: Binding { alreadyInvited != nil } set: { if !$0 { alreadyInvited = nil } },
            presenting: alreadyInvited
        ) { waiting in
            Button {
                Task { await send(replacing: waiting.id) }
            } label: {
                Text("Invite Again", comment: "Invite: sends a new invite in place of the one waiting.")
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Invite: leaves the Already Invited question without sending.")
            }
        } message: { waiting in
            Text("You've already invited \(waiting.name). Inviting again sends a new invite, and the earlier one stops working.", comment: "Invite: under Already Invited. The argument is the person's name, such as \"Riley Park\".")
        }
        .alert(
            Text("Link Copied", comment: "Invite: title of the message shown after Copy Link, once the invite's link is on the clipboard."),
            isPresented: Binding { copiedFor != nil } set: { if !$0 { copiedFor = nil } },
            presenting: copiedFor
        ) { _ in
            Button {
                dismiss()
            } label: {
                Text("OK", comment: "Invite: dismisses the Link Copied message and closes the sheet.")
            }
        } message: { connection in
            Text("Paste it into a message or email to \(connection.name).", comment: "Invite: under Link Copied. The argument is the invited person's name, such as \"Riley Park\".")
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

    private var whoSection: some View {
        Section {
            HStack(spacing: Design.Spacing.s3) {
                if isChosen, let person {
                    namePill(person)
                } else {
                    TextField(text: $text) {
                        Text("Email or phone", comment: "Invite Someone: placeholder of the field for the address of the person to invite.")
                    }
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                Spacer(minLength: 0)
                if locked == nil {
                    Button {
                        isPickingContact = true
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: Design.Spacing.s5 + Design.Spacing.s1, height: Design.Spacing.s5 + Design.Spacing.s1)
                            .background(.fill.tertiary, in: Circle())
                            .frame(minWidth: Design.Spacing.rowMin, minHeight: Design.Spacing.rowMin)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Choose from Contacts", comment: "Invite Someone: the plus beside the address field, which opens the contact picker."))
                }
            }
        } header: {
            Text("Who to Invite", comment: "Invite Someone: heading of the field for the person to invite.")
        } footer: {
            if isChosen, let person {
                Text("The invite opens only for \(person.name) at \(person.address).", comment: "Invite Someone: under the field once a person is chosen. The first argument is their name, the second their email address or phone number.")
            } else {
                Text("Use the email address or phone number of their Apple Account, or the invite won't open for them.", comment: "Invite Someone: under the address field before a person is chosen.")
            }
        }
    }

    /// A chosen person's name in the field, with a way to remove them unless the person is locked.
    private func namePill(_ person: InvitedPerson) -> some View {
        HStack(spacing: Design.Spacing.s2) {
            Text(person.name)
                .lineLimit(1)
            if locked == nil {
                Button {
                    contact = nil
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Remove \(person.name)", comment: "Invite Someone: removes the chosen person from the field. The argument is their name."))
            }
        }
        .foregroundStyle(.tint)
        .padding(.horizontal, Design.Spacing.s3)
        .padding(.vertical, Design.Spacing.s1)
        .background(.fill.tertiary, in: Capsule())
    }

    /// The contact the contact access button shared: the one address, or a choice between several.
    private func choose(from identifiers: [String]) async {
        let people = await InviteContacts.people(withIdentifiers: identifiers)
        if people.count == 1 {
            contact = people[0]
        } else {
            addressChoices = people
        }
    }

    private func invite() async {
        guard let person else { return }
        // Someone already invited isn't listed twice: inviting again replaces that invite, after asking.
        if locked == nil, let waiting = sharing.invitedConnection(for: person) {
            alreadyInvited = waiting
            return
        }
        await send(replacing: locked?.id)
    }

    private func send(replacing replacedID: UUID?) async {
        guard let person, let route else { return }
        isPreparing = true
        defer { isPreparing = false }
        do {
            switch try await sharing.invite(to: person, via: route, replacing: replacedID) {
            case .invited(let connection):
                onInvited(connection)
                if route == .copyLink {
                    copiedFor = connection
                } else {
                    dismiss()
                }
            case .alreadyConnected(let connection): alreadyConnected = connection
            case .canceled: break
            }
        } catch {
            failed = true
        }
    }
}
