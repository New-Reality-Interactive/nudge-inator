import Foundation

/// How the Tags tab's list is ordered: the Sort menu's choice.
public struct TagSort: Equatable, Sendable {
    public var field: Field
    public var order: Order

    public enum Field: String, CaseIterable, Sendable {
        /// By name, ignoring case.
        case name
        /// By how many reminders have the tag.
        case reminderCount
    }

    public enum Order: String, Sendable {
        /// A to Z, or Fewest First.
        case ascending
        /// Z to A, or Most First.
        case descending
    }

    public init(field: Field, order: Order) {
        self.field = field
        self.order = order
    }

    /// Out of the box, and after Delete All Data.
    public static let nameAToZ = TagSort(field: .name, order: .ascending)
}

/// The Tags tab's list: the tags shown, in the Sort menu's order.
public struct TagList: Equatable, Sendable {
    public var rows: [TagSummary]
    /// Every tag the engine holds, the header row's "out of" number, however few are shown.
    public var total: Int

    /// The rows shown: the header row's first number.
    public var visibleCount: Int { rows.count }
}

extension Engine {
    /// The Tags tab's list as it stands now, in `sort`'s order. Tags with the same reminder count
    /// sort by name, A to Z, under both orders (spec #104, Decision 43).
    public func tagList(sortedBy sort: TagSort = .nameAToZ) -> TagList {
        let byName = tagSummaries()
        let rows: [TagSummary] = switch sort.field {
        case .name:
            sort.order == .ascending ? byName : byName.reversed()
        case .reminderCount:
            byName.enumerated().sorted { first, second in
                let (a, b) = (first.element.reminderCount, second.element.reminderCount)
                guard a != b else { return first.offset < second.offset }
                return sort.order == .ascending ? a < b : a > b
            }.map(\.element)
        }
        return TagList(rows: rows, total: tags.count)
    }
}
