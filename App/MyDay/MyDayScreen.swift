import Foundation
import NudgeEngine

/// What the My Day tab shows, read from the engine at one moment: the four counts and the rows,
/// in time order. A value, so the tests and previews read it with no view.
struct MyDayScreen {
    var counts: [Count]
    var items: [Item]
    /// One token per chosen tag, or one for No Tags, then one for From others, each of which
    /// removes itself when tapped.
    let filterTokens: [FilterToken]
    /// "Due today with #home and #money", under the tokens when two or more tags are chosen.
    let filterSummary: LocalizedStringResource?
    /// What the list says when it has no rows, by the chosen count.
    let emptyMessage: LocalizedStringResource
    /// What VoiceOver says when My Day moves to this day: its label and how many are due with the
    /// filter's tags (#375).
    let announcement: LocalizedStringResource
    /// Whether the Filter button shows: a reminder is due on the day, or on another day a filter is
    /// on (#375), and a tag exists or someone has sent a reminder (ticket 209). With neither the sheet would offer only No Tags, which matches
    /// every row. Read from the whole day, not the rows the filter leaves, so a filter that empties
    /// the list keeps the button that clears it (Decision 56).
    let offersFilter: Bool
    private let nowTime: String
    private let now: Date
    /// The day listed, its label, its neighbours and its words (#375).
    let shown: MyDayShownDay

    struct Count: Identifiable {
        var kind: MyDayCount
        var number: Int
        /// The one the list is narrowed to.
        var isChosen: Bool
        /// Zero has nothing to show, so it can't be tapped, unless it's chosen: then it can be
        /// tapped again to show everything.
        var isEnabled: Bool { number > 0 || isChosen }

        var id: MyDayCount { kind }
    }

    /// One row: a reminder's due time today.
    struct Item: Identifiable {
        var reminder: Reminder
        var dueTime: Date
        /// The due time of day, in the engine's zone.
        var time: String
        var status: MyDay.Status
        /// When it closed, as a time of day, once it has.
        var closedTime: String?
        var nudgesSent: Int
        /// Under how it closed, how many of its nudges quiet hours held, on a Missed one (#369).
        var missedNote: MissedNote?
        /// When the next nudge fires, while nudging and one is left.
        var nextNudgeTime: String?
        /// The reminder's tags that the engine holds.
        var tags: [TagLabel]
        /// "From Riley Park" under the title of a received reminder, or `nil` (ticket 199).
        var from: FromLine?
        /// How it repeats, on a day after today, where it stands in for how soon (#375).
        var schedule: String?

        /// A reminder can be due twice in a day after an Edit, so its ID alone isn't unique.
        var id: String { "\(reminder.id.uuidString) \(dueTime.timeIntervalSinceReferenceDate)" }
        var title: String { reminder.title }
        /// Done is offered, as a swipe and a button, only while the occurrence is Nudging.
        var offersDone: Bool {
            if case .due(.nudging) = status { true } else { false }
        }

        /// Under the title, the mockup's `note`. `now` is when the row is drawn, for "in 4 hr.".
        func note(at now: Date) -> LocalizedStringResource {
            switch status {
            case .due(.done):
                guard let closedTime, nudgesSent > 0 else {
                    return LocalizedStringResource("Done at \(closedTime ?? time)", comment: "My Day: under the title of an occurrence closed as Done with no nudge sent. The placeholder is when it closed, such as \"7:04 AM\".")
                }
                return LocalizedStringResource("Done at \(closedTime) after \(nudgesSent) nudges", comment: "My Day: under the title of an occurrence closed as Done. 1: when it closed, such as \"7:04 AM\". 2: how many nudges it sent.")
            case .due(.nudging):
                guard let nextNudgeTime else {
                    return LocalizedStringResource("Nudging · \(nudgesSent) nudges", comment: "My Day: under the title of a Nudging occurrence with no nudge left. The placeholder is how many it sent.")
                }
                return LocalizedStringResource("Nudging · \(nudgesSent) nudges · next \(nextNudgeTime)", comment: "My Day: under the title of a Nudging occurrence. 1: how many nudges it has sent. 2: when the next one fires, such as \"1:15 PM\".")
            case .due(let state):
                return ClosedRow.detail(closingAs: state, nudgesSent: nudgesSent)
            case .paused:
                return LocalizedStringResource("Paused: this one will be skipped", comment: "My Day: under the title of an occurrence due later today whose reminder is paused.")
            case .waiting:
                return LocalizedStringResource("Waiting for you to accept", comment: "My Day: under the title of a reminder someone sent that waits for the person to accept it before it nudges.")
            case .canceled:
                return LocalizedStringResource("Canceled", comment: "My Day: under the title of a reminder someone sent that its sender deleted. It no longer nudges.")
            case .left:
                let soon = schedule ?? dueTime.shortRelative(to: now)
                return LocalizedStringResource("\(soon)", comment: "My Day: under the title of an occurrence still to come: on today how soon, such as \"in 4 hr.\"; on a later day how it repeats, such as \"Every day at 6:30 AM\".")
            }
        }
    }

    struct FilterToken: Identifiable {
        enum Kind: Hashable {
            case tag(Tag.ID)
            case noTags
            case fromOthers
        }

        var kind: Kind
        /// "#home". `nil` for No Tags and From others, whose words are the view's, so they are
        /// localized there.
        var tagText: String?

        var id: Kind { kind }

        var isTag: Bool {
            if case .tag = kind { true } else { false }
        }
    }

