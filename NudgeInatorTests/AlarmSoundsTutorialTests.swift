import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The How Alarm Sounds Work sheet's content and paging (#467), against the approved tutorial sheets
/// mockup's wording, `docs/mockups/2026-11-20-tutorial-sheets/`, with the leads and picture of
/// `docs/mockups/2026-11-20-alarm-sounds-tutorial-leads/` (#467's phone check).
struct AlarmSoundsTutorialTests {
    @Test func theThreePagesShowInOrder() {
        #expect(AlarmSoundsTutorialPage.allCases.map { String(localized: $0.heading) } == [
            "Pick Your Default Sound",
            "Change Your Reminders",
            "When It Plays",
        ])
        #expect(String(localized: AlarmSoundsTutorialPage.title) == "How Alarm Sounds Work")
    }

    /// The mockup's rows: the SF Symbol each names, its title and the line under it.
    @Test(arguments: [
        (AlarmSoundsTutorialPage.pickYourDefaultSound,
         "In Settings, under Default Alarm Sound, choose the sound your alarms ring with.",
         [["play", "Tap a tone to hear it", "Choose from six tones, from the gentle Chime to the insistent Siren. Default Alarm is iOS's own sound, which apps can't play, so you'll hear it when an alarm rings."],
          ["plus", "New reminders start with it", "So do reminders someone sends you. The reminders you already have keep their sounds."]],
         nil),
        (.changeYourReminders,
         "Change the sound of reminders you already have, all at once or one at a time.",
         [["square.stack", "Use for All Reminders", "Settings › Default Alarm Sound. Gives every reminder you have the default, including ones people sent you."],
          ["pencil", "Sound on the form", "Edit a reminder and change its Sound, under Break Through Focus, even while it's nudging."],
          ["list.bullet.rectangle", "Named on its details", "A reminder's details name its sound, under Break Through Focus."]],
         "A reminder someone sends you rings with the sound chosen on your iPhone."),
        (.whenItPlays,
         "Your sound plays only when a nudge rings as an alarm.",
         [["alarm", "Only alarms play it", "A Firm reminder's Urgent nudges with Break Through Focus on, and every Relentless nudge, ring as alarms."],
          ["bell.slash", "Some reminders never ring", "A Gentle reminder, or a Firm one with Break Through Focus off, never rings, so it has no Sound row."],
          ["bell", "Other nudges sound standard", "Notifications use the standard sound, and so does every nudge while Alarms are off in iOS Settings."]],
         nil),
    ] as [(AlarmSoundsTutorialPage, String?, [[String]], String?)])
    func eachPageHasTheMockupsLeadRowsAndFooter(page: AlarmSoundsTutorialPage, lead: String?, rows: [[String]], footnote: String?) {
        guard case .points(let actualLead, let points, let actualFootnote) = page.content else {
            Issue.record("\(page) isn't a page of points")
            return
        }
        #expect(actualLead.map { String(localized: $0) } == lead)
        #expect(points.map { [$0.symbol, String(localized: $0.title), String(localized: $0.text)] } == rows)
        #expect(actualFootnote.map { String(localized: $0) } == footnote)
    }

    /// The pictures' pills, decoration only: their symbol and word, an arrow as "→". Only the second
    /// page's, a reminder and its sound, stops growing at the largest standard size.
    @Test(arguments: [
        (AlarmSoundsTutorialPage.pickYourDefaultSound, ["speaker.wave.2 Default Alarm Sound"], false),
        (.changeYourReminders, ["bell Wake Up", "→", "speaker.wave.2 Chime"], true),
        (.whenItPlays, ["alarm Alarm"], false),
    ])
    func eachPageHasTheMockupsPicture(page: AlarmSoundsTutorialPage, pieces: [String], stopsGrowing: Bool) {
        #expect(page.art.map { piece in
            switch piece {
            case .pill(let symbol, let text): "\(symbol) \(String(localized: text))"
            case .arrow: "→"
            }
        } == pieces)
        #expect(page.artStopsGrowingAtLargestStandardSize == stopsGrowing)
    }

    /// The sheet names the rows as the screens do: Settings' Default Alarm Sound, its Use for All
    /// Reminders, the form's Sound, and the sounds Default Alarm and Chime.
    @Test func theSheetNamesTheRowsAsTheScreensDo() throws {
        let defaultAlarmSound = String(localized: DefaultAlarmSoundPage.title)
        let useForAll = String(localized: DefaultAlarmSoundPage.useForAllTitle)
        let formSound = String(localized: SoundRow.title)

        guard case .points(let lead?, let firstRows, _) = AlarmSoundsTutorialPage.pickYourDefaultSound.content,
              case .points(_, let secondRows, _) = AlarmSoundsTutorialPage.changeYourReminders.content
        else {
            Issue.record("A page isn't a page of points with the rows it names")
            return
        }
        #expect(String(localized: lead).contains(defaultAlarmSound))
        #expect(String(localized: firstRows[0].text).contains(String(localized: AlarmSound.default.title)))
        #expect(String(localized: firstRows[0].text).contains(String(localized: AlarmSound.chime.title)))
        #expect(String(localized: firstRows[0].text).contains(String(localized: AlarmSound.siren.title)))
        #expect(String(localized: secondRows[0].title) == useForAll)
        #expect(String(localized: secondRows[0].text).contains(defaultAlarmSound))
        #expect(String(localized: secondRows[1].text).contains("its \(formSound),"))

        guard case .pill(_, let pill) = try #require(AlarmSoundsTutorialPage.pickYourDefaultSound.art.first),
              case .pill(_, let tone) = try #require(AlarmSoundsTutorialPage.changeYourReminders.art.last)
        else {
            Issue.record("A picture lost its pill")
            return
        }
        #expect(String(localized: pill) == defaultAlarmSound)
        #expect(String(localized: tone) == String(localized: AlarmSound.chime.title))
    }

    /// The shared paging over three pages: the dots count three, and the third is the last.
    @Test func nextAndBackMoveOverTheThreePages() {
        var paging = TutorialPaging<AlarmSoundsTutorialPage>()
        #expect(paging.page == .pickYourDefaultSound)
        #expect(!paging.canGoBack)
        #expect(String(localized: paging.position) == "Page 1 of 3")

        paging.goForward()
        #expect(paging.page == .changeYourReminders)
        #expect(!paging.isLastPage)
        #expect(String(localized: paging.position) == "Page 2 of 3")

        paging.goForward()
        #expect(paging.page == .whenItPlays)
        #expect(paging.isLastPage)
        #expect(String(localized: paging.position) == "Page 3 of 3")
        paging.goForward()
        #expect(paging.page == .whenItPlays)

        paging.page = .pickYourDefaultSound
        paging.goBack()
        #expect(paging.page == .pickYourDefaultSound)
    }
}
