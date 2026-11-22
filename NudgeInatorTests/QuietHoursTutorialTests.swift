import Foundation
import Testing
@testable import NudgeInator

/// The How Quiet Hours Work sheet's content (#468), against the approved mockup's wording,
/// `docs/mockups/2026-11-22-quiet-hours-tutorial/`.
/// Times are in the phone's own format; the test host runs in US English, which puts a narrow
/// no-break space before AM and PM.
struct QuietHoursTutorialTests {
    @Test func theFourPagesShowInOrder() {
        #expect(QuietHoursTutorialPage.allCases.map { String(localized: $0.heading) } == [
            "Rest Without Nudges",
            "Quiet Now",
            "Your Schedules",
            "Held Nudges",
        ])
        #expect(String(localized: QuietHoursTutorialPage.title) == "How Quiet Hours Work")
    }

    /// The mockup's rows: the SF Symbol each names, its title and the line under it. The last page's
    /// held-nudge rows say what the engine does (spec #338: a held nudge counts as dismissed, none
    /// is sent late, and the give-up limit closes it as Missed), and quote the Missed note as built.
    @Test(arguments: [
        (QuietHoursTutorialPage.restWithoutNudges,
         "A quiet hours schedule is a time, on the days you choose, when no nudge arrives.",
         [["clock", "A start, an end and days", "Such as 10:00\u{202F}PM to 7:00\u{202F}AM, every day. A schedule that ends before it starts runs past midnight."],
          ["bell.slash", "Every nudge is held", "Notifications and alarms alike, even a Relentless reminder's. Quiet hours hold them all."]]),
        (.quietNow,
         "The switch above your schedules, for quiet hours no schedule covers.",
         [["bell.slash", "Holds every nudge", "From the moment you turn it on until you turn it off, whatever your schedules say. It never ends by itself."],
          ["calendar", "Then your schedules apply", "Turn it off, and your schedules hold nudges again as before."]]),
        (.heldNudges,
         "A nudge that falls in quiet hours is held, and counts as one you didn't answer.",
         [["arrow.right", "Its reminder moves on", "As if you'd swiped the nudge away, the next nudges come as planned, and the held ones count toward its limit."],
          ["clock", "Nothing arrives late", "When quiet hours end, the next nudge arrives on time. Held nudges aren't sent afterward."],
          ["xmark.circle.fill", "It can end as Missed", "A reminder that reaches its limit while held ends as Missed, with a note such as \u{201C}Quiet hours held 10 of its 20 nudges.\u{201D}"]]),
    ] as [(QuietHoursTutorialPage, String, [[String]])])
    func eachPageOfPointsHasTheMockupsLeadAndRows(page: QuietHoursTutorialPage, lead: String, rows: [[String]]) {
        guard case .points(let actualLead, let points, let footnote) = page.content else {
            Issue.record("\(page) isn't a page of points")
            return
        }
        #expect(actualLead.map { String(localized: $0) } == lead)
        #expect(points.map { [$0.symbol, String(localized: $0.title), String(localized: $0.text)] } == rows)
        #expect(footnote == nil)
    }

    /// Your Schedules numbers its three steps under a lead, the developer's addition to the mockup
    /// (#468), and ends with a note.
    @Test func yourSchedulesNumbersItsStepsUnderALeadAndEndsWithANote() {
        guard case .steps(let lead, let steps, let footnote) = QuietHoursTutorialPage.yourSchedules.content else {
            Issue.record("Your Schedules isn't a page of steps")
            return
        }
        #expect(lead.map { String(localized: $0) } == "Add as many as you need, such as one for weeknights and one for weekends.")
        #expect(steps.map { [String(localized: $0.title), String(localized: $0.text)] } == [
            ["Add a Schedule", "Settings › Quiet Hours. Tap +, choose the times and days, and tap Save."],
            ["Change One", "Tap a schedule to change its times and days, or to delete it."],
            ["Switch One Off", "Its switch turns it off and keeps it for later."],
        ])
        #expect(String(localized: footnote) == "A change applies from now on. What was already sent or held stays as it was.")
    }

    /// The pictures' pills, decoration only: their symbol and word, an arrow as "→".
    @Test(arguments: [
        (QuietHoursTutorialPage.restWithoutNudges, ["moon.fill 10:00\u{202F}PM", "→", "bell 7:00\u{202F}AM"]),
        (.quietNow, ["bell.slash Quiet Now"]),
        (.yourSchedules, ["plus Add Schedule"]),
        (.heldNudges, ["bell.slash Held", "→", "xmark.circle.fill Missed"]),
    ])
    func eachPageHasTheMockupsPicture(page: QuietHoursTutorialPage, pieces: [String]) {
        #expect(page.art.map(\.described) == pieces)
    }

    /// The sheet names what the screens show with their own strings, so the two can't be worded
    /// apart: the Quiet Hours page's Quiet Now and Add Schedule, the Missed status, and the Missed
    /// note.
    @Test func itNamesTheScreensWithTheirOwnStrings() {
        #expect(QuietHoursTutorialPage.quietNow.heading.key == QuietHoursPage.quietNowTitle.key)
        #expect(QuietHoursTutorialPage.quietNow.art.map(\.described) == ["bell.slash \(String(localized: QuietHoursPage.quietNowTitle))"])
        #expect(QuietHoursTutorialPage.yourSchedules.art.map(\.described) == ["plus \(String(localized: QuietHoursScheduleSheet.addTitle))"])
        guard case .points(_, let points, _) = QuietHoursTutorialPage.heldNudges.content, let missed = points.last else {
            Issue.record("Held Nudges has no rows")
            return
        }
        #expect(String(localized: missed.text).contains(String(localized: MissedNote(held: 10, total: 20).text)))
    }
}
