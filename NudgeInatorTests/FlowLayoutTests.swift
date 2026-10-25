import CoreGraphics
import Testing
@testable import NudgeInator

/// How many of My Day's filter tokens show within three rows, before "+N more" (ticket 20). Rows are
/// 100 pt wide with 10 pt between items, so two 45 pt tokens fill one.
struct FlowLayoutTests {
    @Test func everyTokenShowsWhenAllFitInTheRows() {
        #expect(FlowLayout(spacing: 10).shownCount(widths: [40, 40, 40, 40], moreWidth: 30, in: 100, maxRows: 3) == 4)
    }

    @Test func moreTakesTheLastRowsSpaceFromItsLastTokens() {
        let widths: [CGFloat] = Array(repeating: 45, count: 8)
        #expect(FlowLayout(spacing: 10).shownCount(widths: widths, moreWidth: 30, in: 100, maxRows: 3) == 5)
    }

    /// At the largest text size a token can fill a row. Then the third row keeps its token, and
    /// "+N more" goes below it, so three tags still show.
    @Test func moreGoesOnItsOwnRowRatherThanEmptyingTheLastRow() {
        let widths: [CGFloat] = Array(repeating: 100, count: 6)
        #expect(FlowLayout(spacing: 10).shownCount(widths: widths, moreWidth: 30, in: 100, maxRows: 3) == 3)
    }
}
