import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A received copy's alarm sound is the recipient's own (spec #129, ticket 224): the Default Alarm
/// Sound passed in at creation, whatever the sender's reminder has.
struct ReceivedCopyAlarmSoundTests {
    @Test(arguments: AlarmSound.allCases)
    func aCopyStartsWithTheAlarmSoundPassedIn(recipientsSound: AlarmSound) {
        var sendersReminder = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15, 8, 30), strength: .firm)
        sendersReminder.alarmSound = .siren

        let copy = SentReminder(reminder: sendersReminder, revision: 0)
            .copy(through: UUID(), deliveryMode: .startRightAway, alarmSound: recipientsSound)

        #expect(copy.alarmSound == recipientsSound)
        #expect(copy.title == "Take the pills")
    }
}
