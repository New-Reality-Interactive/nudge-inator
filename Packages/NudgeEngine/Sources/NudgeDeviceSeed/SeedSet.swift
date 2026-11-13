#if DEBUG
import Foundation
import NudgeEngine

/// A setting a set can change, by the name the record keeps it under. Its value is text the app
/// reads and writes (`created.ascending` for the Reminders tab's sort, `consistent.600` for the
/// Default Pace); the seed only keeps and restores it.
public enum SeedSetting: String, Sendable {
    case defaultPace
    case remindersSort
}

/// One reminder of a set. Its ID is fixed, so a second load replaces it and removal finds it
/// without looking at its title. It is built with Break Through Focus off: it defaults to on, which
/// can schedule a real alarm, and uninstalling the app doesn't remove those.
public struct SeedReminder: Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    /// Names from the set's `tags`.
    public var tagNames: [String]
    /// Seconds from the load to the due time, rounded down to the whole minute, since nothing on
    /// screen shows seconds; negative is already due.
    public var dueIn: TimeInterval
    /// Seconds before the load it was created, so the Reminders tab has dates to sort by.
    public var createdAgo: TimeInterval
    public var strength: Strength
    public var repeatRule: RepeatRule?
    /// Mine, or a copy received through a connection (ticket 197's set).
    public var origin: ReminderOrigin

    public init(
        id: UUID,
        title: String,
        notes: String = "",
        tagNames: [String] = [],
        dueIn: TimeInterval,
        createdAgo: TimeInterval = 0,
        strength: Strength = .gentle,
        repeatRule: RepeatRule? = nil,
        origin: ReminderOrigin = .mine
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.tagNames = tagNames
        self.dueIn = dueIn
        self.createdAgo = createdAgo
        self.strength = strength
        self.repeatRule = repeatRule
        self.origin = origin
    }

    /// A reminder ID that never changes, so the same set always has the same IDs. `number` is
    /// unique within the module's sets (a test checks).
    public static func fixedID(_ number: UInt8) -> UUID {
        UUID(uuid: (0x5E, 0xED, 0x00, 0x01, 0x00, 0x00, 0x40, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, number))
    }

    private static func wholeMinute(of date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
    }

    func reminder(tagIDs: [Tag.ID], now: Date) -> Reminder {
        Reminder(
            id: id,
            title: title,
            notes: notes,
            tagIDs: tagIDs,
            dueTime: Self.wholeMinute(of: now.addingTimeInterval(dueIn)),
            repeatRule: repeatRule,
            strength: strength,
            breakThroughFocus: false,
            createdAt: now.addingTimeInterval(-createdAgo),
            origin: origin
        )
    }
}

/// A named set of test data for one manual device check. Add one by writing a file like
/// `SearchSet.swift` and listing it in `SeedSet.all`.
public struct SeedSet: Sendable {
    /// What a launch names it by: `NUDGE_SEED=<name>`. Not `clean`, which removes.
    public var name: String
    /// Tag names the reminders use. A tag the person already has under a name is used as it is.
    public var tags: [String]
    /// Settings the check needs; removal puts them back as they were.
    public var settings: [SeedSetting: String]
    public var reminders: [SeedReminder]

    public init(
        name: String,
        tags: [String] = [],
        settings: [SeedSetting: String] = [:],
        reminders: [SeedReminder]
    ) {
        self.name = name
        self.tags = tags
        self.settings = settings
        self.reminders = reminders
    }
}

extension SeedSet {
    /// Every set a launch can name.
    public static let all: [SeedSet] = [.search, .dueDates, .swipeTiles, .tagSearch, .lastTag, .deliveredNudges, .keptOrder, .received, .fromOthers]
}
#endif