    /// A tag as "#home". The ones the filter chose show in bold.
    struct TagLabel: Equatable {
        var text: String
        var isChosen: Bool
    }

    /// One line of the list: a due time, or the marker for where the time is now.
    enum Row: Identifiable {
        case item(Item)
        case now(time: String)

        var id: String {
            switch self {
            case .item(let item): item.id
            case .now: "now"
            }
        }
    }

    /// The items with the "Now" marker among them, after those already due. An empty list has no
    /// marker, nor has another day's (#374).
    var rows: [Row] {
        // Only today has the "Now" marker.
        guard shown.isToday else { return items.map(Row.item) }
        guard !items.isEmpty else { return [] }
        let due = items.prefix { $0.dueTime <= now }
        return due.map(Row.item) + [.now(time: nowTime)] + items.dropFirst(due.count).map(Row.item)
    }

    /// Nothing is due: the app hosting tests, and previews without an engine.
    init(filter: MyDayFilter, now: Date) {
        self.now = now
        shown = MyDayShownDay(now: now)
        nowTime = now.formatted(date: .omitted, time: .shortened)
        counts = MyDayCount.allCases.map { Count(kind: $0, number: 0, isChosen: filter.count == $0) }
        items = []
        offersFilter = false
        filterTokens = []
        filterSummary = nil
        emptyMessage = shown.emptyMessage(forCount: filter.count)
        announcement = shown.announcement(due: 0, filtered: false)
    }

    /// `now` is when the screen is drawn, the same moment as the engine's clock. `senders` names
    /// who sent each received reminder; with none, each reads "From Someone". `day` is the day it
    /// lists, today if none (#374), kept inside the range (#375).
    init(engine: Engine, filter: MyDayFilter, now: Date, senders: Senders = Senders(), day: CalendarDay? = nil) {
        let filter = filter.keeping(tagsIn: Set(engine.tags.map(\.id)))
        self.now = now
        let shown = MyDayShownDay(engine: engine, asked: day)
        self.shown = shown
        let chosenTags = filter.tagIDs.compactMap { engine.tag(withID: $0) }
        let fromOthersToken = filter.fromOthers ? [FilterToken(kind: .fromOthers, tagText: nil)] : []
        if filter.noTags {
            filterTokens = [FilterToken(kind: .noTags, tagText: nil)] + fromOthersToken
        } else {
            filterTokens = chosenTags.map { FilterToken(kind: .tag($0.id), tagText: $0.label) }
                + fromOthersToken
        }
        // The tokens name the tags, so the line says only how they combine (ticket 20).
        if filter.noTags {
            filterSummary = shown.filterSummary(.noTags)
        } else if chosenTags.count == 1 {
            filterSummary = shown.filterSummary(.oneTag)
        } else if chosenTags.count > 1 {
            filterSummary = shown.filterSummary(filter.match == .all ? .all : .any)
        } else {
            filterSummary = nil
        }
        emptyMessage = shown.emptyMessage(forCount: filter.count)
        nowTime = engine.timeOfDay(of: now)
        let myDay = engine.myDay(on: shown.day, tagFilter: filter.tagFilter, fromOthers: filter.fromOthers)
        let wholeDay = engine.myDay(on: shown.day)
        // On another day a filter that's on keeps the button, so moving to a day with nothing due
        // doesn't clear it (#375). Today's rule is as before.
        let keepsFilter = !shown.isToday && filter.isOn
        offersFilter = (!engine.tags.isEmpty || engine.hasReceivedReminders) && (!wholeDay.items.isEmpty || keepsFilter)
        counts = MyDayCount.allCases.map { Count(kind: $0, number: myDay.count(of: $0), isChosen: filter.count == $0) }
        announcement = shown.announcement(due: myDay.items.count, filtered: filter.isOn)
        let isLater = shown.isLater
        let reminders = Dictionary(engine.reminders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let listed = filter.count.map(myDay.items(countedIn:)) ?? myDay.items
        items = listed.compactMap { item in
            reminders[item.reminderID].map { Item(engine: engine, reminder: $0, item: item, chosen: Set(filter.tagIDs), from: senders.fromLine(of: $0), isLater: isLater) }
        }
    }
}

extension MyDayScreen.Item {
    /// `isLater` says the row is on a day after today, where it says how it repeats.
    init(engine: Engine, reminder: Reminder, item: MyDay.Item, chosen: Set<Tag.ID>, from: FromLine?, isLater: Bool = false) {
        self.reminder = reminder
        self.from = from
        schedule = isLater ? engine.repeatSummary(of: reminder) : nil
        dueTime = item.dueTime
        time = engine.timeOfDay(of: item.dueTime)
        status = item.status
        let closed = engine.closedOccurrence(of: item.reminderID, dueAt: item.dueTime)
        closedTime = closed.map { engine.timeOfDay(of: $0.closedAt) }
        let nudging = engine.nudgingStatus(of: item.reminderID)
        nudgesSent = closed?.nudgesSent ?? nudging?.nudgesSent ?? 0
        missedNote = closed.flatMap(MissedNote.init)
        nextNudgeTime = nudging?.nextNudge.map { engine.timeOfDay(of: $0.fireTime) }
        tags = reminder.tagIDs.compactMap { tagID in
            engine.tag(withID: tagID).map { MyDayScreen.TagLabel(text: $0.label, isChosen: chosen.contains(tagID)) }
        }
    }
}
