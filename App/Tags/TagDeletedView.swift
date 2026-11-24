import SwiftUI

/// What both of a tag's pages show once the tag is gone: its details page and its reminders.
struct TagDeletedView: View {
    var body: some View {
        ContentUnavailableView {
            EmptyStateLabel(systemImage: "tag.slash") {
                Text("Tag Deleted", comment: "A tag's details page and its reminders page after the tag was deleted.")
            }
        } description: {
            Text("This tag was deleted. Its reminders are still there.", comment: "A tag's details page and its reminders page after the tag was deleted.")
        }
    }
}
