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

#if DEBUG
#Preview("Swipe tiles") {
    List {
        Text(verbatim: "Swipe left")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                SwipeDoneTile(label: Text(verbatim: "Done"), action: {})
                SwipeDeleteTile(label: Text(verbatim: "Delete"), action: {})
            }
    }
}
#endif
