#if DEBUG
import Foundation
import NudgeEngine

/// What the seed needs of the app's model. The app's own add and delete are behind it, so seeded
/// data is stored and scheduled like data made by hand.
@MainActor
public protocol SeedTarget {
    var now: Date { get }
    var reminders: [Reminder] { get }
    var tags: [Tag] { get }
    func add(_ reminder: Reminder)
    func delete(_ reminderID: Reminder.ID)
    /// The new tag, or `nil` if it couldn't be made.
    func createTag(named name: String) -> Tag?
    func deleteTag(_ tagID: Tag.ID)
    func setting(_ setting: SeedSetting) -> String
    func setSetting(_ setting: SeedSetting, to value: String)
}
#endif
