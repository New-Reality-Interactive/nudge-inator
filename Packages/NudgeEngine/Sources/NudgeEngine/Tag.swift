import Foundation

/// A one-word label on a reminder, shown as `#home`, used only to filter. Private to the app:
/// never carried into a schedule plan.
public struct Tag: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Without the `#`, which the screens add.
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// Why the engine turned down a tag name.
public enum TagNameError: Error, Equatable, Sendable {
    /// Nothing is left once the name is made one word.
    case empty
    /// A tag already has this name, ignoring case. The form reuses it; the Tags tab says so.
    case taken(by: Tag)
}

extension Tag {
    /// The name as one word, as the mockup's `cleanTag` makes it: trimmed, one leading `#`
    /// dropped, each run of spaces made one hyphen, and hyphens at either end removed.
    static func normalized(_ name: String) -> String {
        var name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("#") { name.removeFirst() }
        let words = name.split(whereSeparator: \.isWhitespace)
        return words.joined(separator: "-").trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Whether two names are the same tag. Folded with no locale, so the answer doesn't change
    /// with the person's language.
    static func isSameName(_ a: String, _ b: String) -> Bool {
        sortKey(a) == sortKey(b)
    }

    /// The name folded for comparing, with no locale.
    static func sortKey(_ name: String) -> String {
        name.folding(options: .caseInsensitive, locale: nil)
    }
}

/// A tag's row on the Tags tab: how many reminders have it, how many of those are due today, and
/// how many are nudging. A reminder with several tags counts under each.
public struct TagSummary: Equatable, Sendable {
    public var tag: Tag
    public var reminders: Int
    /// Items on My Day, whatever their status.
    public var dueToday: Int
    /// Reminders with an open occurrence, whenever it fell due, as the Now tab counts them.
    public var nudging: Int
}

extension Engine {
    /// Every tag's row on the Tags tab, by name ignoring case, then by ID so the order is fixed.
    public func tagSummaries() -> [TagSummary] {
        let today = myDay().items.map(\.reminderID)
        let nudging = Set(nudgingOccurrences().map(\.reminderID))
        return tags
            .sorted { (Tag.sortKey($0.name), $0.id.uuidString) < (Tag.sortKey($1.name), $1.id.uuidString) }
            .map { tag in
                let tagged = taggedReminders(tag.id).map(\.id)
                return TagSummary(
                    tag: tag,
                    reminders: tagged.count,
                    dueToday: today.count { tagged.contains($0) },
                    nudging: tagged.count { nudging.contains($0) }
                )
            }
    }

    /// Adds a tag, from the Tags tab's + or the reminder form. A name another tag has, ignoring
    /// case and a leading `#`, is turned down with that tag, so the form can use it instead.
    public mutating func createTag(named name: String) throws(TagNameError) -> Tag {
        let tag = Tag(name: try validName(name, for: nil))
        tags.append(tag)
        return tag
    }

    /// Renames a tag from the Tags tab's Edit mode. Reminders refer to it by ID, so every reminder
    /// with it gets the new name. It may change its own casing; another tag's name is turned down.
    /// Rename of a tag the engine doesn't hold is ignored.
    public mutating func renameTag(_ tagID: Tag.ID, to name: String) throws(TagNameError) {
        guard let index = tags.firstIndex(where: { $0.id == tagID }) else { return }
        tags[index].name = try validName(name, for: tagID)
    }

    /// The reminders with the tag, in the store's order: a tag's screen on the Tags tab.
    public func taggedReminders(_ tagID: Tag.ID) -> [Reminder] {
        reminders.filter { $0.tagIDs.contains(tagID) }
    }

    /// `name` made one word, or why it can't be a name for the tag `tagID` (`nil` for a new one).
    private func validName(_ name: String, for tagID: Tag.ID?) throws(TagNameError) -> String {
        let name = Tag.normalized(name)
        guard !name.isEmpty else { throw .empty }
        if let existing = tags.first(where: { $0.id != tagID && Tag.isSameName($0.name, name) }) {
            throw .taken(by: existing)
        }
        return name
    }
}
