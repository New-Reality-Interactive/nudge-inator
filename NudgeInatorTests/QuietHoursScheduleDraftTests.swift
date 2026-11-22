import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Add Schedule's and a schedule's sheet (#371, the approved Quiet Hours page mockup): what it
/// starts with, what stops Save and why, and the words under the times, resolved in US English on
/// a Gregorian calendar in New York. iOS puts a narrow no-break space before AM and PM.
struct QuietHoursScheduleDraftTests {
    func calendar(firstWeekday: Int = 1) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    var wording: QuietHoursWording { QuietHoursWording(calendar: calendar()) }

    func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en_US")
        return String(localized: resource)
    }

    let saved = try! QuietHoursSchedule(start: TimeOfDay(hour: 23), end: TimeOfDay(hour: 8), days: [.friday, .saturday], isOn: false)

    @Test func aNewScheduleStartsAtTenAtNightToSevenEveryDayAndOn() throws {
        let draft = QuietHoursScheduleDraft()
        let schedule = try #require(draft.schedule)
        #expect(schedule.start == (try TimeOfDay(hour: 22)))
        #expect(schedule.end == (try TimeOfDay(hour: 7)))
        #expect(schedule.days == Set(RepeatRule.Weekday.allCases))
        #expect(schedule.isOn)
        #expect(!draft.hasChanges)
        #expect(draft.isNew)
    }

    @Test func twoNewSchedulesAreTwo() throws {
        #expect(try #require(QuietHoursScheduleDraft().schedule).id != (try #require(QuietHoursScheduleDraft().schedule).id))
    }

    @Test func anEditStartsAsSavedAndKeepsItsIdentityAndSwitch() throws {
        var draft = QuietHoursScheduleDraft(editing: saved)
        #expect(!draft.isNew)
        #expect(!draft.hasChanges)
        draft.start = try TimeOfDay(hour: 21, minute: 30)
        draft.toggle(.sunday)
        let schedule = try #require(draft.schedule)
        #expect(schedule.id == saved.id)
        #expect(!schedule.isOn)
        #expect(schedule.start == (try TimeOfDay(hour: 21, minute: 30)))
        #expect(schedule.days == [.sunday, .friday, .saturday])
        #expect(draft.hasChanges)
    }

    /// Edit Schedule's Schedule switch (the approved schedule switch mockup): an edit like the rest,
    /// kept on Save, and a change Cancel asks about.
    @Test func theScheduleSwitchIsKeptOnSave() throws {
        var draft = QuietHoursScheduleDraft(editing: saved)
        #expect(!draft.isOn)
        draft.isOn = true
        #expect(draft.hasChanges)
        #expect(try #require(draft.schedule).isOn)
        draft.isOn = false
        #expect(!draft.hasChanges)
        #expect(try !#require(draft.schedule).isOn)
    }

    @Test func changingAndChangingBackIsNoChange() {
        var draft = QuietHoursScheduleDraft(editing: saved)
        draft.toggle(.monday)
        draft.toggle(.monday)
        #expect(!draft.hasChanges)
    }

    @Test func aStartEqualToTheEndCantBeSavedAndSaysWhy() throws {
        var draft = QuietHoursScheduleDraft()
        draft.end = try TimeOfDay(hour: 22)
        #expect(draft.schedule == nil)
        #expect(draft.problems == [.startEqualsEnd])
        #expect(english(QuietHoursScheduleDraft.Problem.startEqualsEnd.message) == "The start and end are the same. Change one to save.")
    }

    @Test func noDayCantBeSavedAndSaysWhy() {
        var draft = QuietHoursScheduleDraft(editing: saved)
        draft.toggle(.friday)
        draft.toggle(.saturday)
        #expect(draft.schedule == nil)
        #expect(draft.problems == [.noDays])
        #expect(english(QuietHoursScheduleDraft.Problem.noDays.message) == "Choose at least one day to save.")
    }

    @Test func bothProblemsAreSaidStartFirst() throws {
        var draft = QuietHoursScheduleDraft(editing: saved)
        draft.end = draft.start
        draft.toggle(.friday)
        draft.toggle(.saturday)
        #expect(draft.problems == [.startEqualsEnd, .noDays])
    }

    @Test func anEndBeforeTheStartEndsTheNextDay() throws {
        let line = try #require(wording.ends(QuietHoursScheduleDraft()))
        #expect(english(line) == "Ends at 7:00\u{202F}AM the next day.")
    }

    @Test func anEndAfterTheStartEndsTheSameDay() throws {
        var draft = QuietHoursScheduleDraft()
        draft.start = try TimeOfDay(hour: 12)
        draft.end = try TimeOfDay(hour: 13, minute: 30)
        let line = try #require(wording.ends(draft))
        #expect(english(line) == "Ends at 1:30\u{202F}PM the same day.")
    }

    @Test func aStartEqualToTheEndHasNoEndsLine() throws {
        var draft = QuietHoursScheduleDraft()
        draft.end = draft.start
        #expect(wording.ends(draft) == nil)
    }

    @Test func theDaysAreInTheCalendarsWeekOrder() {
        #expect(wording.weekOrder == [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
        #expect(QuietHoursWording(calendar: calendar(firstWeekday: 2)).weekOrder == [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
    }

    /// The time pills show a `Date`; the schedule keeps its hour and minute, on a day with no clock change.
    @Test func aTimeReadsBackFromThePillsDate() throws {
        let time = try TimeOfDay(hour: 2, minute: 30)
        #expect(wording.time(of: wording.date(of: time)) == time)
    }
}
