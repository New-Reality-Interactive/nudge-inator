import NudgeEngine
import SwiftUI

extension View {
    /// The question that asks before deleting a tag, on a tag's row and on its details page: the
    /// system's confirmation dialog with its title showing, as Apple's own apps ask (#286). From a
    /// tile, iOS 27.0 (simulator) draws a popover with Delete alone: a tap outside it, or
    /// VoiceOver's "Dismiss popup", closes it with nothing deleted. As an action sheet, its Cancel does.
    func deleteTagConfirmation(_ summary: TagSummary, isPresented: Binding<Bool>, delete: @escaping () -> Void) -> some View {
        confirmationDialog(
            Text("Delete \(summary.tag.label)?", comment: "Tags: title of the question that asks before deleting a tag. The placeholder is the tag, such as \"#home\"."),
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button(role: .destructive, action: delete) {
                Text("Delete Tag", comment: "Tags: confirms deleting the tag, as Delete Reminder does for a reminder. The reminders that have it are kept.")
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Keeps the tag instead of deleting it.")
            }
        } message: {
            Text(summary.deleteMessage)
        }
    }
}
