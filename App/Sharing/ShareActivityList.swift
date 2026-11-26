import Foundation

/// What Settings › Share Activity lists (#397): the record's entries (GLOSSARY.md, Share
/// Activity), newest first, each naming who it concerns.
struct ShareActivityList {
    let rows: [Row]

    struct Row: Identifiable {
        let id: ShareActivityEntry.ID
        /// The connections the entry concerns: one name, or several joined as a list in the
        /// person's language. `nil` for an entry with no one to name.
        let who: LocalizedStringResource?
        let event: ShareActivityEntry.Event
        let at: Date
    }

    init(_ data: SharingData, locale: Locale) {
        // The store keeps the record oldest first.
        rows = data.activity.reversed().map { entry in
            Row(
                id: entry.id,
                who: entry.connectionNames.isEmpty ? nil : Self.names(entry.connectionNames, in: locale),
                event: entry.event,
                at: entry.at
            )
        }
    }

    var isEmpty: Bool { rows.isEmpty }

    /// The names as a list, joined in `locale`'s words.
    private static func names(_ names: [String], in locale: Locale) -> LocalizedStringResource {
        var list = LocalizedStringResource.list(names)
        list.locale = locale
        return list
    }
}
