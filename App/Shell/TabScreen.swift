import NudgeEngine
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
                .centeredInReadableColumn()
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
            Text("Your reminders are still on this iPhone, and nudges already scheduled will still come. Unlock your iPhone, then open \(Bundle.appDisplayName) again.",
                 comment: "Explains the unreadable store: nothing is lost, and reopening the app tries again. The placeholder is the app's name.")
        }
    }
}

/// A list row that says a section is empty, in the mockup's secondary, centered style.
struct EmptyRow: View {
    let text: Text

    var body: some View {
        text
            .font(.body)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// The + that opens the New Reminder form, on Now and My Day. Saving it lands back here, so the
/// new reminder shows on the screen the person came from. It is disabled until the store has been
/// read, since the model drops events before then, and without a model (previews, the test host).
struct NewReminderButton: View {
    /// Tags the form opens with chosen: a tag's screen passes its own.
    var tagIDs: [Tag.ID] = []

    @Environment(AppModel.self) private var model: AppModel?
    @State private var form: ReminderForm?

    var body: some View {
        Button {
            if let model { form = ReminderForm(engine: { model.engine }, now: { .now }, tagIDs: tagIDs) }
        } label: {
            Label {
                Text("New Reminder", comment: "Toolbar button (a plus) that opens the New Reminder form.")
            } icon: {
                Image(systemName: "plus")
            }
        }
        .disabled(model == nil || ScreenState(model: model) != .ready)
        .sheet(item: $form) { form in
            ReminderFormSheet(form: form)
        }
    }
}

extension View {
    /// The mockup's subhead under a screen's title: today's date and the like.
    func subheadStyle() -> some View {
        font(.subheadline)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
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
