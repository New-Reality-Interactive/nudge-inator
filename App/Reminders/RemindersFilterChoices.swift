import Foundation
import NudgeEngine

/// What the Reminders filter sheet has chosen, applied or as a draft. Search isn't part of it, so
/// Apply, Reset and Clear All Filters leave the search as it is. The tags are My Day's.
struct RemindersFilterChoices: Equatable {
    var tags = TagChoice()
    private(set) var statuses: Set<RemindersFilter.Status> = []
    private(set) var strengths: Set<Strength> = []
    private(set) var dueFrom: CalendarDay?
    private(set) var dueTo: CalendarDay?

    /// The Filter button's badge: how many of the sheet's sections are in use, not how many choices.
    var sectionsInUse: Int {
        [tags.isOn, !statuses.isEmpty, !strengths.isEmpty, dueFrom != nil || dueTo != nil].count { $0 }
    }

    func isChosen(_ status: RemindersFilter.Status) -> Bool { statuses.contains(status) }

    func isChosen(_ strength: Strength) -> Bool { strengths.contains(strength) }

    mutating func toggle(_ status: RemindersFilter.Status) {
        if statuses.remove(status) == nil { statuses.insert(status) }
    }

    mutating func toggle(_ strength: Strength) {
        if strengths.remove(strength) == nil { strengths.insert(strength) }
    }

    /// The first day a reminder may be due. It can't pass the last, so it stops there.
    mutating func setDueFrom(_ day: CalendarDay?) {
        dueFrom = day.map { min($0, dueTo ?? $0) }
    }

    /// The last day a reminder may be due. It can't pass the first, so it stops there.
    mutating func setDueTo(_ day: CalendarDay?) {
        dueTo = day.map { max($0, dueFrom ?? $0) }
    }

    /// What the list is narrowed by with this applied and `search` in the field.
    func narrowing(search: String) -> RemindersFilter {
        RemindersFilter(tags: tags.tagFilter, statuses: statuses, strengths: strengths, dueFrom: dueFrom, dueTo: dueTo, search: search)
    }

    /// The filter without tags that no longer exist, as My Day's.
    func keeping(tagsIn existing: Set<Tag.ID>) -> RemindersFilterChoices {
        var kept = self
        kept.tags = tags.keeping(tagsIn: existing)
        return kept
    }
}

extension RemindersFilter.Status {
    /// The status label's word, as a row shows it.
    var title: LocalizedStringResource {
        switch self {
        case .nudging: ReminderStatus.nudging.name
        case .comingUp: ReminderStatus.comingUp.name
        case .paused: ReminderStatus.paused.name
        case .done: ReminderStatus.closed(.done).name
        case .missed: ReminderStatus.closed(.missed(reason: .giveUpLimit)).name
        case .skipped: ReminderStatus.closed(.skipped(reason: .paused)).name
        }
    }
}
