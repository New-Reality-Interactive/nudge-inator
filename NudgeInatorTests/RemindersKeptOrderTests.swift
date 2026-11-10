import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A chosen tab, sorted oldest first, unfiltered, and ready, unless said otherwise.
private func inputs(
    isChosen: Bool = true,
    sort: RemindersSort = .createdOldestFirst,
    filter: RemindersFilter = RemindersFilter(),
    state: ScreenState = .ready
) -> RemindersKeptOrder.Inputs {
    RemindersKeptOrder.Inputs(isChosen: isChosen, sort: sort, filter: filter, state: state)
}

/// One row per change the tab can see, and whether it keeps the order again.
private let refreshCases: [(RemindersKeptOrder.Change, Bool)] = [
    (.appeared(inputs(isChosen: true, sort: .createdOldestFirst, filter: RemindersFilter(), state: .ready)), true),
    (.appeared(inputs(isChosen: false, sort: .createdOldestFirst, filter: RemindersFilter(), state: .loading)), true),
    // The tab is chosen.
    (.changed(from: inputs(isChosen: false), to: inputs(isChosen: true)), true),
    // Chosen again with nothing else changed, and not chosen to chosen only.
    (.changed(from: inputs(isChosen: true), to: inputs(isChosen: true)), false),
    // Leaving the tab keeps the order it has, so coming back is what sorts again.
    (.changed(from: inputs(isChosen: true), to: inputs(isChosen: false)), false),
    (.changed(from: inputs(isChosen: false), to: inputs(isChosen: false)), false),
    // The sort, the filter and the screen state, whichever tab is chosen.
    (.changed(from: inputs(), to: inputs(sort: RemindersSort(field: .dueDate, order: .ascending))), true),
    (.changed(from: inputs(isChosen: false), to: inputs(isChosen: false, sort: RemindersSort(field: .dueDate, order: .ascending))), true),
    (.changed(from: inputs(), to: inputs(filter: RemindersFilter(statuses: [.nudging]))), true),
    (.changed(from: inputs(), to: inputs(filter: RemindersFilter(search: "meds"))), true),
    (.changed(from: inputs(state: .loading), to: inputs(state: .ready)), true),
    (.changed(from: inputs(state: .ready), to: inputs(state: .storeUnreadable)), true),
    // Nothing changed.
    (.changed(from: inputs(), to: inputs()), false),
]

/// The Reminders tab's kept order (spec #104, Decision 35; ticket 325): which changes of the tab's
/// inputs keep the order again, and what the kept order holds, with no view. The sequences read the
/// real app model on ticket 16's fixture, as `RemindersScreenTests` does.
@MainActor
struct RemindersKeptOrderTests {
    let fixture = MyDayScreenTests()
    let byCreation = RemindersSort.createdOldestFirst
    let byDueDate = RemindersSort(field: .dueDate, order: .ascending)
    let noFilter = RemindersFilter()

    /// What the tab reads the order from: the screen as it sorts now.
    func read(_ day: MyDayScreenTests.Day) -> (RemindersSort, RemindersFilter) -> RemindersScreen? {
        { sort, filter in RemindersScreen(engine: day.model.engine, sort: sort, filter: filter) }
    }

    // MARK: The refresh rule

    /// One row per change the tab can see. Only these keep the order again.
    @Test(arguments: refreshCases)
    func onlyTheseChangesKeepTheOrderAgain(change: RemindersKeptOrder.Change, refreshes: Bool) {
        #expect(RemindersKeptOrder.refreshes(change) == refreshes)
    }

    // MARK: The kept order

    @Test func beforeAnyOrderIsKeptThereIsNoneToShow() {
        #expect(RemindersKeptOrder().ids(for: byCreation, filter: noFilter) == nil)
    }

    @Test func theOrderKeptIsTheRowsTheScreenShows() async throws {
        let day = try await fixture.dayAtOnePM()
        let filter = RemindersFilter(statuses: [.nudging])
        var order = RemindersKeptOrder()

        order.respond(to: .appeared(inputs(sort: byDueDate, filter: filter)), reading: read(day))

        let shown = RemindersScreen(engine: day.model.engine, sort: byDueDate, filter: filter).rows.map(\.id)
        #expect(order.ids(for: byDueDate, filter: filter) == shown)
    }

    @Test func aSortOrAFilterThatIsNotTheKeptOnesGetsNoOrder() async throws {
        let day = try await fixture.dayAtOnePM()
        var order = RemindersKeptOrder()
        order.respond(to: .appeared(inputs(sort: byDueDate)), reading: read(day))

        #expect(order.ids(for: byDueDate, filter: noFilter) != nil)
        #expect(order.ids(for: byCreation, filter: noFilter) == nil)
        #expect(order.ids(for: byDueDate, filter: RemindersFilter(statuses: [.nudging])) == nil)
        #expect(order.ids(for: byDueDate, filter: RemindersFilter(search: "meds")) == nil)
    }

