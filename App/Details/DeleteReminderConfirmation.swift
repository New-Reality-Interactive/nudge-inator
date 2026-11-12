import SwiftUI

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
    func deleteReminderConfirmation(title: String, isReceived: Bool = false, isPresented: Binding<Bool>, confirm: @escaping () -> Void) -> some View {
        confirmationDialog(
            isReceived
                ? Text("Remove “\(title)”?", comment: "Asked before removing a received reminder, from its details or a Reminders tab row. The placeholder is its title.")
                : Text("Delete “\(title)”?", comment: "Asked before deleting a reminder, from its details or a Reminders tab row. The placeholder is its title."),
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
            isReceived
                ? Text("This removes your copy and cancels its nudges and alarms.", comment: "Under the question asked before removing a received reminder.")
                : Text("This deletes its history too, and cancels any nudges and alarms.", comment: "Under the question asked before deleting a reminder.")
        }
    }
}
