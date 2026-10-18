import NudgeEngine

/// What came of Resume after the person edited a paused reminder whose Resume was turned down for
/// want of a time.
enum ResumeAfterEdit: Equatable {
    /// The Edit gave it a time to resume at, and it is back.
    case resumed
    /// The reminder is as it was (Cancel), so there is nothing to resume or to say.
    case unchanged
    /// The Edit changed something else and left no time, so the screen asks for one again.
    case needsNewDueTime
}

extension AppModel {
    /// Resumes the reminder if the Edit that just closed changed it from `before`.
    @discardableResult
    func resumeAfterEdit(of before: Reminder) -> ResumeAfterEdit {
        guard let current = engine.reminders.first(where: { $0.id == before.id }), current != before else { return .unchanged }
        do {
            try resume(before.id)
            return .resumed
        } catch {
            return .needsNewDueTime
        }
    }
}
