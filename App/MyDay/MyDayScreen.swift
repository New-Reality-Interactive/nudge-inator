import Foundation
import NudgeEngine

/// What the My Day tab shows, read from the engine at one moment: the four counts and the rows,
/// in time order. A value, so the tests and previews read it with no view.
struct MyDayScreen {
    var counts: [Count]
    var items: [Item]
    /// One token per chosen tag, or one for No Tags, each of which removes itself when tapped.
    let filterTokens: [FilterToken]
    /// "Due today with #home and #money", under the tokens when two or more tags are chosen.
    let filterSummary: LocalizedStringResource?
    /// What the list says when it has no rows, by the chosen count.
    let emptyMessage: LocalizedStringResource
    private let nowTime: String
    private let now: Date

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
        /// When the next nudge fires, while nudging and one is left.
        var nextNudgeTime: String?
        /// The reminder's tags that the engine holds.
        var tags: [TagLabel]

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
            case .left:
                let relative = dueTime.shortRelative(to: now)
                return LocalizedStringResource("\(relative)", comment: "My Day: under the title of an occurrence due later today. The placeholder is how soon, such as \"in 4 hr.\".")
            }
        }
    }

    struct FilterToken: Identifiable {
        enum Kind: Hashable {
            case tag(Tag.ID)
            case noTags
        }

        var kind: Kind
        /// "#home". `nil` for No Tags, whose words are the view's, so they are localized there.
        var tagText: String?

        var id: Kind { kind }
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
    /// marker.
    var rows: [Row] {
        guard !items.isEmpty else { return [] }
        let due = items.prefix { $0.dueTime <= now }
        return due.map(Row.item) + [.now(time: nowTime)] + items.dropFirst(due.count).map(Row.item)
    }

    private static func emptyMessage(forCount count: MyDayCount?) -> LocalizedStringResource {
        switch count {
        case nil:
            LocalizedStringResource("Nothing is due today.", comment: "My Day: the list when nothing is due today.")
        case .done:
            LocalizedStringResource("Nothing is done yet today.", comment: "My Day: the list when Done is chosen and nothing is done yet today.")
        case .nudging:
            LocalizedStringResource("Nothing is nudging you.", comment: "My Day: the list when Nudging is chosen and nothing is nudging.")
        case .missed:
            LocalizedStringResource("Nothing was missed today.", comment: "My Day: the list when Missed is chosen and nothing was missed today.")
        case .left:
            LocalizedStringResource("Nothing is left to do today.", comment: "My Day: the list when Left is chosen and nothing is left to do today.")
        }
    }

    /// Nothing is due: the app hosting tests, and previews without an engine.
    init(filter: MyDayFilter, now: Date) {
        self.now = now
        nowTime = now.formatted(date: .omitted, time: .shortened)
        counts = MyDayCount.allCases.map { Count(kind: $0, number: 0, isChosen: filter.count == $0) }
        items = []
        filterTokens = []
        filterSummary = nil
        emptyMessage = Self.emptyMessage(forCount: filter.count)
    }

    /// `now` is when the screen is drawn, the same moment as the engine's clock.
    init(engine: Engine, filter: MyDayFilter, now: Date) {
        let filter = filter.keeping(tagsIn: Set(engine.tags.map(\.id)))
        self.now = now
        let chosenTags = filter.tagIDs.compactMap { engine.tag(withID: $0) }
        if filter.noTags {
            filterTokens = [FilterToken(kind: .noTags, tagText: nil)]
        } else {
            filterTokens = chosenTags.map { FilterToken(kind: .tag($0.id), tagText: $0.label) }
        }
        // The tokens name the tags, so the line says only how they combine (ticket 20).
        if filter.noTags {
            filterSummary = LocalizedStringResource("Due today with no tags", comment: "My Day: under the No Tags filter token.")
        } else if chosenTags.count == 1 {
            filterSummary = LocalizedStringResource("Due today with the selected tag", comment: "My Day: under the filter token when one tag is chosen.")
        } else if chosenTags.count > 1 {
            filterSummary = switch filter.match {
            case .all:
                LocalizedStringResource("Due today with all selected tags", comment: "My Day: under the filter tokens when two or more tags are chosen and Match is All Tags.")
            case .any:
                LocalizedStringResource("Due today with any selected tags", comment: "My Day: under the filter tokens when two or more tags are chosen and Match is Any Tag.")
            }
        } else {
            filterSummary = nil
        }
        emptyMessage = Self.emptyMessage(forCount: filter.count)
        nowTime = engine.timeOfDay(of: now)
        let myDay = engine.myDay(tagFilter: filter.tagFilter)
        counts = MyDayCount.allCases.map { Count(kind: $0, number: myDay.count(of: $0), isChosen: filter.count == $0) }
        let reminders = Dictionary(engine.reminders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let shown = filter.count.map(myDay.items(countedIn:)) ?? myDay.items
        items = shown.compactMap { item in
            reminders[item.reminderID].map { Item(engine: engine, reminder: $0, item: item, chosen: Set(filter.tagIDs)) }
        }
    }
}

extension MyDayScreen.Item {
    init(engine: Engine, reminder: Reminder, item: MyDay.Item, chosen: Set<Tag.ID>) {
        self.reminder = reminder
        dueTime = item.dueTime
        time = engine.timeOfDay(of: item.dueTime)
        status = item.status
        let closed = engine.closedOccurrence(of: item.reminderID, dueAt: item.dueTime)
        closedTime = closed.map { engine.timeOfDay(of: $0.closedAt) }
        let nudging = engine.nudgingStatus(of: item.reminderID)
        nudgesSent = closed?.nudgesSent ?? nudging?.nudgesSent ?? 0
        nextNudgeTime = nudging?.nextNudge.map { engine.timeOfDay(of: $0.fireTime) }
        tags = reminder.tagIDs.compactMap { tagID in
            engine.tag(withID: tagID).map { MyDayScreen.TagLabel(text: $0.label, isChosen: chosen.contains(tagID)) }
        }
    }
}
