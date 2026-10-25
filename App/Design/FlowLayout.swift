import SwiftUI

/// Lays its subviews out in rows left to right and wraps to a new row when one doesn't fit, as the
/// mockup's wrapping `.tokens`. Rows align to the leading edge.
struct FlowLayout: Layout {
    var spacing: CGFloat = Design.Spacing.controlGap

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = arrange(in: bounds.width, subviews: subviews)
        for (subview, (origin, size)) in zip(subviews, zip(placed.origins, placed.sizes)) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: ProposedViewSize(size))
        }
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], sizes: [CGSize], size: CGSize) {
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            // An item wider than the row gets the row's width, so its text wraps instead of the layout
            // running past the screen's edge (a long tag at the largest text size, ticket 20).
            var size = subview.sizeThatFits(.unspecified)
            if size.width > width {
                size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            }
            if Self.startsRow(at: x, itemWidth: size.width, in: width) {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            sizes.append(size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, sizes, CGSize(width: widest, height: y + rowHeight))
    }

    /// How many of the items, with these widths, show in at most `maxRows` rows when the rest go
    /// into a "+N more" item after them, `moreWidth` wide (My Day's filter tokens, ticket 20). The
    /// more item takes the last row's space from its last items, but never its only one: then it
    /// goes on a row of its own, so `maxRows` rows of items still show.
    func shownCount(widths: [CGFloat], moreWidth: CGFloat, in width: CGFloat, maxRows: Int) -> Int {
        func rows(_ widths: some Sequence<CGFloat>) -> Int {
            var rows = 0
            var x: CGFloat = 0
            for itemWidth in widths {
                if rows == 0 || Self.startsRow(at: x, itemWidth: itemWidth, in: width) {
                    rows += 1
                    x = 0
                }
                x += itemWidth + spacing
            }
            return rows
        }
        var shown = widths.count
        while shown > 0, rows(widths.prefix(shown)) > maxRows { shown -= 1 }
        guard shown < widths.count else { return shown }
        while shown > 0 {
            if rows(widths.prefix(shown) + [moreWidth]) <= maxRows { return shown }
            if rows(widths.prefix(shown - 1)) < maxRows { return shown }
            shown -= 1
        }
        return 0
    }

    /// An item that would run past the row's end starts the next row, unless it's the row's first.
    private static func startsRow(at x: CGFloat, itemWidth: CGFloat, in width: CGFloat) -> Bool {
        x > 0 && x + itemWidth > width
    }
}
