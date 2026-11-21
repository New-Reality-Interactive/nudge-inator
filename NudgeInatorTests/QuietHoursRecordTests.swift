import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The quiet hours schedules kept on the phone (#366): what the app model reads with nothing
/// saved, after a relaunch, with an entry it can't read, and after Delete All Data. A class so
/// `deinit` removes the defaults each test wrote, even when it fails.
@MainActor
final class QuietHoursRecordTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    let suiteName = "QuietHoursRecordTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suiteName))
    }

    /// A model over this test's defaults, as each launch makes one, not yet launched.
    func model() throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
        return AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            settingsRecords: .temporary(quietHours: QuietHoursRecord(defaults: try defaults())),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
    }

    func schedule(_ startHour: Int, _ endHour: Int, days: Set<RepeatRule.Weekday>, isOn: Bool = true) throws -> QuietHoursSchedule {
        try QuietHoursSchedule(start: TimeOfDay(hour: startHour), end: TimeOfDay(hour: endHour), days: days, isOn: isOn)
    }

    @Test func withNothingSavedQuietHoursIsNone() throws {
        let model = try model()

        #expect(model.quietHours == QuietHours())
        #expect(model.quietHours.schedules.isEmpty)
    }

    @Test func schedulesSavedThroughTheModelReadBackInOrderAfterARelaunch() throws {
        let saved = QuietHours(schedules: [
            try QuietHoursSchedule(start: TimeOfDay(hour: 22, minute: 30), end: TimeOfDay(hour: 7), days: [.sunday, .monday, .thursday]),
            try schedule(13, 14, days: Set(RepeatRule.Weekday.allCases), isOn: false),
            try schedule(6, 8, days: [.saturday]),
        ])
        let first = try model()
        first.quietHours = saved

        let relaunched = try model()

        #expect(relaunched.quietHours == saved)
    }

    @Test func aScheduleWithNoDaysIsKept() throws {
        let saved = QuietHours(schedules: [try schedule(22, 7, days: [])])
        let model = try model()
        model.quietHours = saved

        #expect(try self.model().quietHours == saved)
    }

    /// One entry in the record's own shape, for a test to spoil one field of.
    nonisolated static func entry(
        start: Any = 9 * 60, end: Any = 10 * 60, days: Any = [1], isOn: Any? = true
    ) -> [String: Any] {
        var entry: [String: Any] = [
            QuietHoursRecord.Field.start: start, QuietHoursRecord.Field.end: end, QuietHoursRecord.Field.days: days,
        ]
        entry[QuietHoursRecord.Field.isOn] = isOn
        return entry
    }

    /// What an entry the record can't read looks like, one case each.
    enum Unreadable: String, CaseIterable, Sendable {
        case timeTheClockDoesntShow, negativeTime, startEqualToEnd, dayThatIsNotAWeekday
        case noOnOrOff, timeThatIsNotANumber, daysThatAreNotAList, notADictionary

        var entry: Any {
            switch self {
            case .timeTheClockDoesntShow: QuietHoursRecordTests.entry(start: 25 * 60)
            case .negativeTime: QuietHoursRecordTests.entry(start: -1)
            case .startEqualToEnd: QuietHoursRecordTests.entry(start: 9 * 60, end: 9 * 60)
            case .dayThatIsNotAWeekday: QuietHoursRecordTests.entry(days: [1, 8])
            case .noOnOrOff: QuietHoursRecordTests.entry(isOn: nil)
            case .timeThatIsNotANumber: QuietHoursRecordTests.entry(start: "nine")
            case .daysThatAreNotAList: QuietHoursRecordTests.entry(days: "Sunday")
            case .notADictionary: "not an entry"
            }
        }
    }

    @Test(arguments: Unreadable.allCases)
    func anEntryTheRecordCantReadIsLeftOutAndTheOthersAreKept(_ unreadable: Unreadable) throws {
        let first = Self.entry(start: 22 * 60, end: 7 * 60, days: [1, 2])
        let last = Self.entry(start: 13 * 60 + 15, end: 14 * 60, days: [6], isOn: false)
        // The unreadable entry sits between two readable ones, so order is kept around the gap.
        try defaults().set([first, unreadable.entry, last] as [Any], forKey: QuietHoursRecord.key)

        #expect(try model().quietHours == QuietHours(schedules: [
            try schedule(22, 7, days: [.sunday, .monday]),
            try QuietHoursSchedule(start: TimeOfDay(hour: 13, minute: 15), end: TimeOfDay(hour: 14), days: [.friday], isOn: false),
        ]))
    }

    @Test func aRecordThatIsNotAListReadsAsNone() throws {
        try defaults().set("garbage", forKey: QuietHoursRecord.key)

        #expect(try model().quietHours == QuietHours())
    }

    @Test func deleteAllDataClearsTheSchedulesBackToNone() async throws {
        let model = try model()
        await model.launch()
        model.quietHours = QuietHours(schedules: [try schedule(22, 7, days: [.friday])])

        try await model.deleteAllData()

        #expect(model.quietHours == QuietHours())
        #expect(try self.model().quietHours == QuietHours())
        #expect(try defaults().object(forKey: QuietHoursRecord.key) == nil)
    }
}
