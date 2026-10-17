import SwiftUI

/// One tab's content for its screen state: a spinner while the store is read, a message when it
/// can't be, otherwise the tab's own content.
struct TabScreen<Content: View>: View {
    let state: ScreenState
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .storeUnreadable:
            StoreUnreadableView()
        case .ready:
            content()
        }
    }
}

/// Ticket 21 leaves the store alone when it can't be read, and App opened tries again, so this
/// says that nothing is lost and what to do.
struct StoreUnreadableView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Can't Open Your Reminders", comment: "Title shown when the app can't read its stored reminders, for example before the first unlock after a restart.")
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
        } description: {
            Text("Your reminders are still on this iPhone, and nudges already scheduled will still come. Unlock your iPhone, then open Nudge-inator again.",
                 comment: "Explains the unreadable store: nothing is lost, and reopening the app tries again.")
        }
    }
}

/// A list row that says a section is empty, in the mockup's secondary, centered style.
struct EmptyRow: View {
    let text: Text

    var body: some View {
        text
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// The + that opens the New Reminder form, disabled until that form exists (ticket 24).
struct NewReminderButton: View {
    var body: some View {
        Button {
        } label: {
            Label {
                Text("New Reminder", comment: "Toolbar button (a plus) that opens the New Reminder form.")
            } icon: {
                Image(systemName: "plus")
            }
        }
        .disabled(true)
    }
}

#Preview("Unreadable store") {
    NavigationStack {
        TabScreen(state: .storeUnreadable) { EmptyView() }
            .navigationTitle(Text(AppTab.now.title))
    }
}

#Preview("Loading") {
    TabScreen(state: .loading) { EmptyView() }
}
