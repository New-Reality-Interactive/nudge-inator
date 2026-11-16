import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// What the app tells VoiceOver when something changes away from where its focus is (#221): the
/// sentences, and when an error or a result count is spoken. Whether VoiceOver speaks them, and
/// where its focus goes, are phone checks.
struct VoiceOverAnnouncementTests {
    @Test(arguments: [
        (ReminderForm.SaveBlock.noTitle, "Add a title to save."),
        (.pastTime, "This time has passed. Choose a later time."),
        (.endsBeforeStart, "The repeat ends before it starts. Change its end date."),
        (.noTimesLeft, "The repeat has already ended. Change when it ends."),
    ])
    func eachFormSaveBlockSaysWhatItsFooterShows(block: ReminderForm.SaveBlock, message: String) {
        #expect(String(localized: block.message) == message)
    }

    @Test(arguments: [
        (nil, ReminderForm.SaveBlock.noTitle, ReminderForm.SaveBlock?.some(.noTitle)),
        (.noTitle, .pastTime, .pastTime),
        (.noTitle, nil, nil),
        (.noTitle, .noTitle, nil),
    ] as [(ReminderForm.SaveBlock?, ReminderForm.SaveBlock?, ReminderForm.SaveBlock?)])
    func aMessageIsSpokenWhenItAppearsOrChangesButNotWhenItGoes(old: ReminderForm.SaveBlock?, new: ReminderForm.SaveBlock?, spoken: ReminderForm.SaveBlock?) {
        #expect(VoiceOverAnnouncement.spoken(from: old, to: new) == spoken)
    }

    @Test(arguments: [
        (VoiceOverAnnouncement.done("Take the bins out"), "Take the bins out is Done. Its nudges have stopped."),
        (VoiceOverAnnouncement.accepted("Take the pills"), "Take the pills accepted. It nudges you as your own reminders do."),
        (VoiceOverAnnouncement.removed("Take the pills"), "Take the pills removed."),
        (VoiceOverAnnouncement.paused("Water the plants"), "Water the plants paused. It won't nudge you until you resume it."),
        (VoiceOverAnnouncement.resumed("Water the plants"), "Water the plants resumed. It nudges you when it's next due."),
        (VoiceOverAnnouncement.inviteSent(to: "Riley Park"), "Invite sent to Riley Park."),
        (VoiceOverAnnouncement.disconnected(from: "Riley Park"), "Disconnected from Riley Park."),
    ])
    func eachChangeAwayFromVoiceOversFocusIsSpokenWithItsReminderOrPerson(sentence: LocalizedStringResource, english: String) {
        #expect(String(localized: sentence) == english)
    }

    @Test func eachTagNameProblemSaysWhatTheSheetShows() throws {
        let engine = Engine.myDayPreview()
        let home = try #require(engine.tags.first { $0.name == "home" })

        #expect(String(localized: TagNameDraft.Problem.empty.message) == "Enter a name for the tag.")
        #expect(String(localized: TagNameDraft.Problem.taken(home).message) == "You already have the tag #home.")
    }
}
