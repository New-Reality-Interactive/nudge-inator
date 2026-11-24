import Foundation

extension LocalizedStringResource {
    /// A value standing alone in the language's own format (a date, a time, a duration or a name),
    /// for a sentence to hold as a placeholder or a view to show by itself. Every resource that is
    /// only a placeholder shares the catalog's one entry for it, so each spells the same comment.
    static func alone<F: FormatStyle>(_ value: F.FormatInput, format: F) -> LocalizedStringResource
    where F.FormatInput: Sendable, F: Sendable, F.FormatOutput: StringProtocol {
        LocalizedStringResource("\(value, format: format)", comment: "Words standing alone, already in the language's own format: a date, a time, a duration, how soon, a list, or a person's name. A sentence holds it as a placeholder. Keep it as it is.")
    }

    /// Words already worded, such as RelativeDateTimeFormatter's "in 4 hr." or a person's name.
    static func alone(_ words: String) -> LocalizedStringResource {
        LocalizedStringResource("\(words)", comment: "Words standing alone, already in the language's own format: a date, a time, a duration, how soon, a list, or a person's name. A sentence holds it as a placeholder. Keep it as it is.")
    }

    /// Names or tags as a list in the language's own words: "Riley Park and Sam Rivera".
    static func list(_ items: [String], type: ListFormatStyle<StringStyle, [String]>.ListType = .and) -> LocalizedStringResource {
        .alone(items, format: .list(type: type))
    }
}
