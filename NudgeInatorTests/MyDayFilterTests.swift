import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// My Day's tag filter and chosen count as a value (the mockup's `dayFilter` and `dayStatus`),
/// before any view draws them.
struct MyDayFilterTests {
    let home = Tag(name: "home")
    let money = Tag(name: "money")

    @Test func checkingATagFiltersByItWithMatchAllByDefault() {
        var filter = MyDayFilter()

        filter.toggle(home.id)

        #expect(filter.tagFilter == .matchAll([home.id]))
    }

    @Test func checkingACheckedTagUnchecksItAndNoTagsLeftMeansNoFilter() {
        var filter = MyDayFilter()
        filter.toggle(home.id)
        filter.toggle(money.id)

        filter.toggle(home.id)
        #expect(filter.tagIDs == [money.id])

        filter.toggle(money.id)
        #expect(filter.tagFilter == .off)
    }

    @Test func noTagsUnchecksTheTagsAndCheckingATagUnchecksNoTags() {
        var filter = MyDayFilter()
        filter.toggle(home.id)

        filter.toggleNoTags()
        #expect(filter.tagFilter == .noTags)
        #expect(filter.tagIDs.isEmpty)

        filter.toggle(money.id)
        #expect(filter.tagFilter == .matchAll([money.id]))

        filter.toggleNoTags()
        filter.toggleNoTags()
        #expect(filter.tagFilter == .off)
    }

    @Test func tappingACountChoosesItAndTappingItAgainClearsIt() {
        var filter = MyDayFilter()
        #expect(filter.count == nil)

        filter.tap(.missed)
        #expect(filter.count == .missed)

        filter.tap(.nudging)
        #expect(filter.count == .nudging)

        filter.tap(.nudging)
        #expect(filter.count == nil)
    }

    /// The mockup's Clear starts `dayFilter` afresh and leaves `dayStatus`, the chosen count.
    @Test func clearingTheTagsLeavesTheChosenCountAndMatchGoesBackToAll() {
        var filter = MyDayFilter()
        filter.toggle(home.id)
        filter.toggle(money.id)
        filter.match = .any
        filter.tap(.missed)
        #expect(filter.hasTags)

        filter.clearTags()

        #expect(filter.tagFilter == .off)
        #expect(filter.match == .all)
        #expect(filter.count == .missed)
        #expect(!filter.hasTags)

        filter.toggleNoTags()
        #expect(filter.hasTags)
    }

    @Test func matchAnyFiltersByAnyOfTheCheckedTags() {
        var filter = MyDayFilter()
        filter.toggle(home.id)
        filter.toggle(money.id)

        filter.match = .any

        #expect(filter.tagFilter == .matchAny([home.id, money.id]))
    }
}
