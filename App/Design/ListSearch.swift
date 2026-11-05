import SwiftUI

/// The search field under the title of the Reminders and Tags lists, while there's anything to
/// search: each tab's empty state for having nothing has none, as the mockups draw it. The bar stays
/// during a search, so its buttons, and a Filter button's badge, stay on screen (Brian's call, #113).
struct ListSearchField: ViewModifier {
    let isShown: Bool
    @Binding var text: String
    let prompt: Text

    func body(content: Content) -> some View {
        if isShown {
            content
                .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
                .searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
    }
}

/// A searchable list whose no-match state has a clear button, and what that button and the search's
/// Cancel do once the list's narrowing has been cleared. Each asks VoiceOver to go to the count, and
/// a clear button also ends the search and makes a new list. Cancel's request lands. A clear button's
/// doesn't: iOS puts VoiceOver on the bar's first button, on the iPhone in #141, and Brian accepted
/// that. `list` gets the closure a clear button calls after clearing. Inside the `searchable` view,
/// which is where `isSearching` is set.
struct SearchResultsContainer<ListContent: View>: View {
    /// Goes to the count, which reads the result itself.
    let countFocus: AccessibilityFocusState<Bool>.Binding
    @ViewBuilder let list: (_ didClear: @escaping () -> Void) -> ListContent

    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.isSearching) private var isSearching
    /// Each clear button's tap makes a new list, which starts at its top.
    @State private var listIdentity = 0
    /// A clear button was tapped during a search, so the new list waits for that search to end.
    @State private var isClearing = false

    var body: some View {
        list {
            // Where the keyboard or large text meant scrolling to the button, the rows come back
            // with the count off screen otherwise. A new list rather than `scrollTo`: at the
            // accessibility sizes, no anchor reached the top (#135). During a search it waits for
            // the search to end, and the title's return.
            if isSearching { isClearing = true } else { makeNewList() }
            // Ends the search too, if it's still active, so Cancel and the keyboard go with its text.
            dismissSearch()
            countFocus.wrappedValue = true
        }
        .id(listIdentity)
        .transition(.identity)
        // Cancel moves VoiceOver to the bar's New button, which cut the count's announcement off (seen
        // on the iPhone in #112), so it goes to the count, as Clear Search does.
        .onChange(of: isSearching) {
            guard !isSearching else { return }
            if isClearing {
                isClearing = false
                makeNewList()
            }
            countFocus.wrappedValue = true
        }
    }

    /// With no animation or transition, so the rows are simply there, as a filter redraws them.
    /// Animated, UI tests waited out "animations complete" timeouts on iOS 26.5 too. On iOS 27.0 some
    /// runs still do, with the app idle and nothing wrong on the iPhone (#135's Comments).
    private func makeNewList() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { listIdentity += 1 }
    }
}
