import SwiftUI

enum ReadableColumn {
    /// The margin on each side that leaves `Design.Spacing.readableWidth` for content, given the
    /// width between the safe areas. Zero when there is no room to spare.
    static func margin(availableWidth: CGFloat) -> CGFloat {
        max(0, (availableWidth - Design.Spacing.readableWidth) / 2)
    }
}

extension View {
    /// Centers scrolling content in a column at most `Design.Spacing.readableWidth` wide, as
    /// DESIGN.md's "one column on every iPhone". The margins are safe-area padding, not a frame
    /// around the scroll view, so its background runs to the edges, the bars stay in the safe areas,
    /// and scrolling works over the margins. Apply it once around a screen's scrolling content.
    func centeredInReadableColumn() -> some View {
        modifier(CenteredInReadableColumn())
    }
}

private struct CenteredInReadableColumn: ViewModifier {
    @State private var margin: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.horizontal, margin)
            // The view's size is already inside the safe areas (a 750 pt wide landscape iPhone 17
            // reports 62 pt insets on each side), and the padding adds to those insets without
            // changing the size, so it can't feed back into the measurement.
            .onGeometryChange(for: CGFloat.self) {
                ReadableColumn.margin(availableWidth: $0.size.width)
            } action: {
                margin = $0
            }
    }
}
