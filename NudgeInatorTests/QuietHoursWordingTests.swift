import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The words Settings' Quiet Hours row and page show (#370), each resource resolved in US English,
/// on a Gregorian calendar whose week starts on Sunday, in New York. iOS puts a narrow no-break
/// space before AM and PM.
struct QuietHoursWordingTests {
    let wording: QuietHoursWording = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US")
        return QuietHoursWording(calendar: calendar)
    }()

    /// The resource in US English, as SwiftUI would draw it on an English iPhone.
    func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en_US")
        return String(localized: resource)
    }

    /// 2026-11-16, a Monday, at `hour`:`minute` in New York.
    func monday(_ hour: Int, _ minute: Int = 0, plusDays days: Int = 0) -> Date {
        wording.calendar.date(from: DateComponents(year: 2026, month: 11, day: 16 + days, hour: hour, minute: minute))!
    }

    func schedule(_ start: Int, _ end: Int, on days: Set<RepeatRule.Weekday>, startMinute: Int = 0) throws -> QuietHoursSchedule {
        try QuietHoursSchedule(start: TimeOfDay(hour: start, minute: startMinute), end: TimeOfDay(hour: end), days: days)
    }

    @Test func whileQuietTheRowSaysUntilWhen() {
        let row = wording.row(.quietUntil(monday(7)), quietNowSince: nil, now: monday(6))
        #expect(english(row.text) == "Until 7:00\u{202F}AM")
        #expect(english(row.spoken) == "On until 7:00\u{202F}AM")
    }

    @Test func theNextStartTodayIsJustItsTime() {
        let row = wording.row(.startsAt(monday(22)), quietNowSince: nil, now: monday(8))
        #expect(english(row.text) == "Starts 10:00\u{202F}PM")
        #expect(english(row.spoken) == "Starts at 10:00\u{202F}PM")
    }

    @Test func theNextStartOnAnotherDayNamesTheDay() {
        let row = wording.row(.startsAt(monday(23, plusDays: 4)), quietNowSince: nil, now: monday(8))
        #expect(english(row.text) == "Starts Fri 11:00\u{202F}PM")
        #expect(english(row.spoken) == "Starts Friday at 11:00\u{202F}PM")
    }

    @Test func withNoScheduleOnTheRowSaysOff() {
        let row = wording.row(.off, quietNowSince: nil, now: monday(8))
        #expect(english(row.text) == "Off")
        #expect(english(row.spoken) == "Off")
    }

    @Test(arguments: [QuietHoursState.off, .startsAt(Date(timeIntervalSince1970: 1_700_000_000)), .quietUntil(Date(timeIntervalSince1970: 1_700_030_000))])
    func whileQuietNowIsOnTheRowSaysOnWhateverTheSchedulesSay(state: QuietHoursState) {
        let row = wording.row(state, quietNowSince: monday(8), now: monday(9))
        #expect(english(row.text) == "On")
        #expect(english(row.spoken) == "On")
    }

    @Test func onceQuietNowIsOffTheRowGoesBackToTheSchedules() {
        let row = wording.row(.quietUntil(monday(7)), quietNowSince: nil, now: monday(6))
        #expect(english(row.text) == "Until 7:00\u{202F}AM")
    }

    @Test func quietNowsFooterSaysWhatItDoesThenSinceWhen() {
        #expect(english(wording.quietNowFooter(since: nil))
                == "Holds every nudge from now until you turn it off, whatever your schedules say.")
        #expect(english(wording.quietNowFooter(since: monday(8, 20)))
                == "On since 8:20\u{202F}AM. No nudge arrives until you turn it off.")
    }

    @Test func aScheduleReadsAsItsRangeAndItsDays() throws {
        let night = try schedule(22, 7, on: [.sunday, .monday, .tuesday, .wednesday, .thursday])
        #expect(english(wording.range(night)) == "10:00\u{202F}PM–7:00\u{202F}AM")
        #expect(english(wording.days(night)) == "Every Sun, Mon, Tue, Wed, and Thu")
        #expect(english(wording.spoken(night)) == "10:00\u{202F}PM to 7:00\u{202F}AM, Every Sun, Mon, Tue, Wed, and Thu")
    }

    @Test func daysAreListedInTheCalendarsWeekOrder() throws {
        #expect(english(wording.days(try schedule(23, 8, on: [.saturday, .friday]))) == "Every Fri and Sat")
        #expect(english(wording.days(try schedule(23, 8, on: [.saturday, .sunday]))) == "Every Sun and Sat")
        #expect(english(wording.days(try schedule(23, 8, on: [.wednesday]))) == "Every Wed")
    }

    @Test func everyDayOfTheWeekIsEveryDay() throws {
        #expect(english(wording.days(try schedule(22, 7, on: Set(RepeatRule.Weekday.allCases)))) == "Every day")
    }

    /// 2:30 AM doesn't exist on the day the clocks go forward; the schedule still reads 2:30.
    @Test func aTimeTheClocksSkipOnSomeDayStillReadsAsSet() throws {
        let early = try QuietHoursSchedule(start: TimeOfDay(hour: 1), end: TimeOfDay(hour: 2, minute: 30), days: [.sunday])
        #expect(english(wording.range(early)) == "1:00\u{202F}AM–2:30\u{202F}AM")
    }

    @Test func everyDayIsSpokenWithItsTimes() throws {
        let night = try schedule(22, 7, on: Set(RepeatRule.Weekday.allCases))
        #expect(english(wording.spoken(night)) == "10:00\u{202F}PM to 7:00\u{202F}AM, Every day")
    }

    @Test func aStartPastTheHourKeepsItsMinutes() throws {
        #expect(english(wording.range(try schedule(18, 21, on: [.tuesday], startMinute: 30))) == "6:30\u{202F}PM–9:00\u{202F}PM")
    }

    // The holding banner on Now, My Day and Reminders (#499).

    @Test func whileAScheduleRunsTheBannerSaysUntilWhenAndWhereToChangeIt() throws {
        let detail = try #require(wording.holdingBannerDetail(.quietUntil(monday(7)), quietNowSince: nil))
        #expect(english(detail) == "Until 7:00\u{202F}AM. Change this in Settings, under Quiet Hours.")
    }

    @Test func whileQuietNowIsOnTheBannerSaysUntilYouTurnItOff() throws {
        let detail = try #require(wording.holdingBannerDetail(.off, quietNowSince: monday(8)))
        #expect(english(detail) == "Until you turn it off. Change this in Settings, under Quiet Hours.")
    }

    /// Settings' row reads On, whatever the schedules say, while Quiet Now is on; so does the banner.
    @Test func quietNowWinsOverARunningSchedule() throws {
        let detail = try #require(wording.holdingBannerDetail(.quietUntil(monday(7)), quietNowSince: monday(6)))
        #expect(english(detail) == "Until you turn it off. Change this in Settings, under Quiet Hours.")
    }

    @Test func theBannerAgreesWithTheRowsUntil() throws {
        let state = QuietHoursState.quietUntil(monday(9, 30))
        let detail = try #require(wording.holdingBannerDetail(state, quietNowSince: nil))
        #expect(english(detail).hasPrefix(english(wording.row(state, quietNowSince: nil, now: monday(8)).text)))
    }

    @Test(arguments: [QuietHoursState.off, .startsAt(Date(timeIntervalSince1970: 1_700_000_000))])
    func withNothingHeldThereIsNoBanner(state: QuietHoursState) {
        #expect(wording.holdingBannerDetail(state, quietNowSince: nil) == nil)
    }
}
