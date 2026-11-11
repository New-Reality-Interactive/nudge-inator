import Foundation
import NudgeEngine

/// A change note as the bytes the sharing store and the sent reminder's CloudKit record both keep.
/// The field names and values are spelled out here, not taken from the engine's case names, so
/// renaming a case can't change what is on disk or in iCloud.
extension [ReceivedChange] {
    /// `nil` for a note with nothing in it.
    func storedData() throws -> Data? {
        isEmpty ? nil : try JSONEncoder().encode(map(StoredChange.init))
    }

    init(storedData: Data?) throws {
        guard let storedData else {
            self = []
            return
        }
        do {
            self = try JSONDecoder().decode([StoredChange].self, from: storedData).map { try $0.change() }
        } catch let error as StoreError {
            throw error
        } catch {
            throw StoreError.unreadable(field: .changeNote, value: String(describing: error))
        }
    }
}

/// One field of the note, with its old and new values. A repeat that came or went has no value on
/// that side.
private struct StoredChange: Codable {
    var field: String
    var from: StoredValue?
    var to: StoredValue?

    /// A field's value: which parts are set depends on the field.
    struct StoredValue: Codable {
        var text: String?
        var time: Date?
        var repeatRule: String?
        var repeatMissingDay: String?
        var repeatUntilTime: Date?
        var wait: Double?
        var flag: Bool?

        init(text: String) { self.text = text }
        init(time: Date) { self.time = time }
        init(flag: Bool) { self.flag = flag }

        init(_ rule: RepeatRule) {
            (repeatRule, repeatMissingDay, repeatUntilTime) = rule.storedValue
        }

        init(_ pace: Pace) {
            (text, wait) = pace.storedValue
        }
    }

    init(_ change: ReceivedChange) {
        switch change {
        case .title(let from, let to):
            (field, self.from, self.to) = ("title", .init(text: from), .init(text: to))
        case .notes(let from, let to):
            (field, self.from, self.to) = ("notes", .init(text: from), .init(text: to))
        case .dueTime(let from, let to):
            (field, self.from, self.to) = ("dueTime", .init(time: from), .init(time: to))
        case .repeatRule(let from, let to):
            (field, self.from, self.to) = ("repeatRule", from.map(StoredValue.init), to.map(StoredValue.init))
        case .strength(let from, let to):
            (field, self.from, self.to) = ("strength", .init(text: from.storedValue), .init(text: to.storedValue))
        case .pace(let from, let to):
            (field, self.from, self.to) = ("pace", .init(from), .init(to))
        case .breakThroughFocus(let from, let to):
            (field, self.from, self.to) = ("breakThroughFocus", .init(flag: from), .init(flag: to))
        }
    }

    func change() throws -> ReceivedChange {
        switch field {
        case "title": .title(from: try read(from?.text), to: try read(to?.text))
        case "notes": .notes(from: try read(from?.text), to: try read(to?.text))
        case "dueTime": .dueTime(from: try read(from?.time), to: try read(to?.time))
        case "repeatRule": .repeatRule(from: try rule(from), to: try rule(to))
        case "strength": .strength(from: try Strength(storedValue: try read(from?.text)), to: try Strength(storedValue: try read(to?.text)))
        case "pace": .pace(from: try pace(from), to: try pace(to))
        case "breakThroughFocus": .breakThroughFocus(from: try read(from?.flag), to: try read(to?.flag))
        default: throw StoreError.unreadable(field: .changeNote, value: field)
        }
    }

    private func read<Value>(_ value: Value?) throws -> Value {
        guard let value else { throw StoreError.unreadable(field: .changeNote, value: field) }
        return value
    }

    private func rule(_ value: StoredValue?) throws -> RepeatRule? {
        guard let value else { return nil }
        return try RepeatRule(storedRRULE: try read(value.repeatRule), missingDay: value.repeatMissingDay, untilTime: value.repeatUntilTime)
    }

    private func pace(_ value: StoredValue?) throws -> Pace {
        try Pace(storedKind: try read(value?.text), wait: value?.wait)
    }
}
