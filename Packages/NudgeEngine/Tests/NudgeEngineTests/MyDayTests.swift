import Foundation
import Testing
@testable import NudgeEngine

/// My Day: today's occurrences in time order, with Done, Nudging, Missed and Left counts. Skipped
/// and paused ones are listed but in no count. The counts double as a filter, and the list can be
/// filtered by tags (Match All, Match Any) or to reminders with no tags.
struct MyDayTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 6))
    let scheduler = FakeScheduler()

    let home = Tag(name: "home"), health = Tag(name: "health"), work = Tag(name: "work")

    let meds: Reminder, dog: Reminder, standUp: Reminder, stretch: Reminder, alex: Reminder
    let status: Reminder, grandma: Reminder, plants: Reminder, bins: Reminder, dentist: Reminder

    init() {
        func at(_ hour: Int, _ minute: Int = 0) -> Date { NewYork.local(2026, 10, 16, hour, minute) }
        meds = Reminder(title: "Morning meds", tagIDs: [health.id], dueTime: NewYork.local(2026, 10, 1, 6, 30), repeatRule: .everyDay, strength: .gentle)
        dog = Reminder(title: "Walk the dog", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 1, 7), repeatRule: .everyDay, strength: .gentle)
        standUp = Reminder(title: "Team stand-up", tagIDs: [work.id], dueTime: at(9, 30), strength: .relentless)
        stretch = Reminder(title: "Stretch break", tagIDs: [health.id, work.id], dueTime: NewYork.local(2026, 10, 1, 10), repeatRule: .everyDay, strength: .firm)
        alex = Reminder(title: "Reply to Alex", dueTime: at(12, 30), strength: .firm)
        status = Reminder(title: "Send the status update", tagIDs: [work.id], dueTime: at(16, 30), strength: .gentle)
        grandma = Reminder(title: "Call Grandma", dueTime: NewYork.local(2026, 10, 2, 17), repeatRule: .everyDay, strength: .gentle)
        plants = Reminder(title: "Water the plants", tagIDs: [home.id], dueTime: at(18), strength: .gentle)
        bins = Reminder(title: "Take the bins out", tagIDs: [home.id], dueTime: at(20), strength: .firm)
        dentist = Reminder(title: "Dentist appointment", tagIDs: [health.id], dueTime: NewYork.local(2026, 10, 17, 13, 15), strength: .firm)
    }

    /// 13:00 on Friday 16 October. Meds and the dog were Done in the morning, the stand-up gave
    /// up, the stretch break was paused while nudging, Alex is nudging, Grandma is paused before
    /// her due time, and three are still to come. The dentist is tomorrow.
    func engineAtOnePM() -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(tags: [home, health, work])
        engine.update(reminders: [bins, plants, grandma, status, alex, stretch, standUp, dog, meds, dentist])
        clock.now = NewYork.local(2026, 10, 16, 7, 4)
        engine.markDone(meds.id)
        clock.now = NewYork.local(2026, 10, 16, 7, 18)
        engine.markDone(dog.id)
        clock.now = NewYork.local(2026, 10, 16, 10, 10)
        engine.pause(stretch.id)
        clock.now = NewYork.local(2026, 10, 16, 13)
        engine.pause(grandma.id)
        engine.update(reminders: engine.reminders)
        return engine
    }

    @Test func listsTodaysOccurrencesInTimeOrderWithWhatHappenedToEach() {
        let engine = engineAtOnePM()

        let items = engine.myDay().items

        #expect(items.map(\.reminderID) == [meds, dog, standUp, stretch, alex, status, grandma, plants, bins].map(\.id))
        #expect(items.map(\.status) == [
            .due(.done),
            .due(.done),
            .due(.missed(reason: .giveUpLimit)),
            .due(.skipped(reason: .paused)),
            .due(.nudging(nudgeNumber: 2)),
            .left,
            .paused,
            .left,
            .left,
        ])
        #expect(items.first?.dueTime == NewYork.local(2026, 10, 16, 6, 30))
    }

    /// Nine items, seven counted: the Skipped stretch break and paused Grandma are in no count, so
    /// a pause isn't counted against the person.
    @Test(arguments: [(MyDayCount.done, 2), (.nudging, 1), (.missed, 1), (.left, 3)])
    func countsEachStatusAndLeavesSkippedAndPausedOut(count: MyDayCount, expected: Int) {
        let myDay = engineAtOnePM().myDay()

        #expect(myDay.count(of: count) == expected)
        #expect(MyDayCount.allCases.map(myDay.count(of:)).reduce(0, +) == 7)
    }

    @Test func choosingACountListsOnlyItsItemsInTimeOrder() {
        let myDay = engineAtOnePM().myDay()

        #expect(myDay.items(in: .missed).map(\.reminderID) == [standUp.id])
        #expect(myDay.items(in: .left).map(\.reminderID) == [status, plants, bins].map(\.id))
    }

    /// Only the stretch break has both #health and #work; four have one of them; Alex and Grandma
    /// have no tags.
    @Test func matchAllAnyAndNoTagsGiveDifferentLists() {
        let engine = engineAtOnePM()
        let healthAndWork: Set = [health.id, work.id]

        #expect(engine.myDay(tagFilter: .matchAll(healthAndWork)).items.map(\.reminderID) == [stretch.id])
        #expect(engine.myDay(tagFilter: .matchAny(healthAndWork)).items.map(\.reminderID) == [meds, standUp, stretch, status].map(\.id))
        #expect(engine.myDay(tagFilter: .noTags).items.map(\.reminderID) == [alex, grandma].map(\.id))
    }

    /// The counts cover what the tag filter lets through, as in the mockup's `viewDay`: #home has
    /// the dog (Done) and two still to come.
    @Test(arguments: [(MyDayCount.done, 1), (.nudging, 0), (.missed, 0), (.left, 2)])
    func countsFollowTheTagFilter(count: MyDayCount, expected: Int) {
        let myDay = engineAtOnePM().myDay(tagFilter: .matchAny([home.id]))

        #expect(myDay.count(of: count) == expected)
    }

    /// The filter sheet open with no tag checked filters nothing.
    @Test(arguments: [TagFilter.matchAll([]), .matchAny([])])
    func noTagChosenListsEveryItem(filter: TagFilter) {
        let engine = engineAtOnePM()

        #expect(engine.myDay(tagFilter: filter) == engine.myDay())
    }

    /// Sunday 1 November 2026, when New York falls back, is 25 hours long. Today runs from local
    /// midnight to local midnight, so 23:30 is in it and the next day's 0:30 isn't.
    @Test func todayIsTheLocalDayAcrossAFallBack() {
        clock.now = NewYork.local(2026, 11, 1, 12)
        let early = Reminder(title: "Early", dueTime: NewYork.local(2026, 10, 1, 0, 30), repeatRule: .everyDay, strength: .gentle)
        let late = Reminder(title: "Late", dueTime: NewYork.local(2026, 10, 1, 23, 30), repeatRule: .everyDay, strength: .gentle)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [late, early])

        let items = engine.myDay().items

        #expect(items.map(\.dueTime) == [NewYork.local(2026, 11, 1, 0, 30), NewYork.local(2026, 11, 1, 23, 30)])
    }
}
