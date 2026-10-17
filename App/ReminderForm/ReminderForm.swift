import Foundation
import NudgeEngine
import Observation

/// The New and Edit Reminder form's draft. It reads the engine's rules (tag names, the lock
/// while nudging, the repeat summary) from a snapshot of the engine, and saves through the app
/// model, which re-checks them.
@MainActor
@Observable
final class ReminderForm: Identifiable {
    var title = ""
    var notes = ""
    var tagIDs: [Tag.ID] = []
    var dueTime: Date
    /// `nil` repeats Never.
    var repeatRule: RepeatRule?
    var strength = Strength.firm
    var breakThroughFocus = true

    /// Why Save is turned down, shown as text under the field it's about.
    enum SaveBlock: Equatable {
        /// The title is empty once trimmed.
        case noTitle
        /// A one-off at a time that has passed would never nudge (the mockup's `pastOneOff`).
        case pastTime
    }

    /// The engine as the form opened. It shares the app's clock, so its lock follows the time.
    private let engine: Engine
    /// The engine's tags plus the ones typed in this form. A copy, so the engine's tag-name rule
    /// checks each new name against both; the app model creates the chosen ones on Save, so a
    /// cancelled form leaves no tag behind (the mockup's `newTags`).
    private var tagRules: Engine
    private let now: () -> Date

    /// The reminder being edited, or `nil` for a new one.
    private let original: Reminder?
    /// A new reminder's ID.
    private let newID = UUID()
    /// The draft as the form opened, set once `init` has filled it in.
    private var opened: Reminder?

    /// A New Reminder form.
    init(engine: Engine, now: @escaping () -> Date) {
        self.engine = engine
        tagRules = engine
        self.now = now
        original = nil
        dueTime = Self.nextWholeHour(after: now())
        opened = draft(tagIDs: tagIDs)
    }

    /// A new reminder's start: the next whole hour in the person's time zone, which can't have
    /// passed by the time they save.
    private static func nextWholeHour(after date: Date) -> Date {
        Calendar.autoupdatingCurrent.nextDate(after: date, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) ?? date
    }

    /// An Edit form for a reminder the engine holds, or `nil` if it doesn't hold it.
    init?(engine: Engine, editing reminderID: Reminder.ID, now: @escaping () -> Date) {
        guard let reminder = engine.reminders.first(where: { $0.id == reminderID }) else { return nil }
        self.engine = engine
        tagRules = engine
        self.now = now
        original = reminder
        title = reminder.title
        notes = reminder.notes
        tagIDs = reminder.tagIDs
        dueTime = reminder.dueTime
        repeatRule = reminder.repeatRule
        strength = reminder.strength
        breakThroughFocus = reminder.breakThroughFocus
        opened = draft(tagIDs: tagIDs)
    }

    /// Whether Cancel should ask before throwing the draft away (the mockup's `draftDirty`).
    var hasChanges: Bool {
        draft(tagIDs: tagIDs) != opened
    }

    /// The Repeat row's preset, or `nil` when the rule is Custom. Setting a preset replaces a
    /// custom rule.
    var repeatPreset: RepeatPreset? {
        get { RepeatPreset(repeatRule) }
        set { if let newValue { repeatRule = newValue.rule } }
    }

    /// The engine's summary of the draft's repeat and time ("Every 3 days at 9:00 AM"), for the
    /// Starts footer and the Custom row.
    var repeatSummary: String {
        engine.repeatSummary(of: draft(tagIDs: tagIDs))
    }

    /// The fields the engine won't let an Edit change now (ticket 13). Read from the engine, so
    /// the form has no rule of its own; a new reminder has none.
    var lockedFields: Set<LockedField> {
        original.map { engine.lockedFields(of: $0.id) } ?? []
    }

    var saveBlock: SaveBlock? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .noTitle }
        // An existing one-off that keeps its time can still be renamed, whenever it fell due.
        let keepsItsOneOffTime = original.map { $0.repeatRule == nil && $0.dueTime == dueTime } ?? false
        if repeatRule == nil, dueTime <= now(), !keepsItsOneOffTime { return .pastTime }
        return nil
    }

    /// Every tag the Tags page offers: the saved ones, then the ones typed here.
    var tags: [Tag] { tagRules.tags }

    /// The Tags row: the chosen tags as `#name`, in the order chosen, or `nil` if there are none.
    var chosenTagsText: String? {
        let names = tagIDs.compactMap { tagID in tags.first { $0.id == tagID }?.name }
        return names.isEmpty ? nil : names.map { "#\($0)" }.joined(separator: " ")
    }

    /// The Tags page's Add: the typed name, made one word, attaches the tag with that name
    /// ignoring case, or a new one. The engine's own tag-name rule decides, so the form has no
    /// copy of it.
    func addTag(named name: String) {
        do throws(TagNameError) {
            tagIDs.append(try tagRules.createTag(named: name).id)
        } catch {
            switch error {
            case .taken(by: let existing):
                if !tagIDs.contains(existing.id) { tagIDs.append(existing.id) }
            case .empty:
                break
            }
        }
    }

    /// A row on the Tags page: chooses the tag, or unchooses it.
    func toggleTag(_ tagID: Tag.ID) {
        if let index = tagIDs.firstIndex(of: tagID) {
            tagIDs.remove(at: index)
        } else {
            tagIDs.append(tagID)
        }
    }

    /// Saves the draft through the model. `false` if a save block turned it down.
    func save(to model: AppModel) -> Bool {
        guard saveBlock == nil else { return false }
        let reminder = draft(tagIDs: savedTagIDs(through: model))
        guard original != nil else {
            model.add(reminder)
            return true
        }
        do throws(EditError) {
            try model.edit(reminder)
            return true
        } catch {
            // It started nudging while the form was open. The engine's lock follows the clock, so
            // the lock note now says why, and the locked controls, now disabled, go back to what
            // is saved.
            if let original { restoreLockedFields(from: original) }
            return false
        }
    }

    /// The draft as a reminder. A new one gets its ID here, which nothing keeps until it's saved.
    private func draft(tagIDs: [Tag.ID]) -> Reminder {
        Reminder(
            id: original?.id ?? newID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tagIDs: tagIDs,
            dueTime: dueTime,
            repeatRule: repeatRule,
            strength: strength,
            breakThroughFocus: breakThroughFocus
        )
    }

    private func restoreLockedFields(from reminder: Reminder) {
        for field in lockedFields {
            switch field {
            case .dueTime: dueTime = reminder.dueTime
            case .repeatRule: repeatRule = reminder.repeatRule
            case .strength: strength = reminder.strength
            case .breakThroughFocus: breakThroughFocus = reminder.breakThroughFocus
            }
        }
    }

    /// The chosen tags' IDs, once the model has created the ones typed here. A name the model
    /// already holds (made elsewhere meanwhile) uses that tag.
    private func savedTagIDs(through model: AppModel) -> [Tag.ID] {
        let saved = Set(engine.tags.map(\.id))
        return tagIDs.compactMap { tagID in
            guard !saved.contains(tagID) else { return tagID }
            guard let typed = tagRules.tags.first(where: { $0.id == tagID }) else { return nil }
            do throws(TagNameError) {
                return try model.createTag(named: typed.name)?.id
            } catch {
                switch error {
                case .taken(by: let existing): return existing.id
                case .empty: return nil
                }
            }
        }
    }
}
