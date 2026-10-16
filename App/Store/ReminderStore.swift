import Foundation
import SwiftData
import NudgeEngine

/// Everything the store keeps: the engine's inputs that the clock can't work out.
struct StoredData: Equatable {
    var reminders: [Reminder]
    var tags: [Tag]
    var histories: [Reminder.ID: ReminderHistory]
}

/// Why the store turned down a save or couldn't read what it saved.
enum StoreError: Error, Equatable {
    /// A saved field the store reads back into the engine's values.
    enum Field: Equatable, Sendable {
        case repeatRule
        case repeatMissingDay
        case strength
        case occurrenceState
        case closedOccurrenceDueTime
    }

    /// A saved value the store can't map back to the engine's, such as RRULE text that no longer
    /// parses. Read as an error rather than dropped, so nothing is lost quietly.
    case unreadable(field: Field, value: String)
    /// A save that lists a reminder or tag ID twice. The engine's lists aren't checked, so the
    /// store turns it down rather than write two records for one ID.
    case duplicateID(UUID)
}

/// Where the store file lives.
enum StoreLocation {
    /// The App Group container (ticket 01), so a widget extension can read it in a later version.
    case appGroup
    /// Nothing on disk: for tests.
    case inMemory
    /// A file of the tests' choosing, so a test can open it again as a relaunch would.
    case file(URL)
}

/// Keeps reminders, tags and each reminder's history on the device. No account, no server, no
/// sync. `@MainActor` because it uses the container's main context, and the app model that
/// calls it is `@MainActor` too.
@MainActor
struct ReminderStore {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(location: StoreLocation) throws {
        let configuration = Self.configuration(for: location)
        container = try ModelContainer(for: Self.schema, configurations: configuration)
    }

    nonisolated private static let schema = Schema([
        ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self,
    ])

