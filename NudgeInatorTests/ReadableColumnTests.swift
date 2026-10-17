import CoreGraphics
import Testing
@testable import NudgeInator

/// The side margin that centers content in DESIGN.md's 672 pt readable column.
struct ReadableColumnTests {
    /// Width available between the safe areas -> margin each side, worked by hand from 672.
    @Test(arguments: [
        (CGFloat(772), CGFloat(50)),
        (CGFloat(750), CGFloat(39)),
        (CGFloat(672), CGFloat(0)),
        (CGFloat(402), CGFloat(0)),
    ])
    func theMarginLeavesTheColumnAt672(available: CGFloat, margin: CGFloat) {
        #expect(ReadableColumn.margin(availableWidth: available) == margin)
    }
}
