import Foundation
import NudgeEngine

/// A Done chosen while the store couldn't be read, before the first unlock after a restart
/// (ticket 32). Nothing personal: the file it is kept in has no data protection.
struct QueuedDone: Codable, Equatable, Sendable {
    var reminderID: Reminder.ID
    /// The due time of the occurrence the Done closes.
    var dueTime: Date
    /// When the person chose Done, which the occurrence closes at once the Done is merged.
    var doneAt: Date
}

/// The Dones that wait for the store, in a file readable before the first unlock. The store is
/// `completeUntilFirstUserAuthentication`, so it stays shut until then (ticket 21's device check),
/// and Apple's `noFileProtection` writes a file "your app can access ... at boot time". In the
/// app's own container, not the App Group's: the widget extension never reads it.
struct DoneQueue {
    let folder: URL

    static var standard: DoneQueue {
        DoneQueue(folder: .applicationSupportDirectory)
    }

    var file: URL {
        folder.appending(path: "queued-dones.json")
    }

    /// The Dones in the order they were chosen, or none if there is no file. A file that won't
    /// decode throws a `DecodingError`.
    func dones() throws -> [QueuedDone] {
        guard FileManager.default.fileExists(atPath: file.path()) else { return [] }
        return try JSONDecoder().decode([QueuedDone].self, from: Data(contentsOf: file))
    }

    /// Makes the folder, if it isn't there yet. The app does this while the store is open: Apple's
    /// docs say a `noFileProtection` file can be written at boot time, but not whether a folder can
    /// be made then, so a Done before the first unlock only writes the file.
    func makeFolder() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Adds the Done to those already waiting. The file is replaced whole, atomically, so a write
    /// cut short leaves the Dones before it. A file that won't decode is started again rather than
    /// losing this Done and every one after it.
    func add(_ done: QueuedDone) throws {
        let waiting: [QueuedDone]
        do {
            waiting = try dones()
        } catch is DecodingError {
            waiting = []
        }
        let dones = waiting + [done]
        try makeFolder()
        // `Date`'s own value, seconds since 2001, so the due time comes back exactly.
        try JSONEncoder().encode(dones).write(to: file, options: [.atomic, .noFileProtection])
    }

    /// Deletes the file, once its Dones are merged into the store.
    func removeAll() throws {
        guard FileManager.default.fileExists(atPath: file.path()) else { return }
        try FileManager.default.removeItem(at: file)
    }
}
