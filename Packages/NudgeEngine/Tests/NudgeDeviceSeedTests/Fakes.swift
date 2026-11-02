import Foundation
import NudgeEngine
@testable import NudgeDeviceSeed

/// Stands in for the app's model: holds reminders, tags and the two settings in memory.
@MainActor
final class FakeTarget: SeedTarget {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private(set) var reminders: [Reminder] = []
    private(set) var tags: [Tag] = []
    private(set) var settings: [SeedSetting: String] = [
        .defaultPace: "escalating.600",
        .remindersSort: "created.ascending",
    ]
    /// What the record held when the first reminder arrived.
    private(set) var recordWhenFirstAdded: SeedRecord?
    var record: (() -> SeedRecord)?

    func add(_ reminder: Reminder) {
        if reminders.isEmpty { recordWhenFirstAdded = record?() }
        reminders.append(reminder)
    }

    func delete(_ reminderID: Reminder.ID) {
        reminders.removeAll { $0.id == reminderID }
    }

    func createTag(named name: String) -> Tag? {
        let tag = Tag(name: name)
        tags.append(tag)
        return tag
    }

    func deleteTag(_ tagID: Tag.ID) {
        tags.removeAll { $0.id == tagID }
        reminders = reminders.map { reminder in
            var reminder = reminder
            reminder.tagIDs.removeAll { $0 == tagID }
            return reminder
        }
    }

    func setting(_ setting: SeedSetting) -> String {
        settings[setting] ?? ""
    }

    func setSetting(_ setting: SeedSetting, to value: String) {
        settings[setting] = value
    }

    /// What the person made by hand.
    func addPersonsOwn(title: String, tagNamed tagName: String? = nil) -> Reminder {
        var tagIDs: [Tag.ID] = []
        if let tagName {
            let tag = tags.first { $0.name == tagName } ?? createTag(named: tagName)!
            tagIDs = [tag.id]
        }
        let reminder = Reminder(title: title, tagIDs: tagIDs, dueTime: now, strength: .gentle)
        add(reminder)
        return reminder
    }
}

final class MemoryRecordStore: SeedRecordStore {
    var record = SeedRecord()
    func read() -> SeedRecord { record }
    func write(_ record: SeedRecord) { self.record = record }
}

extension SeedSet {
    /// Two reminders, one tagged, one tag, one setting.
    static let sample = SeedSet(
        name: "sample",
        tags: ["errands"],
        settings: [.remindersSort: "dueDate.descending"],
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(101), title: "Buy milk", tagNames: ["errands"], dueIn: 3600),
            SeedReminder(id: SeedReminder.fixedID(102), title: "Call home", dueIn: -600, createdAgo: 86400),
        ]
    )

    /// A second set that reuses the first one's tag.
    static let other = SeedSet(
        name: "other",
        tags: ["errands"],
        settings: [.remindersSort: "created.descending"],
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(103), title: "Post parcel", tagNames: ["errands"], dueIn: 7200),
        ]
    )
}
