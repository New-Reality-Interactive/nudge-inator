import NudgeEngine
import SwiftUI

/// Disconnect's choice (ticket 197), the mockup's `disconnectSheet`: Remove, the default, or Keep as
/// My Own Reminders, for the reminders received from the person. A sheet, not a confirmation dialog,
/// because a dialog can only list buttons and can't show Remove as the default (DESIGN.md, Shared
/// reminders). With `endedByThem` it's the other person's Connection Ended: a prominent Continue and
/// no Cancel, since the connection is already over and the choice has to be made.
struct DisconnectSheet: View {
    /// The other person's whole name: Foundation reads "Alex Morgan" as one given name (#194).
    let name: String
    /// How many reminders Keep would keep: those received from them and accepted.
    let keptCount: Int
    let endedByThem: Bool
    /// Does the choice. Throws if it couldn't be kept: the sheet then stays, says so, and the
    /// person can try again.
    let onChoose: (DisconnectChoice) throws -> Void

    @State private var choice = DisconnectChoice.remove
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // The list's own side insets, so the text lines up with the rows (phone check:
                    // with none it ran off both edges).
                    lead
                        .listRowBackground(Color.clear)
                }
                Section {
                    option(.remove) {
                        Text("Remove", comment: "Disconnect's sheet: the choice that deletes the reminders received from the person.")
                    } detail: {
                        Text("Deletes them and cancels their nudges and alarms.", comment: "Disconnect's sheet: under Remove.")
                    }
                    option(.keepAsMyOwnReminders) {
                        Text("Keep as My Own Reminders", comment: "Disconnect's sheet: the choice that keeps the reminders received from the person as this person's own.")
                    } detail: {
                        Text("They stay with the same schedule, history and tags, no longer from \(name).", comment: "Disconnect's sheet: under Keep as My Own Reminders. The argument is the other person's name, such as \"Alex Morgan\".")
                    }
                } header: {
                    Text("\(keptCount) Reminders from \(name)", comment: "Disconnect's sheet: header of the choice. 1: how many reminders received from the person Keep would keep. 2: their name, such as \"Alex Morgan\".")
                } footer: {
                    if !endedByThem {
                        Text("\(name) gets a note that the connection ended, and chooses what happens to the reminders you sent.", comment: "Disconnect's sheet: under the choice. The argument is the other person's name, such as \"Alex Morgan\".")
                    }
                }
                Section {
                    button
                        .controlSize(.large)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets()) // the button fills the row on a clear background; no text in the row
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !endedByThem {
                    ToolbarItem(placement: .cancellationAction) {
                        DiscardingCancelButton(hasChanges: false)
                    }
                }
            }
        }
        .interactiveDismissDisabled(endedByThem)
        .alert(
            Text("Couldn't Disconnect", comment: "Disconnect's sheet and Connection Ended: title of the message shown when the disconnect couldn't be saved."),
            isPresented: $failed
        ) {
            Button {
            } label: {
                Text("OK", comment: "Disconnect's sheet and Connection Ended: dismisses Couldn't Disconnect.")
            }
        } message: {
            Text("Nothing has changed. Try again.", comment: "Disconnect's sheet and Connection Ended: under Couldn't Disconnect.")
        }
    }

    private func choose() {
        do {
            try onChoose(choice)
        } catch {
            failed = true
        }
    }

    private var title: Text {
        endedByThem
            ? Text("Connection Ended", comment: "The Connection Ended sheet's title: the other person disconnected.")
            : Text("Disconnect from \(name)", comment: "Disconnect's sheet title. The argument is the other person's name, such as \"Alex Morgan\".")
    }

    private var lead: some View {
        Group {
            if endedByThem {
                Text("\(name) ended your connection. You can't send each other reminders until one of you invites the other again.", comment: "The Connection Ended sheet: its first line. The argument is the other person's name, such as \"Alex Morgan\".")
            } else {
                Text("You and \(name) won't be able to send each other reminders until one of you invites the other again.", comment: "Disconnect's sheet: its first line. The argument is the other person's name, such as \"Alex Morgan\".")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var button: some View {
        if endedByThem {
            Button(action: choose) {
                Text("Continue", comment: "The Connection Ended sheet: does the chosen Remove or Keep and closes the sheet.")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(role: .destructive, action: choose) {
                Text("Disconnect", comment: "Disconnect's sheet: ends the connection, doing the chosen Remove or Keep.")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    /// One of the two choices, with a checkmark when it's chosen. VoiceOver reads it as selected,
    /// so the checkmark isn't the only signal.
    private func option(_ value: DisconnectChoice, @ViewBuilder title: () -> Text, @ViewBuilder detail: () -> Text) -> some View {
        Button {
            choice = value
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                    title()
                        .foregroundStyle(Color(uiColor: .label))
                    detail()
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Spacer()
                if choice == value {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(choice == value ? .isSelected : [])
    }
}

extension View {
    /// The other person's Connection Ended sheet (ticket 197), over whatever screen is showing, as
    /// the Connected sheet is: whenever this person's app holds a connection they ended, so when
    /// they next open the app. It can't be closed without choosing. Nothing without a sharing model.
    func connectionEnded(model: AppModel?) -> some View {
        modifier(ConnectionEndedPresenter(model: model))
    }
}

private struct ConnectionEndedPresenter: ViewModifier {
    let model: AppModel?

    func body(content: Content) -> some View {
        // Closed only by the choice, which ends the connection, so the binding never sets it.
        content.sheet(item: .constant(model?.sharing?.endedConnection)) { connection in
            DisconnectSheet(
                name: connection.name,
                keptCount: model?.engine.keptOnDisconnect(from: connection.id) ?? 0,
                endedByThem: true
            ) { choice in
                try model?.disconnect(connection.id, choosing: choice)
            }
        }
    }
}

#if DEBUG
#Preview("Disconnect") {
    DisconnectSheet(name: "Riley Park", keptCount: 2, endedByThem: false) { _ in }
}

#Preview("Connection Ended") {
    DisconnectSheet(name: "Riley Park", keptCount: 2, endedByThem: true) { _ in }
}

#Preview("Disconnect, largest text") {
    DisconnectSheet(name: "Riley Park", keptCount: 1, endedByThem: false) { _ in }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
