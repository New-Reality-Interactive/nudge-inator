import SwiftUI

/// Whose reminder Delete asks about, which sets its words.
enum DeletedReminderKind {
    /// The person's own.
    case own
    /// A copy they received (ticket 200): Remove.
    case received
    /// One they sent to others (ticket 201).
    case sent

    init(isReceived: Bool) {
        self = isReceived ? .received : .own
    }
}

extension View {
    /// Asks before a reminder is deleted, in the same words wherever Delete is: the details page
    /// and a Reminders tab row. `confirm` runs only when the person chooses Delete Reminder.
    ///
    /// The system's confirmation dialog with its title showing, as Apple's own apps ask (#286).
    /// iOS draws it as a popover with Delete Reminder alone (seen on the iOS 27.0 simulator, from
    /// a button and from a swipe tile): a tap outside it, or VoiceOver's "Dismiss popup", closes it
    /// and deletes nothing. Where iOS draws an action sheet instead, its Cancel does the same.
    ///
    /// A received reminder asks to Remove it instead (ticket 200, the mockup's `removeReceived`): it
    /// is the person's copy that goes. The mockup's "<name> sees it as Removed." waits for the
    /// status tickets, which send Removed.
    ///
    /// A sent reminder's (ticket 201, the mockup's `deleteSent`) says it's canceled on everyone's
    /// iPhone; what the copies do with the cancel is #205's.
    func deleteReminderConfirmation(title: String, kind: DeletedReminderKind, isPresented: Binding<Bool>, confirm: @escaping () -> Void) -> some View {
        let isReceived = kind == .received
        return confirmationDialog(
            isReceived
                ? Text("Remove “\(title)”?", comment: "Asked before removing a received reminder, from its details or a Reminders tab row. The placeholder is its title.")
                : Text("Delete “\(title)”?", comment: "Asked before deleting a reminder, from its details, a Reminders tab row, or a sent reminder's details. The placeholder is its title."),
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button(role: .destructive, action: confirm) {
                isReceived
                    ? Text("Remove Reminder", comment: "Confirms removing the person's copy of a received reminder.")
                    : Text("Delete Reminder", comment: "Confirms deleting the reminder.")
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Keeps the reminder instead of deleting it.")
            }
        } message: {
            switch kind {
            case .sent:
                Text("It's canceled on everyone's iPhone, with a note saying so.", comment: "Under the question asked before deleting a reminder this person sent to others.")
            case .received:
                Text("This removes your copy and cancels its nudges and alarms.", comment: "Under the question asked before removing a received reminder.")
            case .own:
                Text("This deletes its history too, and cancels any nudges and alarms.", comment: "Under the question asked before deleting a reminder.")
            }
        }
    }
}
