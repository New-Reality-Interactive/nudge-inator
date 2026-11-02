#if DEBUG
import Foundation
import NudgeEngine

/// What a launch's command did.
public enum SeedOutcome: Equatable, Sendable {
    case loaded(String)
    case cleaned
    case unknownSet(String)
}

/// Loads a named set into the app, or removes what was loaded. A launch asks for it with
/// `NUDGE_SEED=<set name>` or `NUDGE_SEED=clean` (docs/agents/device-testing.md).
@MainActor
public enum DeviceSeed {
    public static let cleanCommand = "clean"

    public static func run(
        command: String,
        sets: [SeedSet],
        on target: some SeedTarget,
        record store: some SeedRecordStore
    ) -> SeedOutcome {
        if command == cleanCommand {
            removeEverything(from: target, record: store)
            return .cleaned
        }
        guard let set = sets.first(where: { $0.name == command }) else { return .unknownSet(command) }
        load(set, into: target, record: store)
        return .loaded(set.name)
    }

    /// Whether two tag names are the same, ignoring case, as the app compares them.
    private static func sameName(_ a: String, _ b: String) -> Bool {
        a.folding(options: .caseInsensitive, locale: nil) == b.folding(options: .caseInsensitive, locale: nil)
    }

    /// Loading a set again replaces its reminders, so one copy is left.
    private static func load(_ set: SeedSet, into target: some SeedTarget, record store: some SeedRecordStore) {
        var record = store.read()
        var loaded = record.sets[set.name] ?? SeedRecord.Loaded()

        for id in Set(loaded.reminderIDs + set.reminders.map(\.id)) {
            target.delete(id)
        }

        let otherSets = record.sets.filter { $0.key != set.name }.values
        var tagIDsByName: [String: Tag.ID] = [:]
        for name in set.tags {
            if let tag = target.tags.first(where: { sameName($0.name, name) }) {
                tagIDsByName[name] = tag.id
                // A tag another loaded set made is shared, so it goes with the last of them.
                if otherSets.contains(where: { $0.createdTagIDs.contains(tag.id) }), !loaded.createdTagIDs.contains(tag.id) {
                    loaded.createdTagIDs.append(tag.id)
                }
            } else if let tag = target.createTag(named: name) {
                tagIDsByName[name] = tag.id
                loaded.createdTagIDs.append(tag.id)
            }
        }

        // Only the first load of a setting keeps its value, whichever set that is: a later load,
        // of this set or another, would save a seeded value as the original.
        for (setting, value) in set.settings {
            let keptByAnotherSet = otherSets.contains { $0.earlierSettings[setting.rawValue] != nil }
            if loaded.earlierSettings[setting.rawValue] == nil, !keptByAnotherSet {
                loaded.earlierSettings[setting.rawValue] = target.setting(setting)
            }
            target.setSetting(setting, to: value)
        }

        // Written before the reminders, so a launch that stops partway can still be removed.
        loaded.reminderIDs = set.reminders.map(\.id)
        record.sets[set.name] = loaded
        store.write(record)

        let now = target.now
        for seeded in set.reminders {
            let tagIDs = seeded.tagNames.compactMap { tagIDsByName[$0] }
            target.add(seeded.reminder(tagIDs: tagIDs, now: now))
        }
    }

    /// Deletes what the record lists, found by ID, and puts the settings back. A tag stays if a
    /// reminder that isn't the seed's now uses it.
    private static func removeEverything(from target: some SeedTarget, record store: some SeedRecordStore) {
        let record = store.read()
        let loadedSets = record.sets.values

        for id in loadedSets.flatMap(\.reminderIDs) {
            target.delete(id)
        }

        let tagsStillUsed = Set(target.reminders.flatMap(\.tagIDs))
        for id in Set(loadedSets.flatMap(\.createdTagIDs)) where !tagsStillUsed.contains(id) {
            if target.tags.contains(where: { $0.id == id }) {
                target.deleteTag(id)
            }
        }

        for loaded in loadedSets {
            for (name, value) in loaded.earlierSettings {
                if let setting = SeedSetting(rawValue: name) {
                    target.setSetting(setting, to: value)
                }
            }
        }

        store.write(SeedRecord())
    }
}
#endif
