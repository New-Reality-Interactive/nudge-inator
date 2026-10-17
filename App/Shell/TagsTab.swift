import SwiftUI

/// Tags, empty: the mockup's No Tags screen. Ticket 29 lists the tags and enables + (New Tag).
struct TagsTab: View {
    let state: ScreenState

    var body: some View {
        NavigationStack {
            TabScreen(state: state) {
                ContentUnavailableView {
                    Label {
                        Text("No Tags", comment: "Tags: title when there are no tags yet.")
                    } icon: {
                        Image(systemName: "tag")
                    }
                } description: {
                    Text("Tap + to add a tag, or add tags to a reminder when you create or edit it.", comment: "Tags: how to add a tag when there are none.")
                }
            }
            .navigationTitle(Text(AppTab.tags.title))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                    } label: {
                        Label {
                            Text("New Tag", comment: "Toolbar button (a plus) on Tags that adds a tag.")
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    // The New Tag sheet comes with tag creation in a later ticket.
                    .disabled(true)
                }
            }
        }
    }
}

#Preview("Light") {
    TagsTab(state: .ready)
}

#Preview("Dark") {
    TagsTab(state: .ready)
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    TagsTab(state: .ready)
        .environment(\.dynamicTypeSize, .accessibility5)
}
