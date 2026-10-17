import SwiftUI

extension View {
    /// Centers scrolling content in a column at most `Design.Spacing.readableWidth` wide, as
    /// DESIGN.md's "one column on every iPhone". The margins are safe-area padding, not a frame
    /// around the scroll view, so its background runs to the edges, the bars stay in the safe areas, and
    /// scrolling works over the margins. Apply it once around a screen's scrolling content.
    func readableWidth() -> some View {
        modifier(ReadableWidth())
    }
}

private struct ReadableWidth: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.horizontal, max(0, (width - Design.Spacing.readableWidth) / 2))
            // The width inside the safe areas, so the column is centered between the Dynamic Island
            // and the home indicator's side.
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
