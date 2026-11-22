import Foundation
import NudgeEngine

/// A page of the How Quiet Hours Work sheet (#468, the mockup `2026-11-22-quiet-hours-tutorial`), in
/// the order the sheet shows them. It opens by itself the first time the Quiet Hours page opens
/// (`quietHoursTutorialFirstTime`), and any time from Settings' row. What it says about held nudges
/// is the engine's rule (spec #338): a held nudge counts as dismissed, none is sent late, and the
/// give-up limit can close a reminder as Missed, which the Missed note then says.
enum QuietHoursTutorialPage: TutorialPage, CaseIterable {
    case restWithoutNudges
    case quietNow
    case yourSchedules
    case heldNudges

    static let title = LocalizedStringResource("How Quiet Hours Work", comment: "How Quiet Hours Work: the sheet's title, and the Settings row under Tutorials that opens it.")

    var heading: LocalizedStringResource {
        switch self {
        case .restWithoutNudges:
            LocalizedStringResource("Rest Without Nudges", comment: "How Quiet Hours Work: the first page's heading, about what a quiet hours schedule is.")
        case .quietNow:
            QuietHoursPage.quietNowTitle
        case .yourSchedules:
            LocalizedStringResource("Your Schedules", comment: "How Quiet Hours Work: the third page's heading, about adding, changing and switching off quiet hours schedules.")
        case .heldNudges:
            LocalizedStringResource("Held Nudges", comment: "How Quiet Hours Work: the last page's heading, about what happens to nudges quiet hours hold.")
        }
    }

    /// A new schedule's times, 10:00 PM to 7:00 AM, as Add Schedule starts them and the schedules
    /// write them.
    private static let example = QuietHoursScheduleDraft()
    private static let wording = QuietHoursWording(calendar: .autoupdatingCurrent)
    private static var exampleStart: Date { wording.onReferenceDay(example.start) }
    private static var exampleEnd: Date { wording.onReferenceDay(example.end) }

    /// The mockup's art, with the real SF Symbols. The Quiet Hours page's Quiet Now and Add Schedule
    /// and the Missed status are named with the screens' own strings, so the two can't be worded
    /// apart. The first step's title, "Add a Schedule", is the tutorial's own.
    var art: [TutorialArtPiece] {
        switch self {
        case .restWithoutNudges:
            [.pill(symbol: "moon.fill", text: LocalizedStringResource("quietHoursTutorial.exampleStart", defaultValue: "\(Self.exampleStart, format: Self.wording.timeStyle)", comment: "How Quiet Hours Work, Rest Without Nudges: the picture's first pill, beside a moon: an example schedule's start time, such as \"10:00 PM\". The placeholder is the time.")),
             .arrow,
             .pill(symbol: "bell", text: LocalizedStringResource("quietHoursTutorial.exampleEnd", defaultValue: "\(Self.exampleEnd, format: Self.wording.timeStyle)", comment: "How Quiet Hours Work, Rest Without Nudges: the picture's second pill, beside a bell: the example schedule's end time, such as \"7:00 AM\". The placeholder is the time."))]
        case .quietNow:
            [.pill(symbol: "bell.slash", text: QuietHoursPage.quietNowTitle)]
        case .yourSchedules:
            [.pill(symbol: "plus", text: QuietHoursScheduleSheet.addTitle)]
        case .heldNudges:
            [.pill(symbol: "bell.slash", text: LocalizedStringResource("Held", comment: "How Quiet Hours Work, Held Nudges: the picture's first pill, a nudge quiet hours held, before the Missed it can end as.")),
             .arrow,
             .pill(symbol: "xmark.circle.fill", text: OccurrenceState.missed(reason: .giveUpLimit).statusName)]
        }
    }

