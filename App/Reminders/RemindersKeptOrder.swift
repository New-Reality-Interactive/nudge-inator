import NudgeEngine

/// The Reminders tab's kept order: the rows' order as they were last sorted, and when it is sorted
/// again (spec #104, Decision 35). Sorted by Due Date, Done or going Missed changes a row's due time,
/// so the rows keep their order rather than move under the person. The tab hands this its inputs
/// and one `Change` at a time; the rule says whether that change keeps the order again.
///
/// The order is read from the rows `RemindersScreen` shows, so the screen is the only place that
/// sorts. `RemindersScreen` applies the order it is given: a reminder added since goes where the
/// sort puts it, and a deleted or filtered-out one drops out.
struct RemindersKeptOrder {
    struct Inputs: Equatable, Sendable {
        let isChosen: Bool
        let sort: RemindersSort
        let filter: RemindersFilter
        let state: ScreenState
    }

    /// What the tab saw happen.
    enum Change: Sendable {
        case appeared(Inputs)
        case changed(from: Inputs, to: Inputs)

        var inputs: Inputs {
            switch self {
            case .appeared(let inputs), .changed(_, let inputs): inputs
            }
        }
    }

    /// Whether `change` keeps the order again: the tab appearing, being chosen (not chosen to
    /// chosen, and not leaving it, so coming back sorts again), or a change of the sort, the filter
    /// or the screen state.
    static func refreshes(_ change: Change) -> Bool {
        switch change {
        case .appeared:
            true
        case .changed(let old, let new):
            (new.isChosen && !old.isChosen) || old.sort != new.sort || old.filter != new.filter || old.state != new.state
        }
    }

    private struct Kept {
        let sort: RemindersSort
        let filter: RemindersFilter
        let ids: [Reminder.ID]
    }

    private var kept: Kept?

    /// Keeps the order again when `change` calls for it, from the screen `reading` makes for the
    /// change's sort and filter, sorted afresh (no kept order given). With no screen to read (`nil`)
    /// the order is lost. A change that doesn't keep the order again leaves it alone.
    mutating func respond(to change: Change, reading screen: (RemindersSort, RemindersFilter) -> RemindersScreen?) {
        guard Self.refreshes(change) else { return }
        let inputs = change.inputs
        kept = screen(inputs.sort, inputs.filter).map {
            Kept(sort: inputs.sort, filter: inputs.filter, ids: $0.rows.map(\.id))
        }
    }

    /// The kept order for `sort` and `filter`, or `nil` when none is kept for them. Until
    /// `respond(to:reading:)` keeps one for a new sort or filter, the first frame drawn with it
    /// sorts afresh rather than show the old order.
    func ids(for sort: RemindersSort, filter: RemindersFilter) -> [Reminder.ID]? {
        guard let kept, kept.sort == sort, kept.filter == filter else { return nil }
        return kept.ids
    }
}