    @Test func aChangeThatDoesNotKeepTheOrderAgainLeavesTheKeptOneAlone() async throws {
        let day = try await fixture.dayAtOnePM()
        var order = RemindersKeptOrder()
        order.respond(to: .appeared(inputs(sort: byDueDate)), reading: read(day))
        let kept = order.ids(for: byDueDate, filter: noFilter)
        day.model.delete(day.dentist.id)

        order.respond(to: .changed(from: inputs(sort: byDueDate), to: inputs(isChosen: false, sort: byDueDate)), reading: read(day))

        #expect(order.ids(for: byDueDate, filter: noFilter) == kept)
    }

    @Test func withNoScreenToReadTheOrderIsLost() async throws {
        let day = try await fixture.dayAtOnePM()
        var order = RemindersKeptOrder()
        order.respond(to: .appeared(inputs()), reading: read(day))

        order.respond(to: .appeared(inputs())) { _, _ in nil }

        #expect(order.ids(for: byCreation, filter: noFilter) == nil)
    }

    // MARK: Sequences

    /// At 6:31 the next morning Morning meds is Nudging, due 6:30 today. Sorted by Due Date, Done
    /// moves its due time to tomorrow. The sort is changed first, Done doesn't move the row, leaving
    /// the tab doesn't either, and choosing it again sorts again.
    @Test func aSortChangeThenDoneThenChoosingTheTabAgain() async throws {
        let day = try await fixture.dayAtOnePM()
        fixture.clock.now = NewYork.local(2026, 10, 17, 6, 31)
        var order = RemindersKeptOrder()
        order.respond(to: .appeared(inputs(sort: byCreation)), reading: read(day))

        order.respond(to: .changed(from: inputs(sort: byCreation), to: inputs(sort: byDueDate)), reading: read(day))
        let kept = try #require(order.ids(for: byDueDate, filter: noFilter))
        day.model.markDone(day.meds.id)

        let afterDone = RemindersScreen(engine: day.model.engine, sort: byDueDate, keptOrder: order.ids(for: byDueDate, filter: noFilter))
        #expect(afterDone.rows.map(\.id) == kept)

        order.respond(to: .changed(from: inputs(sort: byDueDate), to: inputs(isChosen: false, sort: byDueDate)), reading: read(day))
        #expect(order.ids(for: byDueDate, filter: noFilter) == kept)

        order.respond(to: .changed(from: inputs(isChosen: false, sort: byDueDate), to: inputs(sort: byDueDate)), reading: read(day))
        let sortedAgain = try #require(order.ids(for: byDueDate, filter: noFilter))
        #expect(sortedAgain != kept)
        #expect(sortedAgain.last == day.meds.id)
    }

    /// A reminder added while an order is kept goes where the sort puts it, and a deleted one drops
    /// out, with the other rows where they were; choosing the tab again then holds both.
    @Test func addingAndDeletingWhileAnOrderIsKept() async throws {
        let day = try await fixture.dayAtOnePM()
        var order = RemindersKeptOrder()
        order.respond(to: .appeared(inputs(sort: byDueDate)), reading: read(day))
        let kept = try #require(order.ids(for: byDueDate, filter: noFilter))

        day.model.delete(day.dentist.id)
        let passport = Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)
        day.model.add(passport)

        let shown = RemindersScreen(engine: day.model.engine, sort: byDueDate, keptOrder: order.ids(for: byDueDate, filter: noFilter))
        #expect(shown.rows.map(\.id) == [passport.id] + kept.filter { $0 != day.dentist.id })
        #expect(!shown.rows.map(\.id).contains(day.dentist.id))

        order.respond(to: .changed(from: inputs(isChosen: false, sort: byDueDate), to: inputs(sort: byDueDate)), reading: read(day))
        #expect(order.ids(for: byDueDate, filter: noFilter) == shown.rows.map(\.id))
    }

    /// Between the input changing and the handler keeping a new order, the first frame has the old
    /// order for another sort or filter: it gets none and sorts afresh.
    @Test func theFirstFrameAfterASortOrFilterChangeSortsAfresh() async throws {
        let day = try await fixture.dayAtOnePM()
        fixture.clock.now = NewYork.local(2026, 10, 17, 6, 31)
        var order = RemindersKeptOrder()
        order.respond(to: .appeared(inputs(sort: byDueDate)), reading: read(day))
        day.model.markDone(day.meds.id)

        let firstFrame = RemindersScreen(engine: day.model.engine, sort: byDueDate, filter: RemindersFilter(statuses: [.nudging]), keptOrder: order.ids(for: byDueDate, filter: RemindersFilter(statuses: [.nudging])))

        #expect(firstFrame.rows.map(\.id) == RemindersScreen(engine: day.model.engine, sort: byDueDate, filter: RemindersFilter(statuses: [.nudging])).rows.map(\.id))
    }
}
