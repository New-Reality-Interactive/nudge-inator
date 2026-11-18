import Foundation
import Testing
@testable import NudgeInator

/// The How Sharing Works sheet's content and paging (#423), against the approved mockup's
/// (version 5) wording, `docs/mockups/1.4.0/`.
struct SharingTutorialTests {
    @Test func theFourPagesShowInOrder() {
        #expect(SharingTutorialPage.allCases.map { String(localized: $0.heading) } == [
            "Send Each Other Reminders",
            "Connect",
            "Send a Reminder",
            "Who Sees What",
        ])
    }

    /// The mockup's rows: the SF Symbol each names, its title and the line under it.
    @Test(arguments: [
        (SharingTutorialPage.sendEachOtherReminders,
         "Connect with someone you trust, and the reminders you send them nudge on their iPhone like their own.",
         [["icloud", "You both need iCloud", "Sharing goes through iCloud, so each of you signs in to iCloud on your iPhone."],
          ["hand.raised", "Only people you agree to", "You're connected only after one of you accepts the other's invite. Until then, nobody can send you a reminder."]]),
        (.sendAReminder,
         "Pick Send To when you make a reminder, and choose who gets it. It nudges them at the strength you chose.",
         [["paperplane", "It shows your name", "It appears among their reminders, labeled From you. They can mark it Done, pause it, remove it and tag it."],
          ["clock", "Their Delivery Mode", "Each person chooses, for each connection, whether reminders start right away or wait for them to accept first."]]),
        (.whoSeesWhat,
         nil,
         [["lock", "You own what you send", "Only you can change what it says or when it's due. They can't edit it."],
          ["eye", "Status is their choice", "With Status Sharing on, you see whether it's Done, Paused, Missed or Removed. With it off, you see only that it was Delivered."],
          ["person.2", "Disconnect any time", "Settings › Connections. They choose to keep or remove the reminders you sent."],
          ["list.bullet.rectangle", "Share Activity", "Settings › Share Activity shows what happened to sharing that you'd otherwise never see."]]),
    ] as [(SharingTutorialPage, String?, [[String]])])
    func aPageOfPointsHasTheMockupsLeadAndRows(page: SharingTutorialPage, lead: String?, rows: [[String]]) throws {
        guard case .points(let actualLead, let points) = page.content else {
            Issue.record("\(page) isn't a page of points")
            return
        }
        #expect(actualLead.map { String(localized: $0) } == lead)
        #expect(points.map { [$0.symbol, String(localized: $0.title), String(localized: $0.text)] } == rows)
    }

    @Test func connectNumbersItsThreeStepsAndEndsWithANote() {
        guard case .steps(let steps, let footnote) = SharingTutorialPage.connect.content else {
            Issue.record("Connect isn't a page of steps")
            return
        }
        #expect(steps.map { [String(localized: $0.title), String(localized: $0.text)] } == [
            ["Invite Someone", "Settings › Connections. Enter the email address or phone number of their Apple Account."],
            ["Send the Invite", "Through Messages, Mail or Copy Link. Nothing is sent until you tap Send."],
            ["They Accept", "They open the invite on their iPhone, and you're both connected."],
        ])
        #expect(String(localized: footnote) == "An invite opens only for the Apple Account it was sent to, and you both need the latest Nudge-inator.")
    }

    /// The pictures' pills, decoration only: their symbol and word, an arrow as "→".
    @Test(arguments: [
        (SharingTutorialPage.sendEachOtherReminders, ["iphone You", "→", "iphone Maya Torres"]),
        (.connect, ["person.badge.plus Invite", "→", "checkmark.circle.fill Connected"]),
        (.sendAReminder, ["bell From Maya Torres"]),
        (.whoSeesWhat, ["lock Yours", "eye Status"]),
    ])
    func eachPageHasTheMockupsPicture(page: SharingTutorialPage, pieces: [String]) {
        #expect(page.art.map { piece in
            switch piece {
            case .pill(let symbol, let text): "\(symbol) \(String(localized: text))"
            case .arrow: "→"
            }
        } == pieces)
    }

    @Test func nextMovesForwardAPageAndStopsAtTheLast() {
        var paging = SharingTutorialPaging()
        #expect(paging.page == .sendEachOtherReminders)
        #expect(!paging.canGoBack)
        #expect(!paging.isLastPage)
        #expect(String(localized: paging.position) == "Page 1 of 4")

        paging.goForward()
        #expect(paging.page == .connect)
        #expect(paging.canGoBack)
        #expect(String(localized: paging.position) == "Page 2 of 4")

        paging.goForward()
        paging.goForward()
        #expect(paging.page == .whoSeesWhat)
        #expect(paging.isLastPage)
        #expect(String(localized: paging.position) == "Page 4 of 4")

        // Past the last page there's nowhere to go: Next is the confirm checkmark there, which closes the sheet.
        paging.goForward()
        #expect(paging.page == .whoSeesWhat)
    }

    @Test func backMovesBackAPageAndStopsAtTheFirst() {
        var paging = SharingTutorialPaging()
        paging.goForward()
        paging.goForward()
        paging.goBack()
        #expect(paging.page == .connect)
        paging.goBack()
        #expect(paging.page == .sendEachOtherReminders)
        #expect(!paging.canGoBack)
        paging.goBack()
        #expect(paging.page == .sendEachOtherReminders)
    }

    /// A swipe settles on a page, which the paged view sets: Back, the last page and the dots follow it.
    @Test func aSwipeLandsOnAPageAndTheBarAndDotsFollow() {
        var paging = SharingTutorialPaging()
        paging.page = .sendAReminder
        #expect(paging.canGoBack)
        #expect(!paging.isLastPage)
        #expect(String(localized: paging.position) == "Page 3 of 4")

        paging.page = .whoSeesWhat
        #expect(paging.isLastPage)
        paging.goBack()
        #expect(paging.page == .sendAReminder)

        paging.page = .sendEachOtherReminders
        #expect(!paging.canGoBack)
        paging.goForward()
        #expect(paging.page == .connect)
    }
}
