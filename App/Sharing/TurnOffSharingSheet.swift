import NudgeEngine
import SwiftUI

/// Turning Settings' Sharing switch off while it would delete anything: a connection, an invite, a
/// reminder sent or received (#388), the Turn Off Sharing mockup's `sharingOffSheet`: what goes, then Disconnect's
/// Remove or Keep choice asked once for everyone, shown only when something was received, and the
/// note the other people get, only while someone is connected. A sheet, as Disconnect's is, so
/// Remove shows as the default. The X cancels, and Sharing stays on with nothing changed.
struct TurnOffSharingSheet: View {
    let summary: SharingOffSummary
    /// Turns Sharing off with the choice. Throws if it couldn't be kept: the sheet then stays, says
    /// so, and the person can try again.
    let onConfirm: (DisconnectChoice) throws -> Void

    @State private var choice = DisconnectChoice.remove
    @State private var failed = false

    /// With something received the note belongs under the choice; otherwise under the first line.
    private var hasChoice: Bool { summary.received > 0 }

    var body: some View {
        NavigationStack {
            List {
                leadSection
                if hasChoice {
                    choiceSection
                }
                Section {
                    Button(role: .destructive, action: confirm) {
                        Text("Turn Off Sharing", comment: "Turn Off Sharing's sheet: its title, and the button that disconnects everyone and turns Sharing off.")
                            .foregroundStyle(Color.onAccent)
                            .frame(maxWidth: .infinity)
                    }
                    // DESIGN.md's `button-destructive`: filled, as red text on gray read as dimmed (#402).
                    .buttonStyle(.borderedProminent)
                    .tint(Color.negative)
                    .controlSize(.large)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets()) // the button fills the row on a clear background; no text in the row
            }
            .navigationTitle(Text("Turn Off Sharing", comment: "Turn Off Sharing's sheet: its title, and the button that disconnects everyone and turns Sharing off."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DiscardingCancelButton(hasChanges: false)
                }
            }
        }
        .alert(
            Text("Couldn't Turn Off Sharing", comment: "Settings and Turn Off Sharing's sheet: title of the message shown when turning Sharing off couldn't be saved."),
            isPresented: $failed
        ) {
            Button {
            } label: {
                Text("OK", comment: "Settings and Turn Off Sharing's sheet: dismisses Couldn't Turn Off Sharing.")
            }
        } message: {
            Text("Nothing has changed. Try again.", comment: "Settings and Turn Off Sharing's sheet: under Couldn't Turn Off Sharing.")
        }
    }

    private func confirm() {
        do {
            try onConfirm(choice)
        } catch {
            failed = true
        }
    }

    /// What goes, and the note under it when there's no choice to put it under.
    @ViewBuilder
    private var leadSection: some View {
        if !hasChoice, summary.connected > 0 {
            Section {
                lead.listRowBackground(Color.clear)
            } footer: {
                note
            }
        } else {
            Section {
                lead.listRowBackground(Color.clear)
            }
        }
    }

    /// Disconnect's Remove or Keep, asked once for everyone, and the note under it.
    private var choiceSection: some View {
        Section {
            DisconnectChoiceOption(value: .remove, choice: $choice) {
                Text("Remove", comment: "Disconnect's and Turn Off Sharing's sheets: the choice that deletes the reminders received.")
            } detail: {
                Text("Deletes them and cancels their nudges and alarms.", comment: "Disconnect's and Turn Off Sharing's sheets: under Remove.")
            }
            DisconnectChoiceOption(value: .keepAsMyOwnReminders, choice: $choice) {
                Text("Keep as My Own Reminders", comment: "Disconnect's and Turn Off Sharing's sheets: the choice that keeps the reminders received as this person's own.")
            } detail: {
                Text("They stay with the same schedule, history and tags, from no one.", comment: "Turn Off Sharing's sheet: under Keep as My Own Reminders.")
            }
        } header: {
            Text("\(summary.received) Reminders You've Received", comment: "Turn Off Sharing's sheet: header of the Remove or Keep choice. The argument is how many reminders this person has received from everyone.")
        } footer: {
            if summary.connected > 0 {
                note
            }
        }
    }

    /// "This disconnects you from 2 people and cancels 2 invites.", either part left out at 0: one
    /// whole sentence for each case, so a translation can agree its words with both counts.
    private var lead: some View {
        Group {
            switch (summary.connected > 0, summary.invited > 0) {
            case (true, true):
                Text("This disconnects you from \(summary.connected) people and cancels \(summary.invited) invites. You won't be able to send or receive reminders, and your Sent list and its history are deleted.", comment: "Turn Off Sharing's sheet: its first line. 1: how many people it disconnects you from. 2: how many open invites it cancels.")
            case (true, false):
                Text("This disconnects you from \(summary.connected) people. You won't be able to send or receive reminders, and your Sent list and its history are deleted.", comment: "Turn Off Sharing's sheet: its first line, with no open invites. The argument is how many people it disconnects you from.")
            case (false, true):
                Text("This cancels \(summary.invited) invites. You won't be able to send or receive reminders, and your Sent list and its history are deleted.", comment: "Turn Off Sharing's sheet: its first line, with no one connected. The argument is how many open invites it cancels.")
            case (false, false):
                Text("You won't be able to send or receive reminders, and your Sent list and its history are deleted.", comment: "Turn Off Sharing's sheet: its first line, with no one connected or invited, only reminders sent or received.")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var note: some View {
        Text("Everyone you're connected with gets a note that the connection ended, and chooses what happens to the reminders you sent them.", comment: "Turn Off Sharing's sheet: under the choice, while someone is connected.")
    }
}

#if DEBUG
#Preview("Connected, invited and received") {
    TurnOffSharingSheet(summary: SharingOffSummary(connected: 2, invited: 2, received: 5)) { _ in }
}

#Preview("Invites only") {
    TurnOffSharingSheet(summary: SharingOffSummary(connected: 0, invited: 1, received: 0)) { _ in }
}

#Preview("Largest text") {
    TurnOffSharingSheet(summary: SharingOffSummary(connected: 1, invited: 1, received: 1)) { _ in }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
