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

    /// The Quiet Hours page's switch (#370): off keeps the schedule, in its place, and on again
    /// brings it back as it was, after a relaunch too.
    @Test func aScheduleSwitchedOffIsKeptAndSwitchingItOnBringsItBack() throws {
        let night = try schedule(22, 7, days: [.sunday, .monday])
        let weekend = try schedule(23, 8, days: [.friday, .saturday])
        let first = try model()
        first.quietHours = QuietHours(schedules: [night, weekend])

        first.switchQuietHoursSchedule(night.id, on: false)

        let relaunched = try model()
        #expect(relaunched.quietHours.schedules.map(\.isOn) == [false, true])
        #expect(relaunched.quietHours.schedules.map(\.id) == [night.id, weekend.id])

        relaunched.switchQuietHoursSchedule(night.id, on: true)

        #expect(try model().quietHours == QuietHours(schedules: [night, weekend]))
    }

    /// Add Schedule (#371): a new schedule goes at the end of the list, and is there after a relaunch.
    @Test func aSavedNewScheduleIsAddedAtTheEndAndKept() throws {
        let night = try schedule(22, 7, days: [.sunday, .monday])
        let weekend = try schedule(23, 8, days: [.friday, .saturday])
        let first = try model()
        first.quietHours = QuietHours(schedules: [night])

        first.saveQuietHoursSchedule(weekend)

        #expect(try model().quietHours == QuietHours(schedules: [night, weekend]))
    }

    /// A schedule's sheet (#371): an edit keeps the schedule's place and identity, after a relaunch too.
    @Test func aSavedEditReplacesTheScheduleInItsPlace() throws {
        let night = try schedule(22, 7, days: [.sunday, .monday])
        let weekend = try schedule(23, 8, days: [.friday, .saturday])
        let first = try model()
        first.quietHours = QuietHours(schedules: [night, weekend])
        let earlier = try QuietHoursSchedule(id: night.id, start: TimeOfDay(hour: 21, minute: 30), end: TimeOfDay(hour: 6), days: [.monday], isOn: false)

        first.saveQuietHoursSchedule(earlier)

        #expect(try model().quietHours == QuietHours(schedules: [earlier, weekend]))
    }

    /// Delete Schedule (#371): only that schedule goes, after a relaunch too.
    @Test func aDeletedScheduleIsGoneAndTheOthersAreKept() throws {
        let night = try schedule(22, 7, days: [.sunday, .monday])
        let weekend = try schedule(23, 8, days: [.friday, .saturday])
        let first = try model()
        first.quietHours = QuietHours(schedules: [night, weekend])

        first.deleteQuietHoursSchedule(night.id)

        #expect(try model().quietHours == QuietHours(schedules: [weekend]))
    }

    /// Saving and deleting go through the model's quiet hours, so the launched engine re-plans with
    /// them (#368) and keeps the schedules each replaced, for past Missed notes.
    @Test func savingAndDeletingReachTheEngineAndKeepWhatTheyReplaced() async throws {
        let night = try schedule(22, 7, days: [.sunday, .monday])
        let model = try model()
        await model.launch()

        // The clock reads Thursday 2026-10-15, 8:00 AM, so the night's next start is Sunday's.
        model.saveQuietHoursSchedule(night)
        #expect(model.quietHoursState(at: clock.now) == .startsAt(NewYork.local(2026, 10, 18, 22)))
        model.deleteQuietHoursSchedule(night.id)
        #expect(model.quietHoursState(at: clock.now) == .off)

        let replaced = QuietHoursRecord(defaults: try defaults()).replacedQuietHours.map(\.value)
        #expect(replaced == [QuietHours(), QuietHours(schedules: [night])])
    }

    @Test func aScheduleWithNoDaysIsKept() throws {
        let saved = QuietHours(schedules: [try schedule(22, 7, days: [])])
        let model = try model()
        model.quietHours = saved

        #expect(try self.model().quietHours == saved)
    }

    /// One entry in the record's own shape, for a test to spoil one field of.
    nonisolated static func entry(
        id: Any? = UUID().uuidString, start: Any = 9 * 60, end: Any = 10 * 60, days: Any = [1], isOn: Any? = true
    ) -> [String: Any] {
        var entry: [String: Any] = [
            QuietHoursRecord.Field.start: start, QuietHoursRecord.Field.end: end, QuietHoursRecord.Field.days: days,
        ]
        entry[QuietHoursRecord.Field.id] = id
        entry[QuietHoursRecord.Field.isOn] = isOn
        return entry
    }

    /// What an entry the record can't read looks like, one case each.
    enum Unreadable: String, CaseIterable, Sendable {
        case timeTheClockDoesntShow, negativeTime, startEqualToEnd, dayThatIsNotAWeekday
        case noOnOrOff, timeThatIsNotANumber, daysThatAreNotAList, notADictionary
        case noIdentity, identityThatIsNotAUUID

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
            case .noIdentity: QuietHoursRecordTests.entry(id: nil)
            case .identityThatIsNotAUUID: QuietHoursRecordTests.entry(id: "night")
            }
        }
    }

    @Test(arguments: Unreadable.allCases)
    func anEntryTheRecordCantReadIsLeftOutAndTheOthersAreKept(_ unreadable: Unreadable) throws {
        let firstID = UUID(), lastID = UUID()
        let first = Self.entry(id: firstID.uuidString, start: 22 * 60, end: 7 * 60, days: [1, 2])
        let last = Self.entry(id: lastID.uuidString, start: 13 * 60 + 15, end: 14 * 60, days: [6], isOn: false)
        // The unreadable entry sits between two readable ones, so order is kept around the gap.
        try defaults().set([first, unreadable.entry, last] as [Any], forKey: QuietHoursRecord.key)

        #expect(try model().quietHours == QuietHours(schedules: [
            try QuietHoursSchedule(id: firstID, start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 7), days: [.sunday, .monday]),
            try QuietHoursSchedule(id: lastID, start: TimeOfDay(hour: 13, minute: 15), end: TimeOfDay(hour: 14), days: [.friday], isOn: false),
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
