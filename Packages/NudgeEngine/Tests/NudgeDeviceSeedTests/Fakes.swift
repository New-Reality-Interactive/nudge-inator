import Foundation
import NudgeEngine
@testable import NudgeDeviceSeed

/// Stands in for the app's model: holds reminders, tags and the two settings in memory.
@MainActor
final class FakeTarget: SeedTarget {
    /// On a whole minute, so a seeded due time counts from it exactly.
    var now = Date(timeIntervalSinceReferenceDate: 800_000_040)
    private(set) var reminders: [Reminder] = []
    private(set) var tags: [Tag] = []
    private(set) var settings: [SeedSetting: String] = [
        .defaultPace: "escalating.600",
        .defaultAlarmSound: "bell",
        .remindersSort: "created.ascending",
    ]
    /// Spans of the past that read as quiet hours (#369), by when they were added.
    private(set) var quietSpans: [(from: Date, to: Date, replacedAt: Date)] = []
    /// How many quiet spans there were when the first reminder arrived.
    private(set) var quietSpansWhenFirstAdded: Int?
    /// What the record held when the first reminder arrived.
    private(set) var recordWhenFirstAdded: SeedRecord?
    var record: (() -> SeedRecord)?

    func add(_ reminder: Reminder) {
        if reminders.isEmpty {
            recordWhenFirstAdded = record?()
            quietSpansWhenFirstAdded = quietSpans.count
        }
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

    /// What the record held when the last quiet span was added.
    private(set) var recordWhenSpanAdded: SeedRecord?

    func addQuietSpan(from start: Date, to end: Date, replacedAt: Date) {
        recordWhenSpanAdded = record?()
        quietSpans.append((start, end, replacedAt))
    }

    func removeQuietSpan(replacedAt: Date) {
        quietSpans.removeAll { $0.replacedAt == replacedAt }
    }

    /// Whether Quiet Now is on (#497); a check turns it on by hand.
    var isQuietNowOn = false

    func turnQuietNowOff() {
        isQuietNowOn = false
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

    /// One reminder due 3 hours ago, with quiet hours over the hour after it (#369).
    static let quiet = SeedSet(
        name: "quiet",
        quietHoursBefore: SeedQuietSpan(startIn: -3 * 3600, length: 3600),
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(104), title: "Feed the cat", dueIn: -3 * 3600, strength: .firm),
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

/// A target whose clock moves on each time it is read, as the app's live `Date()` does, and counts the reads.
@MainActor
final class MovingClockTarget: SeedTarget {
    private let base = FakeTarget()
    private(set) var nowReads = 0

    var now: Date {
        nowReads += 1
        return base.now + Double(nowReads) * 30
    }
    var reminders: [Reminder] { base.reminders }
    var tags: [Tag] { base.tags }
    func add(_ reminder: Reminder) { base.add(reminder) }
    func delete(_ reminderID: Reminder.ID) { base.delete(reminderID) }
    func createTag(named name: String) -> Tag? { base.createTag(named: name) }
    func deleteTag(_ tagID: Tag.ID) { base.deleteTag(tagID) }
    func setting(_ setting: SeedSetting) -> String { base.setting(setting) }
    func setSetting(_ setting: SeedSetting, to value: String) { base.setSetting(setting, to: value) }
    func addQuietSpan(from start: Date, to end: Date, replacedAt: Date) { base.addQuietSpan(from: start, to: end, replacedAt: replacedAt) }
    func removeQuietSpan(replacedAt: Date) { base.removeQuietSpan(replacedAt: replacedAt) }
    func turnQuietNowOff() { base.turnQuietNowOff() }
}