    var content: TutorialContent {
        switch self {
        case .restWithoutNudges:
            .points(lead: LocalizedStringResource("A quiet hours schedule is a time, on the days you choose, when no nudge arrives.", comment: "How Quiet Hours Work, Rest Without Nudges: the line under the heading."), [
                TutorialPoint(symbol: "clock",
                              title: LocalizedStringResource("A start, an end and days", comment: "How Quiet Hours Work, Rest Without Nudges: the row about what a schedule is made of."),
                              text: LocalizedStringResource("Such as \(Self.exampleStart, format: Self.wording.timeStyle) to \(Self.exampleEnd, format: Self.wording.timeStyle), every day. A schedule that ends before it starts runs past midnight.", comment: "How Quiet Hours Work, Rest Without Nudges: under \"A start, an end and days\". 1: an example schedule's start time, such as \"10:00 PM\". 2: its end time, such as \"7:00 AM\".")),
                TutorialPoint(symbol: "bell.slash",
                              title: LocalizedStringResource("Every nudge is held", comment: "How Quiet Hours Work, Rest Without Nudges: the row about which nudges quiet hours hold."),
                              text: LocalizedStringResource("Notifications and alarms alike, even a Relentless reminder's. Quiet hours hold them all.", comment: "How Quiet Hours Work, Rest Without Nudges: under \"Every nudge is held\". Relentless is a strength.")),
            ])
        case .quietNow:
            .points(lead: LocalizedStringResource("The switch above your schedules, for quiet hours no schedule covers.", comment: "How Quiet Hours Work, Quiet Now: the line under the heading. Quiet Now is the switch above the schedules on the Quiet Hours page."), [
                TutorialPoint(symbol: "bell.slash",
                              title: LocalizedStringResource("Holds every nudge", comment: "How Quiet Hours Work, Quiet Now: the row about what Quiet Now does."),
                              text: LocalizedStringResource("From the moment you turn it on until you turn it off, whatever your schedules say. It never ends by itself.", comment: "How Quiet Hours Work, Quiet Now: under \"Holds every nudge\".")),
                TutorialPoint(symbol: "calendar",
                              title: LocalizedStringResource("Then your schedules apply", comment: "How Quiet Hours Work, Quiet Now: the row about what happens once Quiet Now is off."),
                              text: LocalizedStringResource("Turn it off, and your schedules hold nudges again as before.", comment: "How Quiet Hours Work, Quiet Now: under \"Then your schedules apply\".")),
            ])
        case .yourSchedules:
            .steps(lead: LocalizedStringResource("Add as many as you need, such as one for weeknights and one for weekends.", comment: "How Quiet Hours Work, Your Schedules: the line under the heading, above the numbered steps."), [
                TutorialStep(title: LocalizedStringResource("Add a Schedule", comment: "How Quiet Hours Work, Your Schedules: the first numbered step, about the Quiet Hours page's Add Schedule (+)."),
                             text: LocalizedStringResource("Settings › Quiet Hours. Tap +, choose the times and days, and tap Save.", comment: "How Quiet Hours Work, Your Schedules: under the first numbered step, Add Schedule. Settings › Quiet Hours is the page; + is its navigation bar's Add Schedule button; Save is the sheet's.")),
                TutorialStep(title: LocalizedStringResource("Change One", comment: "How Quiet Hours Work, Your Schedules: the second numbered step, about editing a schedule."),
                             text: LocalizedStringResource("Tap a schedule to change its times and days, or to delete it.", comment: "How Quiet Hours Work, Your Schedules: under \"Change One\".")),
                TutorialStep(title: LocalizedStringResource("Switch One Off", comment: "How Quiet Hours Work, Your Schedules: the third numbered step, about a schedule's switch."),
                             text: LocalizedStringResource("Its switch turns it off and keeps it for later.", comment: "How Quiet Hours Work, Your Schedules: under \"Switch One Off\".")),
            ], footnote: LocalizedStringResource("A change applies from now on. What was already sent or held stays as it was.", comment: "How Quiet Hours Work, Your Schedules: the note under the steps."))
        case .heldNudges:
            .points(lead: LocalizedStringResource("A nudge that falls in quiet hours is held, and counts as one you didn't answer.", comment: "How Quiet Hours Work, Held Nudges: the line under the heading."), [
                TutorialPoint(symbol: "arrow.right",
                              title: LocalizedStringResource("Its reminder moves on", comment: "How Quiet Hours Work, Held Nudges: the row about a held nudge counting as dismissed."),
                              text: LocalizedStringResource("As if you'd swiped the nudge away, the next nudges come as planned, and the held ones count toward its limit.", comment: "How Quiet Hours Work, Held Nudges: under \"Its reminder moves on\". Its limit is the reminder's give-up limit.")),
                TutorialPoint(symbol: "clock",
                              title: LocalizedStringResource("Nothing arrives late", comment: "How Quiet Hours Work, Held Nudges: the row about held nudges never being sent afterward."),
                              text: LocalizedStringResource("When quiet hours end, the next nudge arrives on time. Held nudges aren't sent afterward.", comment: "How Quiet Hours Work, Held Nudges: under \"Nothing arrives late\".")),
                TutorialPoint(symbol: "xmark.circle.fill",
                              title: LocalizedStringResource("It can end as Missed", comment: "How Quiet Hours Work, Held Nudges: the row about a reminder closing as Missed while its nudges are held. Missed is a status."),
                              text: LocalizedStringResource("A reminder that reaches its limit while held ends as Missed, with a note such as \u{201C}\(MissedNote(held: 10, total: 20).text)\u{201D}", comment: "How Quiet Hours Work, Held Nudges: under \"It can end as Missed\". Missed is a status. The placeholder is the Missed note, \"Quiet hours held 10 of its 20 nudges.\", in the language's quotation marks.")),
            ])
        }
    }
}
