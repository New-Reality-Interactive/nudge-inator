import SwiftUI

extension View {
    /// Asks before a reminder is deleted, in the same words wherever Delete is: the details page
    /// and a Reminders tab row. `confirm` runs only when the person chooses Delete Reminder;
    /// Cancel changes nothing.
    func deleteReminderConfirmation(title: String, isPresented: Binding<Bool>, confirm: @escaping () -> Void) -> some View {
        confirmationDialog(
            Text("Delete “\(title)”?", comment: "Asked before deleting a reminder, from its details or a Reminders tab row. The placeholder is its title."),
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button(role: .destructive, action: confirm) {
                Text("Delete Reminder", comment: "Confirms deleting the reminder.")
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Keeps the reminder instead of deleting it.")
            }
        } message: {
            Text("This deletes its history too, and cancels any nudges and alarms.", comment: "Under the question asked before deleting a reminder.")
        }
    }
}
