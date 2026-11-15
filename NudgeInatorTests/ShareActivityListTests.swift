import Foundation
import Testing
@testable import NudgeInator

/// What Settings › Share Activity lists (#397): the record's entries, newest first, each naming
/// who it concerns.
struct ShareActivityListTests {
    let english = Locale(identifier: "en_US")

    func entry(_ second: Double, _ names: [String], _ event: ShareActivityEntry.Event = .otherPersonLeft) -> ShareActivityEntry {
        ShareActivityEntry(at: Date(timeIntervalSince1970: second), connectionNames: names, event: event)
    }

    @Test func everyEntryIsListedNewestFirst() {
        let record = [
            entry(100, ["Alex Morgan"], .otherPersonLeft),
            entry(200, ["Robin Vega"], .connectionLost),
            entry(300, ["Maya Torres"], .changeGivenUp(.send)),
        ]

        let list = ShareActivityList(SharingData(activity: record), locale: english)

        #expect(list.rows.map(\.id) == [record[2].id, record[1].id, record[0].id])
        #expect(list.rows.map(\.at) == [300, 200, 100].map(Date.init(timeIntervalSince1970:)))
        #expect(list.rows.map(\.event) == [.changeGivenUp(.send), .connectionLost, .otherPersonLeft])
        #expect(list.rows.map(\.who) == ["Maya Torres", "Robin Vega", "Alex Morgan"])
    }

    @Test func severalNamesAreJoinedAsAListInThePersonsLanguage() {
        let data = SharingData(activity: [entry(100, ["Chris Nolan", "Pat Rivera", "Dana Kim"], .accountChanged)])

        #expect(ShareActivityList(data, locale: english).rows.map(\.who) == ["Chris Nolan, Pat Rivera, and Dana Kim"])
        #expect(ShareActivityList(data, locale: Locale(identifier: "es_ES")).rows.map(\.who) == ["Chris Nolan, Pat Rivera y Dana Kim"])
    }

    /// The store can hold an entry from before a waiting change kept its name: its row has no one
    /// to name, and still says what happened and when.
    @Test func anEntryWithNoNameHasNoOneToName() {
        let list = ShareActivityList(SharingData(activity: [entry(100, [], .changeGivenUp(.cancel))]), locale: english)

        #expect(list.rows.map(\.who) == [nil])
    }

    @Test func anEmptyRecordListsNothing() {
        #expect(ShareActivityList(SharingData(), locale: english).isEmpty)
        #expect(!ShareActivityList(SharingData(activity: [entry(100, ["Alex Morgan"])]), locale: english).isEmpty)
    }
}
