import Foundation
import NudgeEngine

/// What the Now tab shows, read from the engine at one moment: the nudge cards, Coming Up and the
/// Last 24 Hours, in the engine's order. A value, so the tests and previews read it with no view.
struct NowScreen {
    var nudging: [NudgeCard]
    var comingUp: [ComingUpRow]
    var lastDay: [ClosedRow]
    /// The engine's short date, so the subhead's day is in its time zone, as every other time is.
    private let shortDate: (Date) -> String

    /// Nothing to show: the app hosting tests, and previews without an engine.
    init() {
        nudging = []
        comingUp = []
        lastDay = []
        shortDate = { $0.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
    }

    init(engine: Engine) {
        shortDate = { engine.shortDate(of: $0) }
        let reminders = Dictionary(engine.reminders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        nudging = engine.nudgingOccurrences().compactMap { item in
            reminders[item.reminderID].flatMap { NudgeCard(engine: engine, reminder: $0) }
        }
        comingUp = engine.comingUp().compactMap { item in
            reminders[item.reminderID].map {
                ComingUpRow(
                    reminder: $0,
                    dueTime: item.dueTime,
                    day: engine.dayLabel(of: item.dueTime),
                    time: engine.timeOfDay(of: item.dueTime),
                    schedule: engine.repeatSummary(of: $0)
                )
            }
        }
        lastDay = engine.closedInLast24Hours().compactMap { item in
            reminders[item.reminderID].map {
                ClosedRow(reminder: $0, closed: item, day: engine.dayLabel(of: item.closedAt), time: engine.timeOfDay(of: item.closedAt))
            }
        }
    }

    /// The Now tab's badge: how many reminders are nudging. Zero hides it. Static, so the tab bar
    /// counts without building the whole screen.
    static func badgeCount(of engine: Engine) -> Int {
        engine.nudgingOccurrences().count
    }

    /// Under the title: today's date and what's nudging. The count is bold, which the view turns
    /// red, as the mockup's `<strong>`.
    func subhead(on date: Date) -> LocalizedStringResource {
        let day = shortDate(date)
        guard !nudging.isEmpty else {
            return LocalizedStringResource("\(day) · Nothing is nudging you", comment: "Now: under the title when nothing is nudging. The placeholder is today's short date, such as \"Sat, Oct 17\".")
        }
        return LocalizedStringResource("\(day) · **\(nudging.count) reminders nudging you**", comment: "Now: under the title; the bold part shows in red. 1: today's short date, such as \"Sat, Oct 17\". 2: how many reminders are nudging.")
    }
}

/// One nudge card: a reminder's open occurrence.
struct NudgeCard: Identifiable {
    var reminder: Reminder
    var status: NudgingStatus
    /// The reminder's tags as "#home".
    var tags: [String]
    var dueTime: String
    var nextNudgeTime: String?
    /// When it closes as Missed, for the line after its last nudge.
    var missedAtTime: String

    var id: Reminder.ID { reminder.id }
    var title: String { reminder.title }

    /// The reminder's card, or `nil` if it isn't nudging.
    init?(engine: Engine, reminder: Reminder) {
        guard let status = engine.nudgingStatus(of: reminder.id) else { return nil }
        self.reminder = reminder
        self.status = status
        tags = engine.tagLabels(for: reminder.tagIDs)
        dueTime = engine.timeOfDay(of: status.dueTime)
        nextNudgeTime = status.nextNudge.map { engine.timeOfDay(of: $0.fireTime) }
        missedAtTime = engine.timeOfDay(of: status.missedAt)
    }

    /// Under the title: the tags and the due time. The urgency is in the top row, with its glyph.
    var detail: LocalizedStringResource {
        guard !tags.isEmpty else {
            return LocalizedStringResource("Due \(dueTime)", comment: "Nudge card: under the title of a reminder with no tags. The placeholder is its due time, such as \"9:00 AM\".")
        }
        // Tags are tokens, so they're joined by spaces, not as a list in words.
        let tags = tags.joined(separator: " ")
        return LocalizedStringResource("\(tags) · due \(dueTime)", comment: "Nudge card: under the title. 1: the reminder's tags, such as \"#home #errands\". 2: its due time, such as \"9:00 AM\".")
    }

    /// What VoiceOver reads after the title. The card's top row and title are one element, so
    /// this says everything they and the details show, the strength first.
    var voiceOverValue: LocalizedStringResource {
        let strength = String(localized: reminder.strength.title)
        let detail = String(localized: detail)
        guard let next = status.nextNudge, let nextNudgeTime else {
            let lastNudge = String(localized: lastNudgeLine)
            return LocalizedStringResource("\(strength), nudge \(status.nudgesSent) of \(status.nudgesInAll), urgency \(status.urgency.name). \(detail). \(lastNudge)",
                                           comment: "VoiceOver value of a nudge card after its last nudge. 1: the strength, such as \"Gentle\". 2: the nudges sent. 3: the most it sends. 4: the urgency now, such as \"High\". 5: the tags and due time, such as \"#home · due 9:00 AM\". 6: the card's line saying that was the last nudge and when it closes as Missed.")
        }
        let via = String(localized: Self.via(next.delivery))
        return LocalizedStringResource("\(strength), nudge \(status.nudgesSent) of \(status.nudgesInAll), urgency \(status.urgency.name). \(detail). Next nudge \(nextNudgeTime): \(via), \(next.urgency.name).",
                                       comment: "VoiceOver value of a nudge card. 1: the strength, such as \"Gentle\". 2: the nudges sent. 3: the most it sends. 4: the urgency now, such as \"High\". 5: the tags and due time, such as \"#home · due 9:00 AM\". 6: the next nudge's time. 7: how it arrives, such as \"Alarm\". 8: its urgency.")
    }

    /// After the last nudge, in place of the next one; its VoiceOver value says the same.
    var lastNudgeLine: LocalizedStringResource {
        LocalizedStringResource("That was the last nudge. It closes as Missed at \(missedAtTime).",
                                comment: "Nudge card: after the occurrence's last nudge. The placeholder is when it gives up or the next occurrence takes over, such as \"11:17 AM\".")
    }

    /// How a nudge arrives, the mockup's `viaLabel`: a weaker one says why. Time Sensitive and
    /// ordinary notifications both read "Notification", as in the mockup.
    static func via(_ delivery: NudgeDelivery) -> LocalizedStringResource {
        switch delivery {
        case .alarm:
            LocalizedStringResource("Alarm", comment: "Nudge card: the next nudge rings as an alarm.")
        case .notification(weakerBecause: nil):
            LocalizedStringResource("Notification", comment: "Nudge card: the next nudge comes as a notification.")
        case .notification(weakerBecause: .alarmsOff):
            LocalizedStringResource("Notification: alarms are off", comment: "Nudge card: an Urgent nudge comes as a notification because alarms aren't allowed.")
        case .notification(weakerBecause: .alarmsAndTimeSensitiveOff):
            LocalizedStringResource("Notification: alarms and Time Sensitive are off", comment: "Nudge card: an Urgent nudge comes as an ordinary notification because alarms aren't allowed and Time Sensitive notifications are off.")
        case .notification(weakerBecause: .timeSensitiveOff):
            LocalizedStringResource("Notification: Time Sensitive is off", comment: "Nudge card: a High nudge comes as an ordinary notification because Time Sensitive notifications are off.")
        case .notification(weakerBecause: .breakThroughFocusOff):
            LocalizedStringResource("Notification: Break through Focus is off", comment: "Nudge card: a High or Urgent nudge comes as an ordinary notification because the reminder's Break through Focus switch is off.")
        case .notification(weakerBecause: .pastAlarmLimit):
            LocalizedStringResource("Notification: too many alarms scheduled", comment: "Nudge card: an Urgent nudge comes as a notification because the system's alarm limit is reached.")
        case .cannotArrive:
            LocalizedStringResource("Notifications off", comment: "Nudge card, in red: the next nudge can't arrive because notifications are off.")
        }
    }
}

/// One Coming Up row: a reminder's next due time.
struct ComingUpRow: Identifiable {
    var reminder: Reminder
    var dueTime: Date
    /// "Today", "Tomorrow" or a short date, under the time.
    var day: String
    var time: String
    /// The repeat summary, such as "Every day at 8:00 AM".
    var schedule: String

    var id: Reminder.ID { reminder.id }
    var title: String { reminder.title }
}

/// One Last 24 Hours row: an occurrence that closed.
struct ClosedRow: Identifiable {
    var reminder: Reminder
    var closed: ClosedOccurrence
    /// When it closed: "Today" or "Yesterday", under the time.
    var day: String
    var time: String

    /// A reminder can close twice in a day, so its ID alone isn't unique.
    var id: String { "\(reminder.id.uuidString) \(closed.occurrence.dueTime.timeIntervalSinceReferenceDate)" }
    var title: String { reminder.title }

    /// How it closed, under the title: the mockup's `closedLabel`.
    var detail: LocalizedStringResource {
        Self.detail(closingAs: closed.occurrence.state, nudgesSent: closed.nudgesSent)
    }

    /// Static so each closing can be checked, a take-over among them, which the shipped give-up
    /// limit never lets a fixture reach.
    static func detail(closingAs state: OccurrenceState, nudgesSent: Int) -> LocalizedStringResource {
        switch state {
        // A closed occurrence is never Nudging; the case is here only to make the switch whole.
        case .done, .nudging:
            LocalizedStringResource("Done after \(nudgesSent) nudges", comment: "Now, Last 24 Hours: under the title of an occurrence closed as Done. The placeholder is how many nudges it sent.")
        case .missed(reason: .giveUpLimit):
            LocalizedStringResource("Missed: gave up after the limit", comment: "Now, Last 24 Hours: under the title of an occurrence that reached its give-up limit (20 nudges or 24 hours).")
        case .missed(reason: .nextTookOver):
            LocalizedStringResource("Missed: the next one took over", comment: "Now, Last 24 Hours: under the title of an occurrence that closed because the repeat's next occurrence fell due.")
        case .skipped(reason: .paused):
            LocalizedStringResource("Skipped: the reminder was paused", comment: "Now, Last 24 Hours: under the title of an occurrence that closed because its reminder was paused.")
        }
    }
}