    /// Where and how SwiftData keeps the store. Its own function so a test can check the App Group
    /// location without opening the real store.
    nonisolated static func configuration(for location: StoreLocation) -> ModelConfiguration {
        // `cloudKitDatabase` defaults to `.automatic`, which would start syncing if a CloudKit
        // entitlement were ever added. Everything stays on the device (spec story 56).
        switch location {
        case .appGroup:
            ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupIdentifier), cloudKitDatabase: .none)
        case .inMemory:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, groupContainer: .none, cloudKitDatabase: .none)
        case .file(let url):
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
    }

    nonisolated static let appGroupIdentifier = "group.com.newrealityinteractive.nudgeinator"

    /// Replaces what the store holds with `data`: what it leaves out is deleted. A history whose
    /// reminder isn't in `data` isn't saved, since it would have nothing to belong to; the engine
    /// keeps one only for a reminder `update(reminders:)` dropped without Delete (ticket 12).
    func save(_ data: StoredData) throws {
        try Self.checkUnique(data.reminders.map(\.id) + data.tags.map(\.id))
        var reminderRecords = try recordsByID(of: ReminderRecord.self)
        for (position, reminder) in data.reminders.enumerated() {
            let record = reminderRecords.removeValue(forKey: reminder.id) ?? {
                let record = ReminderRecord(id: reminder.id, position: position)
                context.insert(record)
                return record
            }()
            record.update(from: reminder, position: position)
            replaceHistory(of: record, with: data.histories[reminder.id] ?? ReminderHistory())
        }
        reminderRecords.values.forEach(context.delete)

        var tagRecords = try recordsByID(of: TagRecord.self)
        for (position, tag) in data.tags.enumerated() {
            if let record = tagRecords.removeValue(forKey: tag.id) {
                record.position = position
                record.name = tag.name
            } else {
                context.insert(TagRecord(id: tag.id, position: position, name: tag.name))
            }
        }
        tagRecords.values.forEach(context.delete)
        try context.save()
    }

    /// Throws for the first ID listed twice. Reminder and tag IDs are both UUIDs, so one list does.
    private static func checkUnique(_ ids: [UUID]) throws {
        var seen: Set<UUID> = []
        for id in ids where !seen.insert(id).inserted {
            throw StoreError.duplicateID(id)
        }
    }

    /// Every saved record of a type, by ID. The ID is unique in the schema, so a clash can't
    /// happen; if it ever did, the first record wins rather than the app crashing.
    private func recordsByID<Record: PersistentModel & IdentifiedRecord>(of type: Record.Type) throws -> [UUID: Record] {
        Dictionary(try context.fetch(FetchDescriptor<Record>()).map { ($0.id, $0) }) { first, _ in first }
    }

    /// Settings' Delete All Data (ticket 30): every reminder, tag and history record. The caller
    /// then hands the engine empty lists, so its plan empties and the adapters cancel everything
    /// pending. Not `ModelContainer.deleteAllData()`, which the iOS 26.5 SDK deprecates.
    func deleteAllData() throws {
        try context.delete(model: ReminderRecord.self)
        try context.delete(model: ClosedOccurrenceRecord.self)
        try context.delete(model: PauseSpanRecord.self)
        try context.delete(model: ReplacedTitleRecord.self)
        try context.delete(model: TagRecord.self)
        try context.save()
    }

    /// Deletes the reminder and, through the cascade, its whole history. Call it with
    /// `engine.delete` (ticket 12): a reminder added back under the same ID inherits nothing.
    func delete(_ reminderID: Reminder.ID) throws {
        // Fetched and deleted one by one, as `save` does, so the cascade delete rule applies; the
        // docs show it only for that path.
        try context.fetch(FetchDescriptor<ReminderRecord>(predicate: #Predicate { $0.id == reminderID })).forEach(context.delete)
        try context.save()
    }

    /// Deletes the tag and takes it off every reminder, which stays: the same change as the
    /// engine's `deleteTag`. The engine's filters ignore a deleted tag's ID anyway, but a saved one
    /// would come back on every reminder that had it.
    func deleteTag(_ tagID: Tag.ID) throws {
        try context.delete(model: TagRecord.self, where: #Predicate { $0.id == tagID })
        for record in try context.fetch(FetchDescriptor<ReminderRecord>()) where record.tagIDs.contains(tagID) {
            record.tagIDs.removeAll { $0 == tagID }
        }
        try context.save()
    }

    /// Swaps the saved history for `history`. The records are small and few, so they're replaced
    /// whole rather than matched up.
    private func replaceHistory(of record: ReminderRecord, with history: ReminderHistory) {
        record.closedOccurrences.forEach(context.delete)
        record.closedOccurrences = history.closedOccurrences.map { dueTime, closing in
            ClosedOccurrenceRecord(
                dueTime: dueTime,
                state: closing.state.storedValue,
                nudgeNumber: closing.state.nudgeNumber,
                closedAt: closing.closedAt,
                nudgesSent: closing.nudgesSent
            )
        }
        record.pauseSpans.forEach(context.delete)
        record.pauseSpans = history.pauseSpans.enumerated().map { PauseSpanRecord(position: $0, start: $1.start, end: $1.end) }
        record.replacedTitles.forEach(context.delete)
        record.replacedTitles = history.replacedTitles.enumerated().map {
            ReplacedTitleRecord(position: $0, title: $1.value, replacedAt: $1.replacedAt)
        }
        record.editAppliesAfter = history.editAppliesAfter
    }

    /// What the store holds, in the order it was saved.
    func load() throws -> StoredData {
        let reminders = try context.fetch(FetchDescriptor<ReminderRecord>(sortBy: [SortDescriptor(\.position)]))
        let tags = try context.fetch(FetchDescriptor<TagRecord>(sortBy: [SortDescriptor(\.position)]))
        return StoredData(
            reminders: try reminders.map { try $0.reminder() },
            tags: tags.map { Tag(id: $0.id, name: $0.name) },
            histories: Dictionary(try reminders.compactMap { record in
                let history = try record.history()
                return history == ReminderHistory() ? nil : (record.id, history)
            }) { first, _ in first }
        )
    }
}

private extension ReminderRecord {
    func update(from reminder: Reminder, position: Int) {
        self.position = position
        title = reminder.title
        notes = reminder.notes
        tagIDs = reminder.tagIDs
        dueTime = reminder.dueTime
        repeatRule = reminder.repeatRule?.rrule
        repeatMissingDay = reminder.repeatRule.map { $0.missingDay.storedValue }
        repeatUntilTime = if case .untilTime(let time) = reminder.repeatRule?.end { time } else { nil }
        strength = reminder.strength.storedValue
        breakThroughFocus = reminder.breakThroughFocus
    }

    func reminder() throws -> Reminder {
        Reminder(
            id: id,
            title: title,
            notes: notes,
            tagIDs: tagIDs,
            dueTime: dueTime,
            repeatRule: try storedRepeatRule(),
            strength: try Strength(storedValue: strength),
            breakThroughFocus: breakThroughFocus
        )
    }

    func history() throws -> ReminderHistory {
        ReminderHistory(
            closedOccurrences: try Dictionary(try closedOccurrences.map { record in
                let closing = Closing(
                    state: try OccurrenceState(storedValue: record.state, nudgeNumber: record.nudgeNumber),
                    closedAt: record.closedAt,
                    nudgesSent: record.nudgesSent
                )
                return (record.dueTime, closing)
            }) { _, _ in throw StoreError.unreadable(field: .closedOccurrenceDueTime, value: "two closings for one due time") },
            editAppliesAfter: editAppliesAfter,
            pauseSpans: pauseSpans.sorted { $0.position < $1.position }.map { PauseSpan(start: $0.start, end: $0.end) },
            replacedTitles: replacedTitles.sorted { $0.position < $1.position }.map { Replaced(value: $0.title, replacedAt: $0.replacedAt) }
        )
    }

    func storedRepeatRule() throws -> RepeatRule? {
        guard let repeatRule else { return nil }
        var rule: RepeatRule
        do {
            rule = try RepeatRule(rrule: repeatRule)
        } catch {
            throw StoreError.unreadable(field: .repeatRule, value: repeatRule)
        }
        rule.missingDay = try RepeatRule.MissingDay(storedValue: repeatMissingDay ?? "")
        // RRULE text keeps UNTIL to the second; the exact instant is saved beside it.
        if case .untilTime = rule.end, let repeatUntilTime { rule.end = .untilTime(repeatUntilTime) }
        return rule
    }
}

/// The engine's enums as the strings the store saves. Spelled out here rather than taken from
/// case names, so renaming a case in the engine can't change what's on disk. Each has a switch
/// both ways: the engine's enums aren't `CaseIterable`, so the writing switch is the only one the
/// compiler checks for a new case, and the round-trip tests cover every case of the reading one.
private extension Strength {
    var storedValue: String {
        switch self {
        case .gentle: "gentle"
        case .firm: "firm"
        case .relentless: "relentless"
        }
    }

    init(storedValue: String) throws {
        switch storedValue {
        case "gentle": self = .gentle
        case "firm": self = .firm
        case "relentless": self = .relentless
        default: throw StoreError.unreadable(field: .strength, value: storedValue)
        }
    }
}

private extension RepeatRule.MissingDay {
    var storedValue: String {
        switch self {
        case .skip: "skip"
        case .lastDayOfMonth: "lastDayOfMonth"
        }
    }

    init(storedValue: String) throws {
        switch storedValue {
        case "skip": self = .skip
        case "lastDayOfMonth": self = .lastDayOfMonth
        default: throw StoreError.unreadable(field: .repeatMissingDay, value: storedValue)
        }
    }
}

private extension OccurrenceState {
    var storedValue: String {
        switch self {
        case .nudging: "nudging"
        case .done: "done"
        case .missed(.giveUpLimit): "missed.giveUpLimit"
        case .missed(.nextTookOver): "missed.nextTookOver"
        case .skipped(.paused): "skipped.paused"
        }
    }

    var nudgeNumber: Int? {
        guard case .nudging(let nudgeNumber) = self else { return nil }
        return nudgeNumber
    }

    init(storedValue: String, nudgeNumber: Int?) throws {
        switch (storedValue, nudgeNumber) {
        case ("nudging", let nudgeNumber?): self = .nudging(nudgeNumber: nudgeNumber)
        case ("done", _): self = .done
        case ("missed.giveUpLimit", _): self = .missed(reason: .giveUpLimit)
        case ("missed.nextTookOver", _): self = .missed(reason: .nextTookOver)
        case ("skipped.paused", _): self = .skipped(reason: .paused)
        default: throw StoreError.unreadable(field: .occurrenceState, value: storedValue)
        }
    }
}
