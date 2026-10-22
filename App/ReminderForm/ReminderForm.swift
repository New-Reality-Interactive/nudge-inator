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
    /// The Custom page's choices while the repeat is custom, or `nil` for Never or a preset.
    var customRepeat: CustomRepeat?
    /// Never (`nil`) or a preset's rule, while the repeat isn't custom.
    private var presetRule: RepeatRule?
    /// A custom rule as it was set, with the choices it was read into and the start then. The
    /// page has no control for some parts of a rule (BYMONTH, say), so the rule is kept as it
    /// came until a choice or the start changes (decision 5, ticket 25).
    private var setCustomRule: (rule: RepeatRule, choices: CustomRepeat, dueTime: Date)?
    var strength = Strength.firm
    /// The person's switch, as saved. Relentless ignores it but keeps it, so leaving Relentless
    /// gives it back; the form shows `breaksThroughFocus`.
    var breakThroughFocus = true
    /// The Pace control: Escalating or Consistent. A new reminder starts Escalating until the
    /// Default Pace (ticket 09).
    var paceChoice = PaceChoice.escalating
    /// The Every row's wait, one of `Pace.consistentWaits`. Kept while Escalating is chosen, so
    /// choosing Consistent again finds it (spec story 25).
    var consistentWait = PaceChoice.startingWait

    /// The draft's pace, from the Pace control and the Every row.
    var pace: Pace {
        switch paceChoice {
        case .escalating: .escalating
        case .consistent: .consistent(wait: consistentWait)
        }
    }

    /// The switch as the form shows it: always on for Relentless (ADR 0004). Setting it sets the
    /// person's switch.
    var breaksThroughFocus: Bool {
        get { strength.breaksThroughFocus(switchedOn: breakThroughFocus) }
        set { breakThroughFocus = newValue }
    }

    /// Relentless always breaks through Focus, so its switch can't be turned off: a strength that
    /// breaks through even with the switch off has nothing for the switch to change.
    var isBreakThroughFocusFixed: Bool {
        strength.breaksThroughFocus(switchedOn: false)
    }

    /// Why Save is turned down, shown as text under the field it's about.
    enum SaveBlock: Equatable {
        /// The title is empty once trimmed.
        case noTitle
        /// A start that has passed: a one-off would never nudge, and a repeat would open an
        /// occurrence at once and nudge (ticket 13). A saved start that is kept is fine.
        case pastTime
        /// A custom repeat whose end date is before its start's day.
        case endsBeforeStart
        /// A custom repeat that has already ended, so it would never fall due again. A saved
        /// reminder that keeps its start and repeat is fine, so it can still be renamed.
        case noTimesLeft
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

    /// A New Reminder form. `tagIDs` are chosen when it opens, as from a tag's screen, and aren't
    /// a change the person made.
    init(engine currentEngine: @escaping () -> Engine, now: @escaping () -> Date, tagIDs: [Tag.ID] = []) {
        self.tagIDs = tagIDs
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
        paceChoice = PaceChoice(reminder.pace)
        if case .consistent(let wait) = reminder.pace { consistentWait = wait }
        opened = draft(tagIDs: tagIDs)
    }

    /// The Edit form, rather than New: its title and Save's label.
    var isEditing: Bool { original != nil }

    /// Whether Cancel should ask before throwing the draft away (the mockup's `draftDirty`).
    var hasChanges: Bool {
        draft(tagIDs: tagIDs) != opened
    }

    /// `nil` repeats Never. A custom repeat's rule is built from its choices and the start, so a
    /// monthly choice a new start doesn't offer falls back to the day of the month. Setting a
    /// rule that isn't a preset's reads it into the Custom page's choices.
    var repeatRule: RepeatRule? {
        get {
            guard let customRepeat else { return presetRule }
            if let setCustomRule, setCustomRule.choices == customRepeat, setCustomRule.dueTime == dueTime { return setCustomRule.rule }
            return currentEngine().repeatRule(for: customRepeat, startingAt: dueTime)
        }
        set {
            if let preset = RepeatPreset(newValue) {
                presetRule = preset.rule
                customRepeat = nil
            } else if let newValue {
                let choices = currentEngine().customRepeat(from: newValue, startingAt: dueTime)
                customRepeat = choices
                setCustomRule = (newValue, choices, dueTime)
            }
        }
    }

    /// What the Custom page shows and edits: the custom choices, or, while the repeat is a preset
    /// or Never, the choices that preset starts from. Those aren't stored: looking at the page
    /// changes nothing, which matters most on a reminder that is locked while nudging (device
    /// check, ticket 27). The first choice made on the page stores them, and the repeat is Custom.
    var customChoices: CustomRepeat {
        get { customRepeat ?? currentEngine().customRepeat(from: presetRule, startingAt: dueTime) }
        set { customRepeat = newValue }
    }

    /// The Custom page's summary sentence: of the choices it shows, which are not yet the repeat
    /// while it is a preset or Never.
    var customPageSummary: String {
        currentEngine().repeatSummary(of: draft(tagIDs: tagIDs, repeatRule: customPageRule))
    }

    /// The Custom page's Next Times: when the choices it shows fall due.
    var customPageUpcomingDueTimes: [Date] {
        currentEngine().upcomingDueTimes(of: draft(tagIDs: tagIDs, repeatRule: customPageRule), count: Self.nextTimesCount)
    }

    /// The rule of the choices the Custom page shows.
    private var customPageRule: RepeatRule? {
        customRepeat == nil ? currentEngine().repeatRule(for: customChoices, startingAt: dueTime) : repeatRule
    }

    /// The Custom page's monthly choices for the start, each with its title ("On the fourth
    /// Monday"), from the engine.
    var monthlyDays: [(day: CustomRepeat.MonthlyDay, title: String)] {
        let engine = currentEngine()
        return engine.monthlyDays(startingAt: dueTime).map { ($0, engine.title(of: $0, startingAt: dueTime)) }
    }

    /// Under a monthly choice of the 29th to the 31st: such months are skipped. From the engine.
    var skippedMonthsNote: String? {
        currentEngine().skippedMonthsNote(of: customChoices, startingAt: dueTime)
    }

    /// A weekday's name for the Custom page, in the engine's locale.
    func name(of weekday: RepeatRule.Weekday) -> String {
        currentEngine().name(of: weekday)
    }

    /// The monthly choice the rule uses for the start, which the Custom page checks.
    var chosenMonthlyDay: CustomRepeat.MonthlyDay {
        currentEngine().monthlyDay(of: customChoices, startingAt: dueTime)
    }

    /// The Repeat row's preset, or `nil` when the rule is Custom. Setting a preset replaces a
    /// custom rule.
    var repeatPreset: RepeatPreset? {
        get { customRepeat == nil ? RepeatPreset(presetRule) : nil }
        set { if let newValue { repeatRule = newValue.rule } }
    }

    /// The engine's summary of the draft's repeat and time ("Every 3 days at 9:00 AM"), for the
    /// Starts footer and the Custom row.
    var repeatSummary: String {
        currentEngine().repeatSummary(of: draft(tagIDs: tagIDs))
    }

    /// The draft's ladder with its strength, pace and switch, for the form's How It Nudges
    /// (ticket 31).
    var howItNudges: HowItNudges {
        currentEngine().howItNudges(strength, pace: pace, breakThroughFocus: breakThroughFocus)
    }

    /// The line under the strength choice, from the same ladder.
    var strengthBlurb: StrengthBlurb {
        StrengthBlurb(howItNudges)
    }

    /// The line under the pace choice, from the same ladder.
    var paceBlurb: PaceBlurb {
        PaceBlurb(pace, howItNudges)
    }

    /// How many due times the Custom page's Next Times shows.
    static let nextTimesCount = 3

    /// The Custom page's Next Times: the draft's next three due times from the engine, fewer if
    /// the repeat ends first.
    var upcomingDueTimes: [Date] {
        currentEngine().upcomingDueTimes(of: draft(tagIDs: tagIDs), count: Self.nextTimesCount)
    }

    /// The time now, by the form's clock, for Next Times' Today and Tomorrow.
    var currentTime: Date { now() }

    /// Whether a Next Times date carries its year: only when it isn't this year, as the mockup's
    /// `nextDay`.
    func showsYear(of dueTime: Date) -> Bool {
        !Calendar.autoupdatingCurrent.isDate(dueTime, equalTo: now(), toGranularity: .year)
    }

    /// When the lock was last checked. Reading it in `lockedFields` is what makes a view that
    /// reads the lock redraw when `checkLock()` moves it: the engine's answer changes as the clock
    /// passes the due time, with no change anywhere the views can see.
    private var lockCheckedAt: Date?

    /// The fields the engine won't let an Edit change now (ticket 13). Read from the engine, so
    /// the form has no rule of its own; a new reminder has none.
    var lockedFields: Set<LockedField> {
        _ = lockCheckedAt
        return original.map { currentEngine().lockedFields(of: $0.id) } ?? []
    }

    /// Makes the views read the lock again, and puts the locked fields back as saved if it has
    /// arrived. The reminder falling due locks it with no event for the views to see, so the sheet
    /// calls this at the start of every minute while it is open.
    func checkLock() {
        lockCheckedAt = now()
        // A lock that has arrived discards what was changed on the fields it locks, at once: their
        // controls are disabled now, and a value that can't be saved shouldn't stay on screen
        // (the user's ruling, ticket 27). A title, notes or tags change is kept.
        guard let original, lockedFields.contains(where: { $0.isChanged(from: original, to: draft(tagIDs: tagIDs)) }) else { return }
        restoreLockedFields(from: original)
    }

    /// Checks the lock at the start of every minute until the task is cancelled. Only an Edit form
    /// has a lock.
    func keepTheLockCurrent() async {
        guard isEditing else { return }
        while (try? await EveryMinute.sleepUntilNext()) != nil {
            checkLock()
        }
    }

    var saveBlock: SaveBlock? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .noTitle }
        if dueTime <= now(), !keepsItsStart { return .pastTime }
        return repeatBlock
    }

    /// A reminder that keeps its start can still be renamed, whenever it fell due. The picker
    /// shows minutes, so the same minute is the same start.
    private var keepsItsStart: Bool {
        original.map { Calendar.autoupdatingCurrent.isDate($0.dueTime, equalTo: dueTime, toGranularity: .minute) } ?? false
    }

    /// Why the custom repeat can't be saved, shown on the Custom page whatever else blocks a save.
    var repeatBlock: SaveBlock? {
        guard let customRepeat else { return nil }
        if currentEngine().endsBeforeStart(customRepeat, startingAt: dueTime) { return .endsBeforeStart }
        let keepsItsSchedule = keepsItsStart && repeatRule == original?.repeatRule
        if !keepsItsSchedule, upcomingDueTimes.isEmpty { return .noTimesLeft }
        return nil
    }

    /// Every tag the Tags page offers: the saved ones, then the ones typed here.
    var tags: [Tag] { tagRules.tags }

    /// The Tags row: the chosen tags as `#name`, in the order chosen, or `nil` if there are none.
    /// Tokens separated by spaces as the mockup shows them, not a sentence, so not a list format.
    var chosenTagsText: String? {
        let labels = tagRules.tagLabels(for: tagIDs)
        return labels.isEmpty ? nil : labels.joined(separator: " ")
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
        draft(tagIDs: tagIDs, repeatRule: repeatRule)
    }

    private func draft(tagIDs: [Tag.ID], repeatRule: RepeatRule?) -> Reminder {
        Reminder(
            id: original?.id ?? newID,
            // One line: a pasted title's line breaks become spaces.
            title: title.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tagIDs: tagIDs,
            dueTime: dueTime,
            repeatRule: repeatRule,
            strength: strength,
            pace: pace,
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
