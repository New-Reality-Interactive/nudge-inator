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
    /// Never (`nil`) or a preset's rule, while the repeat isn't custom. With no end: End Repeat
    /// holds it.
    private var presetRule: RepeatRule?
    /// End Repeat: how the repeat ends, for a preset or a custom repeat alike (#287). Kept when the
    /// repeat changes, and put back to Never only with the repeat.
    var repeatEnd: RepeatEnd
    /// A rule's end as it was set, with the End Repeat it was read into. End Repeat writes a date,
    /// so a rule that ends at a time keeps it until End Repeat changes, as `setCustomRule` keeps a
    /// rule's other parts.
    private var setEnd: (end: RepeatRule.End?, repeatEnd: RepeatEnd)?
    /// A custom rule as it was set, with the choices it was read into and the start then. The
    /// page has no control for some parts of a rule (BYMONTH, say), so the rule is kept as it
    /// came until a choice or the start changes (decision 5, ticket 25).
    private var setCustomRule: (rule: RepeatRule, choices: CustomRepeat, dueTime: Date)?
    var strength = Strength.firm
    /// The person's switch, as saved. Relentless ignores it but keeps it, so leaving Relentless
    /// gives it back; the form shows `breaksThroughFocus`.
    var breakThroughFocus = true
    /// The Pace control: Escalating or Consistent. A New form sets both from the Default Pace; an
    /// Edit form sets them from the reminder, except an Escalating one's wait, which keeps 10 min.
    var paceChoice = DefaultPace.shipped.choice
    /// The Every row's wait, one of `Pace.consistentWaits`. Kept while Escalating is chosen, so
    /// choosing Consistent again finds it (spec story 25).
    var consistentWait = DefaultPace.shipped.consistentWait

    /// The connections of the people chosen in Send To (ticket 198), in the order chosen, including
    /// any who have stopped being connected since: `recipients` leaves those out.
    private var chosen: [UUID] = []
    /// Set when Add couldn't send it: the store wouldn't keep it. The sheet says so, and the person
    /// can try again.
    var isShowingCouldntSend = false
    /// Set when Save found the sent reminder deleted while the form was open (ticket 201): there is
    /// nothing left to save, so the sheet says so and closes.
    var isShowingDeletedMeanwhile = false

    /// The draft's pace, from the Pace control and the Every row.
    var pace: Pace {
        paceChoice.pace(wait: consistentWait)
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
        /// A repeat whose End Repeat date is before its start's day.
        case endsBeforeStart
        /// A repeat that has already ended, so it would never fall due again. A saved reminder
        /// that keeps its start and repeat is fine, so it can still be renamed.
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
    /// Sharing, for Send To and its Invite Someone New, or `nil` when the app has none (the shipped
    /// app until #216) or the form edits a reminder.
    let sharing: SharingModel?

    /// The reminder being edited, or `nil` for a new one.
    private let original: Reminder?
    /// A new reminder's ID.
    private let newID = UUID()
    /// Set once a save is accepted, so a second tap on Save before the sheet closes adds nothing.
    private var isSaved = false
    /// The draft as the form opened, set once `init` has filled it in.
    private var opened: Reminder?

    /// A New Reminder form, starting with Settings' Default Pace (spec story 39). `tagIDs` are
    /// chosen when it opens, as from a tag's screen. Neither is a change the person made.
    /// `sharing` offers Send To.
    init(engine currentEngine: @escaping () -> Engine, now: @escaping () -> Date, defaultPace: DefaultPace, tagIDs: [Tag.ID] = [], sharing: SharingModel? = nil) {
        self.tagIDs = tagIDs
        self.sharing = sharing
        paceChoice = defaultPace.choice
        consistentWait = defaultPace.consistentWait
        self.currentEngine = currentEngine
        tagRules = currentEngine()
        self.now = now
        original = nil
        senderName = nil
        isSent = false
        let dueTime = Self.nextWholeHour(after: now())
        self.dueTime = dueTime
        repeatEnd = currentEngine().repeatEnd(of: nil, startingAt: dueTime)
        opened = draft(tagIDs: tagIDs)
    }

    /// A new reminder's start: the next whole hour in the person's time zone, which can't have
    /// passed by the time they save.
    private static func nextWholeHour(after date: Date) -> Date {
        Calendar.autoupdatingCurrent.nextDate(after: date, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) ?? date
    }

    /// The sender of a received reminder, who owns its content, for the form's note (ticket 200),
    /// or `nil` for the person's own.
    let senderName: String?

    /// An Edit form for a reminder the engine holds, or `nil` if it doesn't hold it. `senders` names
    /// a received reminder's sender.
    convenience init?(engine currentEngine: @escaping () -> Engine, editing reminderID: Reminder.ID, now: @escaping () -> Date, senders: Senders = Senders()) {
        guard let reminder = currentEngine().reminders.first(where: { $0.id == reminderID }) else { return nil }
        self.init(engine: currentEngine, original: reminder, now: now, senderName: senders.name(of: reminder), isSent: false)
    }

    /// The sender's Edit form for a reminder they sent (ticket 201), as the sharing store keeps it.
    /// It has no Tags row and no Send To, and nothing is locked: the engine doesn't hold it, and a
    /// sender's change passes the copies' lock (ADR 0005). Save sends the change to its recipients.
    convenience init(engine currentEngine: @escaping () -> Engine, editingSent reminder: Reminder, now: @escaping () -> Date) {
        self.init(engine: currentEngine, original: reminder, now: now, senderName: nil, isSent: true)
    }

    /// Whether this is the sender's form for a reminder they sent (ticket 201).
    let isSent: Bool

    private init(engine currentEngine: @escaping () -> Engine, original reminder: Reminder, now: @escaping () -> Date, senderName: String?, isSent: Bool) {
        let engine = currentEngine()
        self.currentEngine = currentEngine
        tagRules = engine
        self.now = now
        sharing = nil
        original = reminder
        self.senderName = senderName
        self.isSent = isSent
        title = reminder.title
        notes = reminder.notes
        tagIDs = reminder.tagIDs
        dueTime = reminder.dueTime
        // Every stored property is set before `repeatRule`'s setter runs; it then reads the
        // reminder's end into End Repeat.
        repeatEnd = engine.repeatEnd(of: nil, startingAt: reminder.dueTime)
        repeatRule = reminder.repeatRule
        strength = reminder.strength
        breakThroughFocus = reminder.breakThroughFocus
        setPaceControls(to: reminder.pace)
        opened = draft(tagIDs: tagIDs)
    }

    /// The Edit form, rather than New: its title and Save's label.
    var isEditing: Bool { original != nil }

    /// A received reminder's form (ticket 200): its sender owns the title and notes, which are
    /// read-only, and every schedule field, which is locked. Only the tags can change.
    var isContentLocked: Bool { original?.isReceived == true }

    /// Whether Cancel should ask before throwing the draft away (the mockup's `draftDirty`). The
    /// Custom sheet's changes are in the draft as they're made (#284), so they count too.
    var hasChanges: Bool {
        draft(tagIDs: tagIDs) != opened || !recipients.isEmpty
    }

    /// Whether the form has a Send To row: a New form, with sharing.
    var offersSendTo: Bool { sharing != nil }

    /// The people Send To offers: those connected, as Connections lists them. With no one, the
    /// row offers only Invite Someone New.
    var sendToChoices: [SharingConnection] { sharing?.connected ?? [] }

    /// Why Send To is shown off (ticket 210), or `nil` while sharing works: without iCloud nothing
    /// can be sent, so the row says so and no one chosen counts.
    var sendToPause: SharingReach.Pause? { sharing?.pause }

    /// Send To (ticket 198): the connections of the people chosen to send it to, in the order chosen.
    /// With anyone chosen, Add sends it to them instead of adding it to the person's own reminders.
    /// Someone chosen who stops being connected while the form is open drops off, so the row always
    /// shows who it goes to. While sharing is paused no one counts, so Add sends nothing; whoever
    /// was chosen comes back once it works again.
    var recipients: [UUID] {
        guard sendToPause == nil else { return [] }
        let connected = Set(sendToChoices.map(\.id))
        return chosen.filter(connected.contains)
    }

    /// Whether the person with the connection `connectionID` is chosen in Send To.
    func isRecipient(_ connectionID: UUID) -> Bool {
        recipients.contains(connectionID)
    }

    /// A row on the Send To page: chooses the person, or unchooses them.
    func toggleRecipient(_ connectionID: UUID) {
        if let index = chosen.firstIndex(of: connectionID) {
            chosen.remove(at: index)
        } else {
            chosen.append(connectionID)
        }
    }

    /// The chosen people's whole names (#194), in the order Send To lists them.
    var recipientNames: [String] {
        let recipients = Set(recipients)
        return sendToChoices.filter { recipients.contains($0.id) }.map(\.name)
    }

    /// The chosen people's names as one list ("Riley Park and Sam Rivera"), for the row and its
    /// footer, or `nil` when no one is chosen.
    var recipientsText: String? {
        let names = recipientNames
        return names.isEmpty ? nil : names.formatted(.list(type: .and))
    }

    /// Whether the form has a Tags row: not with anyone chosen in Send To, nor for a reminder already
    /// sent, since a sent reminder has no tags. The chosen tags are kept, and come back if no one is
    /// chosen.
    var showsTags: Bool { recipients.isEmpty && !isSent }

    /// `nil` repeats Never. The repeat's pattern (a preset's rule, or a custom repeat's, built from
    /// its choices and the start, so a monthly choice a new start doesn't offer falls back to the
    /// day of the month) ending as End Repeat says. Setting a rule reads its end into End Repeat,
    /// and the rest into a preset, or into the Custom page's choices when it isn't one, so a preset
    /// with an end is still that preset (#287). Setting Never puts End Repeat back to Never.
    var repeatRule: RepeatRule? {
        get {
            (customRepeat.map(pattern(for:)) ?? presetRule).map(withEnd)
        }
        set {
            let engine = currentEngine()
            var pattern = newValue
            pattern?.end = nil
            let end = engine.repeatEnd(of: newValue, startingAt: dueTime)
            repeatEnd = end
            setEnd = (newValue?.end, end)
            if let preset = RepeatPreset(pattern) {
                presetRule = preset.rule
                customRepeat = nil
            } else if let pattern {
                let choices = engine.customRepeat(from: pattern, startingAt: dueTime)
                customRepeat = choices
                setCustomRule = (pattern, choices, dueTime)
            }
        }
    }

    /// Whether End Repeat shows: for every repeat but Never, as in Apple's Reminders.
    var showsEndRepeat: Bool { customRepeat != nil || presetRule != nil }

    /// The pattern ending as End Repeat says, or as the rule that was set did while End Repeat is
    /// as it was read.
    private func withEnd(_ pattern: RepeatRule) -> RepeatRule {
        if let setEnd, setEnd.repeatEnd == repeatEnd {
            var rule = pattern
            rule.end = setEnd.end
            return rule
        }
        return currentEngine().rule(pattern, ending: repeatEnd)
    }

    /// A custom repeat's pattern, with no end: the one that was set while its choices and start
    /// are as it was read, or else the one built from the choices.
    private func pattern(for choices: CustomRepeat) -> RepeatRule {
        if let setCustomRule, setCustomRule.choices == choices, setCustomRule.dueTime == dueTime { return setCustomRule.rule }
        return currentEngine().repeatRule(for: choices, startingAt: dueTime)
    }

    /// A custom repeat's rule, ending as End Repeat says.
    private func rule(for choices: CustomRepeat) -> RepeatRule {
        withEnd(pattern(for: choices))
    }

    /// The repeat's choices: the custom choices, or, while the repeat is a preset or Never, the
    /// choices that preset starts the Custom page from.
    private var repeatChoices: CustomRepeat {
        customRepeat ?? currentEngine().customRepeat(from: presetRule, startingAt: dueTime)
    }

    /// What the Custom sheet shows and edits: the repeat's choices. Each change is the form's
    /// custom repeat as it's made, as in Apple's Reminders (#284), so closing the sheet, by Apply
    /// or a swipe down, has nothing left to apply or drop. Reading stores nothing, so looking at
    /// the sheet changes nothing, which matters most on a reminder that is locked while nudging
    /// (device check, ticket 27).
    var customPageChoices: CustomRepeat {
        get { repeatChoices }
        set { customRepeat = newValue }
    }

    /// The Custom page's summary sentence, of the choices it shows, without the end: End Repeat is
    /// the form's (#287).
    var customPageSummary: String {
        currentEngine().repeatSummary(of: draft(tagIDs: tagIDs, repeatRule: pattern(for: customPageChoices)))
    }

    /// The Custom page's Next Times: when the choices it shows fall due.
    var customPageUpcomingDueTimes: [Date] {
        upcomingDueTimes(of: rule(for: customPageChoices))
    }

    private func upcomingDueTimes(of rule: RepeatRule) -> [Date] {
        currentEngine().upcomingDueTimes(of: draft(tagIDs: tagIDs, repeatRule: rule), count: Self.nextTimesCount)
    }

    /// The Custom page's monthly choices for the start, each with its title ("On the fourth
    /// Monday"), from the engine.
    var monthlyDays: [(day: CustomRepeat.MonthlyDay, title: String)] {
        let engine = currentEngine()
        return engine.monthlyDays(startingAt: dueTime).map { ($0, engine.title(of: $0, startingAt: dueTime)) }
    }

    /// Under a monthly choice of the 29th to the 31st: such months are skipped. From the engine.
    var skippedMonthsNote: String? {
        currentEngine().skippedMonthsNote(of: customPageChoices, startingAt: dueTime)
    }

    /// A weekday's name for the Custom page, in the engine's locale.
    func name(of weekday: RepeatRule.Weekday) -> String {
        currentEngine().name(of: weekday)
    }

    /// The monthly choice the rule uses for the start, which the Custom page checks.
    var chosenMonthlyDay: CustomRepeat.MonthlyDay {
        currentEngine().monthlyDay(of: customPageChoices, startingAt: dueTime)
    }

    /// The Repeat row's preset, or `nil` when the rule is Custom. Setting a preset replaces a
    /// custom rule and keeps End Repeat; Never puts it back to Never (#287).
    var repeatPreset: RepeatPreset? {
        get { customRepeat == nil ? RepeatPreset(presetRule) : nil }
        set {
            guard let newValue else { return }
            presetRule = newValue.rule
            customRepeat = nil
            if newValue == .never { repeatEnd.ending = .never }
        }
    }

    /// Whether the repeat is Custom, which the Repeat menu checks and the Custom row shows.
    var isCustomRepeat: Bool { customRepeat != nil }

    /// The Repeat menu's Custom: the repeat becomes a custom one, starting from the choices the
    /// current preset gives the Custom page (from Never, weekly). A rule that is already custom
    /// stays as it is.
    func chooseCustomRepeat() {
        guard customRepeat == nil else { return }
        customRepeat = repeatChoices
    }

    /// The engine's summary of the draft's repeat and time, end included ("Every 3 days at 9:00 AM,
    /// 10 times"), for the footer under the section, whatever the repeat (#287).
    var repeatSummary: String {
        currentEngine().repeatSummary(of: draft(tagIDs: tagIDs))
    }

    /// The same without the end ("Every 3 days at 9:00 AM"), for the Custom row: End Repeat and the
    /// footer say the end (#287).
    var repeatPatternSummary: String {
        var pattern = repeatRule
        pattern?.end = nil
        return currentEngine().repeatSummary(of: draft(tagIDs: tagIDs, repeatRule: pattern))
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

    /// The draft's next three due times from the engine, fewer if the repeat ends first.
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
        if isContentLocked { return Set(LockedField.allCases) }
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
        // A received reminder saves its tags alone, whatever its schedule.
        if isContentLocked { return nil }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .noTitle }
        if dueTime <= now(), !keepsItsStart { return .pastTime }
        return repeatBlock
    }

    /// A reminder that keeps its start can still be renamed, whenever it fell due. The picker
    /// shows minutes, so the same minute is the same start.
    private var keepsItsStart: Bool {
        original.map { Calendar.autoupdatingCurrent.isDate($0.dueTime, equalTo: dueTime, toGranularity: .minute) } ?? false
    }

    /// Why the repeat, preset or custom, can't be saved. Never has no end, so nothing blocks it.
    var repeatBlock: SaveBlock? {
        guard let repeatRule else { return nil }
        if currentEngine().endsBeforeStart(repeatEnd, startingAt: dueTime) { return .endsBeforeStart }
        return block(of: repeatRule)
    }

    /// A rule with no times left, unless it is the saved one with its saved start.
    private func block(of rule: RepeatRule) -> SaveBlock? {
        let keepsItsSchedule = keepsItsStart && rule == original?.repeatRule
        if !keepsItsSchedule, upcomingDueTimes(of: rule).isEmpty { return .noTimesLeft }
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
        if original == nil, !recipients.isEmpty {
            do {
                // Sharing leaves the tags out: a sent reminder has none.
                try model.send(draft(tagIDs: tagIDs), to: recipients)
            } catch {
                isShowingCouldntSend = true
                return false
            }
            isSaved = true
            return true
        }
        guard let original else {
            model.add(draft(tagIDs: savedTagIDs(through: model)))
            isSaved = true
            return true
        }
        if isContentLocked { return saveTags(of: original, to: model) }
        if isSent { return saveSent(to: model) }
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

    /// The sender's Save of a reminder they sent (ticket 201): the draft goes to its recipients
    /// through sharing. `false`, with the form saying so, if sharing couldn't keep it or it was
    /// deleted meanwhile.
    private func saveSent(to model: AppModel) -> Bool {
        do {
            try model.reviseSent(draft(tagIDs: []))
        } catch is SharingModel.SentReminderGone {
            isShowingDeletedMeanwhile = true
            return false
        } catch {
            isShowingCouldntSend = true
            return false
        }
        isSaved = true
        return true
    }

    /// A received reminder's Save: the reminder as it is, with the chosen tags, so nothing the
    /// sender owns can change, even as the draft writes it (a title's spaces, say). `false` if the
    /// engine turned it down.
    private func saveTags(of original: Reminder, to model: AppModel) -> Bool {
        var edited = model.engine.reminders.first { $0.id == original.id } ?? original
        edited.tagIDs = savedTagIDs(through: model)
        do throws(EditError) {
            try model.edit(edited)
            isSaved = true
            return true
        } catch {
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
            case .pace: setPaceControls(to: reminder.pace)
            case .breakThroughFocus: breakThroughFocus = reminder.breakThroughFocus
            }
        }
    }

    /// Sets the Pace control and the Every row to show `pace`. An Escalating pace leaves the
    /// Every row's wait as it is.
    private func setPaceControls(to pace: Pace) {
        paceChoice = PaceChoice(pace)
        if case .consistent(let wait) = pace { consistentWait = wait }
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
