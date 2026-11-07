import SwiftUI

/// A sheet's Cancel (`xmark`): it closes the sheet, asking first while there are changes to lose.
/// A sheet with changes also disables interactive dismissal, so a swipe can't lose them.
///
/// The question is the system's confirmation dialog, with its title showing, as Calendar asks when
/// a new event is cancelled (iOS 27, #278). From the button iOS draws it as a popover with Discard
/// Changes alone: a tap outside it, or VoiceOver's "Dismiss popup", closes it and keeps the changes.
/// Where iOS draws an action sheet instead, its Cancel does the same.
struct DiscardingCancelButton: View {
    let hasChanges: Bool

    @State private var isConfirming = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(role: .cancel) {
            if hasChanges { isConfirming = true } else { dismiss() }
        } label: {
            Label {
                Text("Cancel", comment: "A sheet's cancel button (an xmark): the reminder form's and the Reminders and Tags filters'.")
            } icon: {
                Image(systemName: "xmark")
            }
        }
        .confirmationDialog(Text("Are you sure you want to discard these changes?", comment: "Asked when cancelling a sheet with changes: the reminder form, or the Reminders or Tags filter."),
                            isPresented: $isConfirming, titleVisibility: .visible) {
            Button(role: .destructive) {
                dismiss()
            } label: {
                Text("Discard Changes", comment: "Throws away a sheet's changes and closes it.")
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Closes the discard question and goes back to the sheet with its changes.")
            }
        }
    }
}
