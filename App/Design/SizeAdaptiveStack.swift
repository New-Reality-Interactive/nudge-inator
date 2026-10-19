import SwiftUI

/// Content in a row, stacked in a column at accessibility text sizes, where beside each other the
/// pieces would leave a few letters of width.
struct SizeAdaptiveStack<Content: View>: View {
    var rowAlignment: VerticalAlignment = .center
    var rowSpacing: CGFloat?
    var stackedSpacing: CGFloat?
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: stackedSpacing))
            : AnyLayout(HStackLayout(alignment: rowAlignment, spacing: rowSpacing))
        layout { content }
    }
}
