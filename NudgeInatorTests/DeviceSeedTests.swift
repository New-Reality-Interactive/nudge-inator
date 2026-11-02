#if DEBUG
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The app side of the device seed. The load and removal decisions are tested in the
/// NudgeEngine package's NudgeDeviceSeed tests; this is the setting text and the record's storage.
final class DeviceSeedTests {
    let suiteName = "DeviceSeedTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    @Test(arguments: [
        RemindersSort(field: .created, order: .ascending),
        RemindersSort(field: .dueDate, order: .descending),
    ])
    func aSortSurvivesBeingWrittenAndRead(sort: RemindersSort) {
        #expect(SeedSettingText.remindersSort(from: SeedSettingText.text(of: sort)) == sort)
    }

    @Test(arguments: [DefaultPace.shipped, DefaultPace(choice: .escalating, consistentWait: 900)])
    func aDefaultPaceSurvivesBeingWrittenAndRead(pace: DefaultPace) {
        #expect(SeedSettingText.defaultPace(from: SeedSettingText.text(of: pace)) == pace)
    }

    @Test func textTheAppDoesntKnowIsIgnored() {
        #expect(SeedSettingText.remindersSort(from: "title.ascending") == nil)
        #expect(SeedSettingText.remindersSort(from: "created") == nil)
        #expect(SeedSettingText.defaultPace(from: "consistent.7") == nil)
        #expect(SeedSettingText.defaultPace(from: "nonsense.600") == nil)
    }

    @Test func theSearchSetsSortIsOneTheAppReads() throws {
        let search = try #require(SeedSet.all.first { $0.name == "search" })
        let text = try #require(search.settings[.remindersSort])
        #expect(SeedSettingText.remindersSort(from: text) != nil)
    }

    @Test func theRecordSurvivesInTheDefaults() throws {
        let store = UserDefaultsSeedRecordStore(defaults: try #require(UserDefaults(suiteName: suiteName)))
        var record = SeedRecord()
        record.sets["search"] = SeedRecord.Loaded(
            reminderIDs: [UUID()], createdTagIDs: [UUID()], earlierSettings: ["remindersSort": "created.ascending"]
        )

        store.write(record)

        #expect(store.read() == record)
        store.write(SeedRecord())
        #expect(store.read() == SeedRecord())
    }
}
#endif
