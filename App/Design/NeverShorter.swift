import SwiftUI

/// Keeps a filter sheet's list from getting shorter while it is open (ticket 23). A tap that
/// shortens the text under the tags, such as No Tags dropping the Match explanation, would otherwise
/// make a list scrolled to its end scroll back, moving every row under the finger. Blank space at
/// the end makes up the difference. A new width, from turning the phone, or a new text size starts
/// again.
struct NeverShorter {
    private var width: CGFloat = 0
    private var tallest: CGFloat = 0
    private(set) var extra: CGFloat = 0

    /// `height` is the list's content height, `extra` included.
    mutating func update(width: CGFloat, height: CGFloat) {
        let natural = height - extra
        if width != self.width {
            self.width = width
            tallest = natural
        }
        tallest = max(tallest, natural)
        extra = tallest - natural
    }
}

extension View {
    /// Measures the list this modifies. Its last section adds `height.extra` as padding at its end.
    func neverShorter(_ height: Binding<NeverShorter>) -> some View {
        modifier(NeverShorterMeasure(height: height))
    }
}

private struct NeverShorterMeasure: ViewModifier {
    @Binding var height: NeverShorter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGSize.self) { geometry in
                CGSize(width: geometry.containerSize.width, height: geometry.contentSize.height)
            } action: { _, size in
                height.update(width: size.width, height: size.height)
            }
            .onChange(of: dynamicTypeSize) {
                height = NeverShorter()
            }
    }
}
