import Foundation
import Testing
@testable import NudgeInator

/// The file a Done waits in while the store can't be read (ticket 32), over a folder of its own
/// in the temporary directory. A class so `deinit` removes the folder, even when a test fails.
final class DoneQueueTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "DoneQueueTests-\(UUID().uuidString)")
    var queue: DoneQueue { DoneQueue(folder: folder) }

    let pills = QueuedDone(
        reminderID: UUID(uuidString: "6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C")!,
        dueTime: NewYork.local(2026, 10, 16) + 0.1234567,
        doneAt: NewYork.local(2026, 10, 16, 9, 10, 30)
    )
    let bins = QueuedDone(
        reminderID: UUID(uuidString: "0A1B2C3D-4E5F-4061-8273-8495A6B7C8D9")!,
        dueTime: NewYork.local(2026, 10, 16, 7),
        doneAt: NewYork.local(2026, 10, 16, 9, 11)
    )

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    @Test func anEmptyQueueHoldsNoDones() throws {
        #expect(try queue.dones().isEmpty)
    }

    /// Each Done is added to those already waiting, in the order chosen. The due time comes back
    /// exactly, or the engine wouldn't find the occurrence.
    @Test func donesComeBackInTheOrderTheyWereAdded() throws {
        try queue.add(pills)
        try queue.add(bins)

        #expect(try queue.dones() == [pills, bins])
    }

    @Test func removingTheDonesDeletesTheFile() throws {
        try queue.add(pills)

        try queue.removeAll()

        #expect(!FileManager.default.fileExists(atPath: queue.file.path()))
        #expect(try queue.dones().isEmpty)
    }

    /// The file is written without data protection, so it holds nothing personal: the reminder,
    /// which occurrence, and when Done was chosen.
    @Test func theFileHoldsOnlyTheReminderTheDueTimeAndWhenDoneWasChosen() throws {
        try queue.add(pills)

        let entries = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: queue.file)) as? [[String: Any]])
        #expect(entries.map { Set($0.keys) } == [["reminderID", "dueTime", "doneAt"]])
    }

    /// A file that won't decode would otherwise lose this Done and every one after it.
    @Test func aDoneAddedToAFileThatWontDecodeStartsItAgain() throws {
        try queue.makeFolder()
        try Data("not a list of Dones".utf8).write(to: queue.file)

        try queue.add(pills)

        #expect(try queue.dones() == [pills])
    }

    @Test func aFolderThatCantBeMadeThrows() throws {
        try Data().write(to: folder)

        #expect(throws: (any Error).self) { try self.queue.add(self.pills) }
    }
}
