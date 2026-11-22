import Foundation
import Testing
import NudgeEngine

/// The Quiet Hours page's add, edit, delete and switch (#370, #371): each schedule is known by its
/// own identity, which an edit keeps, so a change never lands on another schedule.
struct QuietHoursEditingTests {
    let night = try! QuietHoursSchedule(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 7), days: [.sunday, .monday])
    let weekend = try! QuietHoursSchedule(start: TimeOfDay(hour: 23), end: TimeOfDay(hour: 8), days: [.friday, .saturday])
    let lunch = try! QuietHoursSchedule(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13), days: [.wednesday])

    @Test func everyScheduleHasItsOwnIdentity() throws {
        let same = try QuietHoursSchedule(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 7), days: [.sunday, .monday])
        #expect(same.id != night.id)
        #expect(same != night)
    }

    @Test func savingANewScheduleAddsItAtTheEnd() {
        var quietHours = QuietHours(schedules: [night, weekend])
        quietHours.save(lunch)
        #expect(quietHours.schedules == [night, weekend, lunch])
    }

    @Test func savingAnEditedScheduleReplacesItInItsPlace() throws {
        var quietHours = QuietHours(schedules: [night, weekend, lunch])
        let later = try QuietHoursSchedule(id: weekend.id, start: TimeOfDay(hour: 23, minute: 30), end: TimeOfDay(hour: 9), days: [.saturday], isOn: false)
        quietHours.save(later)
        #expect(quietHours.schedules == [night, later, lunch])
    }

    @Test func deletingAScheduleRemovesOnlyThatOne() {
        var quietHours = QuietHours(schedules: [night, weekend, lunch])
        quietHours.deleteSchedule(weekend.id)
        #expect(quietHours.schedules == [night, lunch])
        quietHours.deleteSchedule(UUID())
        #expect(quietHours.schedules == [night, lunch])
    }

    @Test func switchingAScheduleKeepsItInItsPlace() {
        var quietHours = QuietHours(schedules: [night, weekend])
        quietHours.switchSchedule(night.id, on: false)
        quietHours.switchSchedule(UUID(), on: false)
        #expect(quietHours.schedules.map(\.isOn) == [false, true])
        #expect(quietHours.schedules.map(\.id) == [night.id, weekend.id])
    }
}
