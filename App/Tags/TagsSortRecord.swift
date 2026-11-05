import Foundation
import NudgeEngine

/// The Tags tab's Sort menu choice, field and order, kept in `UserDefaults` so it outlives a
/// relaunch, apart from the Reminders tab's. Delete All Data clears it. With nothing stored, or a
/// value this version doesn't know, it reads Name, A to Z.
struct TagsSortRecord {
    let defaults: UserDefaults

    static var standard: TagsSortRecord { TagsSortRecord(defaults: .standard) }

    private static let fieldKey = "tagsSortField"
    private static let orderKey = "tagsSortOrder"

    var sort: TagSort {
        get {
            let shipped = TagSort.nameAToZ
            let field = defaults.string(forKey: Self.fieldKey).flatMap(TagSort.Field.init(rawValue:))
            let order = defaults.string(forKey: Self.orderKey).flatMap(TagSort.Order.init(rawValue:))
            return TagSort(field: field ?? shipped.field, order: order ?? shipped.order)
        }
        nonmutating set {
            defaults.set(newValue.field.rawValue, forKey: Self.fieldKey)
            defaults.set(newValue.order.rawValue, forKey: Self.orderKey)
        }
    }

    /// Back to Name, A to Z.
    func clear() {
        defaults.removeObject(forKey: Self.fieldKey)
        defaults.removeObject(forKey: Self.orderKey)
    }
}
