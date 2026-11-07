import SwiftUI

extension View {
    /// Asks before a reminder is deleted, in the same words wherever Delete is: the details page
    /// and a Reminders tab row. `confirm` runs only when the person chooses Delete Reminder;
    /// Cancel changes nothing.
    ///
    /// An alert, not a confirmation dialog: on iOS 26 a dialog from a button is a popover with no
    /// Cancel, so VoiceOver offered only Delete Reminder, and a double-tap meant to dismiss it
    /// deleted the reminder (#276).
    func deleteReminderConfirmation(title: String, isPresented: Binding<Bool>, confirm: @escaping () -> Void) -> some View {
        alert(
            Text("Delete “\(title)”?", comment: "Asked before deleting a reminder, from its details or a Reminders tab row. The placeholder is its title."),
            isPresented: isPresented
        ) {
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Keeps the reminder instead of deleting it.")
            }
            Button(role: .destructive, action: confirm) {
                Text("Delete Reminder", comment: "Confirms deleting the reminder.")
            }
        } message: {
            Text("This deletes its history too, and cancels any nudges and alarms.", comment: "Under the question asked before deleting a reminder.")
        }
    }
}
