import SwiftUI

/// A sheet's Cancel (`xmark`): it closes the sheet, asking first while there are changes to lose.
/// A sheet with changes also disables interactive dismissal, so a swipe can't lose them. The
/// system draws the dialog as a popover with Discard Changes alone: a tap outside it is Keep Editing.
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
        .confirmationDialog(Text("Discard your changes?", comment: "Asked when cancelling a sheet with changes: the reminder form or the Reminders filter."),
                            isPresented: $isConfirming, titleVisibility: .hidden) {
            Button(role: .destructive) {
                dismiss()
            } label: {
                Text("Discard Changes", comment: "Throws away a sheet's changes and closes it.")
            }
            Button(role: .cancel) {
            } label: {
                Text("Keep Editing", comment: "Goes back to a sheet without discarding its changes.")
            }
        }
    }
}
