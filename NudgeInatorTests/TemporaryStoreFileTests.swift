import Foundation
import Testing

/// Tests run on the physical iPhone leave it as they found it (AGENTS.md), so a store test's file
/// and SQLite's side files go when the test's suite instance does.
struct TemporaryStoreFileTests {
    @Test func releasingTheFileDeletesItAndItsSideFiles() throws {
        var file: TemporaryStoreFile? = TemporaryStoreFile()
        let url = try #require(file?.url)
        let sideFiles = ["-wal", "-shm"].map { URL(filePath: url.path() + $0) }
        for written in [url] + sideFiles {
            try Data("x".utf8).write(to: written)
        }

        file = nil

        #expect(([url] + sideFiles).allSatisfy { !FileManager.default.fileExists(atPath: $0.path()) })
    }
}
