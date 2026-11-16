import SwiftUI

/// DESIGN.md's `swipe-done`: a trailing swipe action on a green tile, with a white `checkmark`
/// and its word. The caller gives the word, so each screen keeps its own string comment.
struct SwipeDoneTile: View {
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label { label } icon: { Image(systemName: "checkmark") }
        }
        .tint(Color.tileGreen)
    }
}

/// DESIGN.md's `swipe-delete`: a trailing swipe action on a red tile, with a white `trash` and
/// its word. No destructive role: Delete asks first, and the row stays until the person confirms.
struct SwipeDeleteTile: View {
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label { label } icon: { Image(systemName: "trash") }
        }
        .tint(Color.tileRed)
    }
}

/// DESIGN.md's `swipe-edit`: a trailing swipe action on a blue tile, with a white `pencil` and its
/// word.
struct SwipeEditTile: View {
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label { label } icon: { Image(systemName: "pencil") }
        }
        .tint(Color.tileBlue)
    }
}

/// One of a list row's trailing actions (DESIGN.md, Swipe actions): its tile in the swipe, and the
/// same action among the row's VoiceOver actions.
struct RowAction: Identifiable {
    enum Kind: Hashable {
        case done
        case edit
        case delete
    }

    let kind: Kind
    let label: Text
    let action: () -> Void
    /// What VoiceOver's action does instead, when it must say more than the tile: Done's announcement.
    var voiceOverAction: (() -> Void)?

    var id: Kind { kind }
}

extension View {
    /// The Reminders and Tags tabs' row actions (#429): a trailing swipe with the tiles in `actions`'
    /// order from the edge, no full swipe and nothing on the leading edge (ADR 0001), and the same
    /// actions, in the same order, as the row's VoiceOver actions. The tiles are left out while
    /// VoiceOver runs: it lists a row's swipe actions among its actions (My Day's rows showed it on
    /// the phone), so each would be offered twice.
    func rowActions(_ actions: [RowAction]) -> some View {
        modifier(RowActionsModifier(actions: actions))
    }
}

private struct RowActionsModifier: ViewModifier {
    let actions: [RowAction]

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    func body(content: Content) -> some View {
        content
            .accessibilityActions {
                ForEach(actions) { action in
                    Button(action: action.voiceOverAction ?? action.action) { action.label }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !voiceOverEnabled {
                    ForEach(actions) { action in
                        tile(action)
                    }
                }
            }
    }

    @ViewBuilder private func tile(_ action: RowAction) -> some View {
        switch action.kind {
        case .done: SwipeDoneTile(label: action.label, action: action.action)
        case .edit: SwipeEditTile(label: action.label, action: action.action)
        case .delete: SwipeDeleteTile(label: action.label, action: action.action)
        }
    }
}

#if DEBUG
#Preview("Swipe tiles") {
    List {
        Text(verbatim: "Swipe left")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                SwipeDoneTile(label: Text(verbatim: "Done"), action: {})
                SwipeDeleteTile(label: Text(verbatim: "Delete"), action: {})
            }
        Text(verbatim: "Swipe a tag")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                SwipeEditTile(label: Text(verbatim: "Edit"), action: {})
                SwipeDeleteTile(label: Text(verbatim: "Delete"), action: {})
            }
    }
}
#endif
