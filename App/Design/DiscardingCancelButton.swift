import SwiftUI

/// A sheet's Cancel (`xmark`): it closes the sheet, asking first while there are changes to lose.
/// A sheet with changes also disables interactive dismissal, so a swipe can't lose them.
///
/// The question is an alert, not a confirmation dialog: on iOS 26 a dialog from a button is a
/// popover with Discard Changes alone, so VoiceOver offered no Keep Editing, and a double-tap meant
/// to get out of it threw the changes away (#278, as #276 found for Delete Reminder).
struct DiscardingCancelButton: View {
    let hasChanges: Bool

    @State private var isConfirming = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(role: .cancel) {
            if hasChanges { isConfirming = true } else { dismiss() }
        } label: {
            Label {
                Text("Cancel", comment: "A sheet's cancel button (an xmark): the reminder form's and the Reminders filter's.")
            } icon: {
                Image(systemName: "xmark")
            }
        }
        .alert(Text("Discard your changes?", comment: "Asked when cancelling a sheet with changes: the reminder form, or the Reminders or Tags filter."),
               isPresented: $isConfirming) {
            Button(role: .cancel) {
            } label: {
                Text("Keep Editing", comment: "Goes back to a sheet without discarding its changes.")
            }
            Button(role: .destructive) {
                dismiss()
            } label: {
                Text("Discard Changes", comment: "Throws away a sheet's changes and closes it.")
            }
        }
    }
}
