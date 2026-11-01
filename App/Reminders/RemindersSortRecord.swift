import Foundation
import NudgeEngine

/// The Reminders tab's Sort menu choice, field and order, kept in `UserDefaults` so it outlives a
/// relaunch, as the Default Pace is. Delete All Data clears it. With nothing stored, or a value
/// this version doesn't know, it reads Created, Oldest First.
struct RemindersSortRecord {
    let defaults: UserDefaults

    static var standard: RemindersSortRecord { RemindersSortRecord(defaults: .standard) }

    private static let fieldKey = "remindersSortField"
    private static let orderKey = "remindersSortOrder"

    var sort: RemindersSort {
        get {
            let shipped = RemindersSort.createdOldestFirst
            let field = defaults.string(forKey: Self.fieldKey).flatMap(RemindersSort.Field.init(rawValue:))
            let order = defaults.string(forKey: Self.orderKey).flatMap(RemindersSort.Order.init(rawValue:))
            return RemindersSort(field: field ?? shipped.field, order: order ?? shipped.order)
        }
        nonmutating set {
            defaults.set(newValue.field.rawValue, forKey: Self.fieldKey)
            defaults.set(newValue.order.rawValue, forKey: Self.orderKey)
        }
    }

    /// Back to Created, Oldest First.
    func clear() {
        defaults.removeObject(forKey: Self.fieldKey)
        defaults.removeObject(forKey: Self.orderKey)
    }
}
