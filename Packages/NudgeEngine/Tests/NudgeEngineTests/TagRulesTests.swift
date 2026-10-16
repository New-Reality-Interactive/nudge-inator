import Foundation
import Testing
@testable import NudgeEngine

/// A tag is one word, shown as `#home`, and names are unique ignoring case. Deleting a tag keeps
/// the reminders that used it.
struct TagRulesTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 8))
    let scheduler = FakeScheduler()

    func engine() -> Engine {
        Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
    }

    @Test(arguments: ["#home", "HOME", " home "])
    func aNameDifferingOnlyInCaseOrHashResolvesToTheExistingTag(name: String) throws {
        var engine = engine()
        let home = try engine.createTag(named: "Home")

        #expect(throws: TagNameError.taken(by: home)) { try engine.createTag(named: name) }
        #expect(engine.tags == [home])
    }

    /// The mockup's `cleanTag`: one word, so runs of spaces become one hyphen, and hyphens left at
    /// either end go.
    @Test(arguments: [
        ("doctor visits", "doctor-visits"),
        ("#Side   project", "Side-project"),
        ("- errands -", "errands"),
        ("🏡\tchores", "🏡-chores"),
    ])
    func aNameIsMadeOneWord(typed: String, name: String) throws {
        var engine = engine()

        let tag = try engine.createTag(named: typed)

        #expect(tag.name == name)
    }

    @Test(arguments: ["", "   ", "#", " - "])
    func aNameWithNothingLeftIsRejected(typed: String) {
        var engine = engine()

        #expect(throws: TagNameError.empty) { try engine.createTag(named: typed) }
        #expect(engine.tags.isEmpty)
    }

    @Test func renamingToAnotherTagsNameIgnoringCaseIsRejected() throws {
        var engine = engine()
        let home = try engine.createTag(named: "home")
        let work = try engine.createTag(named: "work")

        #expect(throws: TagNameError.taken(by: home)) { try engine.renameTag(work.id, to: "#Home") }
        #expect(engine.tags == [home, work])
    }

    @Test func renamingCanChangeATagsOwnCasing() throws {
        var engine = engine()
        let home = try engine.createTag(named: "home")

        try engine.renameTag(home.id, to: "#Home")

        #expect(engine.tags == [Tag(id: home.id, name: "Home")])
    }

    @Test func renamingMakesTheNameOneWord() throws {
        var engine = engine()
        let errands = try engine.createTag(named: "errands")

        try engine.renameTag(errands.id, to: " weekend  errands ")

        #expect(engine.tags.map(\.name) == ["weekend-errands"])
    }

    @Test func renamingToNothingIsRejected() throws {
        var engine = engine()
        let home = try engine.createTag(named: "home")

        #expect(throws: TagNameError.empty) { try engine.renameTag(home.id, to: "#") }
        #expect(engine.tags == [home])
    }

    /// The mockup's `deleteTag`: the reminders stay, without the tag, and keep their other tags.
    @Test func deletingATagReportsHowManyRemindersUseItAndKeepsThemAll() {
        let home = Tag(name: "home"), money = Tag(name: "money")
        let reminders = [
            reminder("Take the bins out", tagged: [home]),
            reminder("Pay rent", tagged: [money, home]),
            reminder("Water the plants", tagged: [home]),
            reminder("Renew passport", tagged: [money]),
            reminder("Call Grandma", tagged: []),
        ]
        var engine = engine()
        engine.update(tags: [home, money])
        engine.update(reminders: reminders)

        let used = engine.deleteTag(home.id)

        #expect(used == 3)
        #expect(engine.tags == [money])
        #expect(engine.reminders.map(\.id) == reminders.map(\.id))
        #expect(engine.reminders.map(\.tagIDs) == [[], [money.id], [], [money.id], []])
    }

    /// The reverse of deleting a tag (ticket 12): the tag outlives its last reminder.
    @Test func deletingAReminderKeepsItsTags() {
        let home = Tag(name: "home")
        let bins = reminder("Take the bins out", tagged: [home])
        var engine = engine()
        engine.update(tags: [home])
        engine.update(reminders: [bins])

        engine.delete(bins.id)

        #expect(engine.tags == [home])
    }

    /// A tag's screen on the Tags tab, in the store's order.
    @Test func aTagsRemindersAreTheOnesWithIt() {
        let home = Tag(name: "home"), money = Tag(name: "money")
        let bins = reminder("Take the bins out", tagged: [home])
        let rent = reminder("Pay rent", tagged: [money, home])
        let passport = reminder("Renew passport", tagged: [money])
        var engine = engine()
        engine.update(tags: [home, money])
        engine.update(reminders: [bins, rent, passport])

        #expect(engine.taggedReminders(home.id) == [bins, rent])
        #expect(engine.taggedReminders(money.id) == [rent, passport])
    }

    func reminder(_ title: String, tagged tags: [Tag]) -> Reminder {
        Reminder(title: title, tagIDs: tags.map(\.id), dueTime: NewYork.local(2026, 10, 16, 18), strength: .gentle)
    }
}
