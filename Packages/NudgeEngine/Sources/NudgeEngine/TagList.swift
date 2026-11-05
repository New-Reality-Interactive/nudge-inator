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

/// What the Tags tab's list is narrowed by. Nothing chosen narrows nothing.
public struct TagListFilter: Equatable, Sendable {
    /// The phrase a tag's name must contain, as typed without leading or trailing whitespace, so a
    /// space typed after a word doesn't change the filter, and the no-match state can name it. A
    /// leading `#` stays here and isn't searched for. Empty narrows nothing.
    public var search: String {
        didSet { search = Self.trimmed(search) }
    }

    public init(search: String = "") {
        self.search = Self.trimmed(search)
    }

    /// Ignores case and diacritics. Names are stored without the `#`, so "#home" finds "home".
    func matches(_ tag: Tag) -> Bool {
        var phrase = search
        if phrase.hasPrefix("#") { phrase.removeFirst() }
        phrase = Self.trimmed(phrase)
        return phrase.isEmpty || tag.name.localizedStandardContains(phrase)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The Tags tab's list: the tags `filter` matches, in the Sort menu's order.
public struct TagList: Equatable, Sendable {
    public var rows: [TagSummary]
    /// Every tag the engine holds, the header row's "out of" number, however few are shown.
    public var total: Int

    /// The rows shown: the header row's first number.
    public var visibleCount: Int { rows.count }
}

extension Engine {
    /// The Tags tab's list as it stands now, in `sort`'s order. Tags with the same reminder count
    /// sort by name, A to Z, under both orders (spec #104, Decision 43). Only tags `filter` matches
    /// are listed.
    public func tagList(
        sortedBy sort: TagSort = .nameAToZ,
        filteredBy filter: TagListFilter = TagListFilter()
    ) -> TagList {
        let byName = tagSummaries().filter { filter.matches($0.tag) }
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
