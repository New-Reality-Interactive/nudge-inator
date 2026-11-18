import Foundation
import Testing
@testable import NudgeEngine

/// A reminder has an alarm sound, Default unless set. It is a reminder field like the title and
/// notes, so ADR 0002's lock leaves it editable while Nudging, and every plan item carries it for
/// the alarm adapter. It is local: a sender's revision never changes a received copy's.
struct AlarmSoundTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    /// Every day at 9:00 from Thursday 15 October 2026.
    let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)

    func engine(for reminder: Reminder) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder])
        return engine
    }

    // MARK: The sound

    @Test func thereAreSevenSoundsWithDefaultFirst() {
        #expect(AlarmSound.allCases == [.default, .chime, .bell, .pulse, .beacon, .rise, .siren])
    }

    /// The IDs are saved, so they are spelled out: a rename of a case must not change one.
    static let ids: [(AlarmSound, String)] = [
        (.default, "default"), (.chime, "chime"), (.bell, "bell"), (.pulse, "pulse"),
        (.beacon, "beacon"), (.rise, "rise"), (.siren, "siren"),
    ]

    @Test(arguments: ids)
    func eachSoundHasAStableIDThatReadsBackAsThatSound(sound: AlarmSound, id: String) {
        #expect(sound.id == id)
        #expect(AlarmSound(id: id) == sound)
    }

    @Test(arguments: ["", "Chime", "gong", "chime.caf", "🔔"])
    func anIDTheEngineDoesntRecognizeReadsAsDefault(id: String) {
        #expect(AlarmSound(id: id) == .default)
    }

    // MARK: On the reminder

    @Test func aNewReminderIsDefault() {
        #expect(pills.alarmSound == .default)
    }

    @Test(arguments: AlarmSound.allCases)
    func aReminderKeepsTheSoundItIsMadeWith(sound: AlarmSound) {
        let reminder = Reminder(title: "Take the pills", dueTime: pills.dueTime, strength: .firm, alarmSound: sound)
        #expect(reminder.alarmSound == sound)
    }

    // MARK: Edit

    @Test(arguments: AlarmSound.allCases)
    func anEditChangesTheSound(sound: AlarmSound) throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: pills)

        var edited = pills
        edited.alarmSound = sound
        try engine.edit(edited)

        #expect(engine.reminder(pills.id)?.alarmSound == sound)
    }

    /// At 9:40 Firm's nudges 1 and 2 have come: the reminder is Nudging, so its locked fields stay
    /// locked, and the sound isn't one of them.
    @Test(arguments: AlarmSound.allCases)
    func anEditChangesTheSoundWhileNudgingAndTheLockedFieldsStayLocked(sound: AlarmSound) throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        #expect(engine.openOccurrence(for: pills.id) != nil)
        #expect(engine.lockedFields(of: pills.id) == Set(LockedField.allCases))

        var edited = pills
        edited.alarmSound = sound
        try engine.edit(edited)
        #expect(engine.reminder(pills.id)?.alarmSound == sound)
        #expect(engine.lockedFields(of: pills.id) == Set(LockedField.allCases))

        var alsoMoved = edited
        alsoMoved.strength = .gentle
        #expect(throws: EditError.locked([.strength])) { try engine.edit(alsoMoved) }
        #expect(engine.reminder(pills.id)?.strength == .firm)
    }

    // MARK: The plan

    @Test(arguments: AlarmSound.allCases)
    func everyPlanItemCarriesItsRemindersSound(sound: AlarmSound) throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        var reminder = pills
        reminder.alarmSound = sound
        _ = engine(for: reminder)

        let items = try #require(scheduler.lastPlan).items
        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.alarmSound == sound })
    }

    @Test func aReminderWithoutASoundPlansDefaultItems() throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        _ = engine(for: pills)
        #expect(try #require(scheduler.lastPlan).items.allSatisfy { $0.alarmSound == .default })
    }

    /// An Edit to the sound while Nudging re-plans the later items with the new one.
    @Test func aSoundEditWhileNudgingReachesTheLaterPlanItems() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        var edited = pills
        edited.alarmSound = .siren
        try engine.edit(edited)

        let later = try #require(scheduler.lastPlan).items.filter { $0.fireTime > clock.now }
        #expect(!later.isEmpty)
        #expect(later.allSatisfy { $0.alarmSound == .siren })
    }

    /// The sound decides nothing about delivery: the same reminder plans the same items, kinds
    /// and times, with any sound.
    @Test(arguments: AlarmSound.allCases)
    func theSoundChangesNeitherWhichItemsAreAlarmsNorWhenTheyFire(sound: AlarmSound) throws {
        clock.now = NewYork.local(2026, 10, 15, 8)
        _ = engine(for: pills)
        let baseline = try #require(scheduler.lastPlan).items

        var reminder = pills
        reminder.alarmSound = sound
        _ = engine(for: reminder)
        let items = try #require(scheduler.lastPlan).items

        #expect(items.map(\.deliveryKind) == baseline.map(\.deliveryKind))
        #expect(items.map(\.fireTime) == baseline.map(\.fireTime))
        #expect(items.map(\.urgency) == baseline.map(\.urgency))
        #expect(items.map(\.isPastAlarmLimit) == baseline.map(\.isPastAlarmLimit))
    }

    // MARK: Received copies

    /// A received copy whose recipient chose Bell, and the sender's revision 4 of everything else.
    @Test(arguments: AlarmSound.allCases)
    func aSendersRevisionLeavesAReceivedCopysSoundAsTheRecipientSetIt(sendersSound: AlarmSound) throws {
        let connectionID = UUID()
        let sendersReminderID = UUID()
        let copy = Reminder(
            title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm,
            alarmSound: .bell,
            origin: .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 3, state: .accepted)
        )
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: copy)

        var revised = copy
        revised.title = "Take the vitamins"
        revised.alarmSound = sendersSound
        revised.origin = .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 4, state: .accepted)
        let changes = engine.applySendersRevision(revised)

        #expect(changes == [.title(from: "Take the pills", to: "Take the vitamins")])
        #expect(engine.reminder(copy.id)?.title == "Take the vitamins")
        #expect(engine.reminder(copy.id)?.alarmSound == .bell)
        #expect(try #require(scheduler.lastPlan).items.allSatisfy { $0.alarmSound == .bell })
    }

    /// A received copy's content is the sender's, but the sound is the recipient's own, so an Edit
    /// that changes only the sound is accepted, and one that changes the content is still rejected.
    @Test func theRecipientCanChangeAReceivedCopysSoundButNotItsContent() throws {
        let copy = Reminder(
            title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm,
            origin: .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 3, state: .accepted)
        )
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: copy)

        var edited = copy
        edited.alarmSound = .chime
        try engine.edit(edited)
        #expect(engine.reminder(copy.id)?.alarmSound == .chime)

        edited.title = "Something else"
        #expect(throws: EditError.receivedContent([.title])) { try engine.edit(edited) }
    }
}
