import Foundation
import NudgeEngine
import Observation

/// The New and Edit Reminder form's draft. It reads the engine's rules (tag names, the lock
/// while nudging, the repeat summary) from the app's current engine, and saves through the app
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
        /// A start that has passed: a one-off would never nudge, and a repeat would open an
        /// occurrence at once and nudge (ticket 13). A saved start that is kept is fine.
        case pastTime
    }

    /// The app's engine as it is now, so the lock follows the model (a Done from a notification
    /// while the form is open) as well as the clock.
    private let currentEngine: () -> Engine
    /// The engine's tags plus the ones typed in this form. A copy, so the engine's tag-name rule
    /// checks each new name against both; the app model creates the chosen ones on Save, so a
    /// cancelled form leaves no tag behind (the mockup's `newTags`).
    private var tagRules: Engine
    private let now: () -> Date

    /// The reminder being edited, or `nil` for a new one.
    private let original: Reminder?
    /// A new reminder's ID.
    private let newID = UUID()
    /// Set once a save is accepted, so a second tap on Save before the sheet closes adds nothing.
    private var isSaved = false
    /// The draft as the form opened, set once `init` has filled it in.
    private var opened: Reminder?

    /// A New Reminder form.
    init(engine currentEngine: @escaping () -> Engine, now: @escaping () -> Date) {
        self.currentEngine = currentEngine
        tagRules = currentEngine()
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
    init?(engine currentEngine: @escaping () -> Engine, editing reminderID: Reminder.ID, now: @escaping () -> Date) {
        let engine = currentEngine()
        guard let reminder = engine.reminders.first(where: { $0.id == reminderID }) else { return nil }
        self.currentEngine = currentEngine
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

    /// The Edit form, rather than New: its title and Save's label.
    var isEditing: Bool { original != nil }

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
        currentEngine().repeatSummary(of: draft(tagIDs: tagIDs))
    }

    /// The fields the engine won't let an Edit change now (ticket 13). Read from the engine, so
    /// the form has no rule of its own; a new reminder has none.
    var lockedFields: Set<LockedField> {
        original.map { currentEngine().lockedFields(of: $0.id) } ?? []
    }

    var saveBlock: SaveBlock? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .noTitle }
        // A reminder that keeps its start can still be renamed, whenever it fell due. The picker
        // shows minutes, so the same minute is the same start.
        let keepsItsStart = original.map { Calendar.autoupdatingCurrent.isDate($0.dueTime, equalTo: dueTime, toGranularity: .minute) } ?? false
        if dueTime <= now(), !keepsItsStart { return .pastTime }
        return nil
    }

    /// Every tag the Tags page offers: the saved ones, then the ones typed here.
    var tags: [Tag] { tagRules.tags }

    /// The Tags row: the chosen tags as `#name`, in the order chosen, or `nil` if there are none.
    /// Tokens separated by spaces as the mockup shows them, not a sentence, so not a list format.
    var chosenTagsText: String? {
        let names = tagIDs.compactMap { tagID in tags.first { $0.id == tagID }?.name }
        return names.isEmpty ? nil : names.map { "#\($0)" }.joined(separator: " ")
    }

    /// The Tags page's Add: the typed name, made one word, attaches the tag with that name
    /// ignoring case, or a new one. The engine's own tag-name rule decides, so the form has no
    /// copy of it.
    func addTag(named name: String) {
        guard let tag = Self.tag({ () throws(TagNameError) -> Tag? in try tagRules.createTag(named: name) }),
              !tagIDs.contains(tag.id)
        else { return }
        tagIDs.append(tag.id)
    }

    /// A row on the Tags page: chooses the tag, or unchooses it.
    func toggleTag(_ tagID: Tag.ID) {
        if let index = tagIDs.firstIndex(of: tagID) {
            tagIDs.remove(at: index)
        } else {
            tagIDs.append(tagID)
        }
    }

    /// Saves the draft through the model. `false` if a save block or the lock turned it down, or
    /// it was already saved.
    func save(to model: AppModel) -> Bool {
        guard !isSaved, saveBlock == nil else { return false }
        guard let original else {
            model.add(draft(tagIDs: savedTagIDs(through: model)))
            isSaved = true
            return true
        }
        // It may have started nudging since the form opened. Checked with the engine's own rule
        // before any typed tag is created, so a turned-down save leaves nothing behind.
        let locked = model.engine.lockedFields(of: original.id)
        guard !locked.contains(where: { $0.isChanged(from: original, to: draft(tagIDs: tagIDs)) }) else {
            restoreLockedFields(from: original)
            return false
        }
        do throws(EditError) {
            try model.edit(draft(tagIDs: savedTagIDs(through: model)))
            isSaved = true
            return true
        } catch {
            restoreLockedFields(from: original)
            return false
        }
    }

    /// The draft as a reminder. A new one gets its ID here, which nothing keeps until it's saved.
    private func draft(tagIDs: [Tag.ID]) -> Reminder {
        Reminder(
            id: original?.id ?? newID,
            // One line: a pasted title's line breaks become spaces.
            title: title.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tagIDs: tagIDs,
            dueTime: dueTime,
            repeatRule: repeatRule,
            strength: strength,
            breakThroughFocus: breakThroughFocus
        )
    }

    /// Puts the locked fields back as saved: the lock note now says why, and their controls are
    /// disabled, so the person couldn't put them back themselves.
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
        let saved = Set(model.engine.tags.map(\.id))
        return tagIDs.compactMap { tagID in
            guard !saved.contains(tagID) else { return tagID }
            guard let typed = tagRules.tags.first(where: { $0.id == tagID }) else { return nil }
            return Self.tag({ () throws(TagNameError) -> Tag? in try model.createTag(named: typed.name) })?.id
        }
    }

    /// The tag a create gave, or the one with that name already: the engine's answer either way.
    /// `nil` for a name that is empty once made one word.
    private static func tag(_ create: () throws(TagNameError) -> Tag?) -> Tag? {
        do throws(TagNameError) {
            return try create()
        } catch {
            switch error {
            case .taken(by: let existing): return existing
            case .empty: return nil
            }
        }
    }
}
