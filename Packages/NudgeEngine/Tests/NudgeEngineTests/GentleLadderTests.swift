import Foundation
import Testing
import NudgeEngine

struct GentleLadderTests {
    let dueTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let reminder: Reminder
    let clock: FakeClock
    let scheduler = FakeScheduler()

    init() {
        reminder = Reminder(title: "Water the plants", dueTime: dueTime, strength: .gentle)
        clock = FakeClock(now: dueTime - 3600)
    }

    func engine() -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])
        return engine
    }

    @Test func reminderNotYetDueHasNoOpenOccurrence() {
        #expect(engine().openOccurrence(for: reminder.id) == nil)
    }

    @Test func atTheDueTimeTheOccurrenceIsNudgingFromNudgeOne() throws {
        clock.now = dueTime
        let occurrence = try #require(engine().openOccurrence(for: reminder.id))
        #expect(occurrence.state == .nudging(nudgeNumber: 1))
    }

    @Test(arguments: [
        (3599, 1),
        (3600, 2),
        (9843, 4),
        (9844, 5),
    ])
    func nudgingOccurrenceIsAtLatestNudgeSent(secondsAfterDue: Int, nudgeNumber: Int) throws {
        clock.now = dueTime + TimeInterval(secondsAfterDue)
        let occurrence = try #require(engine().openOccurrence(for: reminder.id))
        #expect(occurrence.state == .nudging(nudgeNumber: nudgeNumber))
    }

    /// Seconds after the due time, from the mockup's How It Nudges table for Gentle: nudge 1
    /// when due, then waits 1 h, 45 min, 33.8 min (33 min 45 s), 25.3 min (25 min 19 s), then
    /// every 20 min through nudge 20.
    @Test(arguments: [
        (1, 0),
        (2, 3600),
        (3, 6300),
        (4, 8325),
        (5, 9844),
        (6, 11044),
        (20, 27844),
    ])
    func dueReminderPlansNudgeAtGentleLadderTime(nudgeNumber: Int, secondsAfterDue: Int) throws {
        clock.now = dueTime
        _ = engine()
        let plan = try #require(scheduler.lastPlan)
        let item = try #require(plan.items.first { $0.nudgeNumber == nudgeNumber })
        #expect(item.fireTime == dueTime + TimeInterval(secondsAfterDue))
    }

    /// The wait after each nudge: 60 min, easing by 0.75 each nudge, rounded to the whole
    /// second (so 33 min 45 s, not 34 min, and 1518.75 s becomes 1519 s), never below 20 min.
    @Test(arguments: [
        (1, 3600),
        (2, 2700),
        (3, 2025),
        (4, 1519),
        (5, 1200),
        (19, 1200),
    ])
    func gentleWaitEasesToTwentyMinuteFloorRoundedToWholeSecond(afterNudge nudgeNumber: Int, seconds: Int) throws {
        clock.now = dueTime
        _ = engine()
        let items = try #require(scheduler.lastPlan).items
        let this = try #require(items.first { $0.nudgeNumber == nudgeNumber })
        let next = try #require(items.first { $0.nudgeNumber == nudgeNumber + 1 })
        #expect(next.fireTime.timeIntervalSince(this.fireTime) == TimeInterval(seconds))
    }

    @Test func beforeTheDueTimeThePlanAlreadyHoldsTheWholeLadder() throws {
        _ = engine()
        let planBeforeDue = try #require(scheduler.lastPlan)

        #expect(planBeforeDue.items.map(\.nudgeNumber) == Array(1...20))
        #expect(planBeforeDue.items.first?.fireTime == dueTime)

        clock.now = dueTime
        _ = engine()
        #expect(scheduler.lastPlan == planBeforeDue)
    }

    /// Urgency from the mockup's How It Nudges table: Gentle is Normal for nudges 1–4, then
    /// High, and never Urgent.
    @Test(arguments: [
        (1, "Nudge 1 of 20 · Normal"),
        (4, "Nudge 4 of 20 · Normal"),
        (5, "Nudge 5 of 20 · High"),
        (20, "Nudge 20 of 20 · High"),
    ])
    func planItemCarriesTitleAndNudgeCountWithUrgency(nudgeNumber: Int, body: String) throws {
        clock.now = dueTime
        _ = engine()
        let plan = try #require(scheduler.lastPlan)
        let item = try #require(plan.items.first { $0.nudgeNumber == nudgeNumber })
        #expect(item.title == "Water the plants")
        #expect(item.body == body)
    }

    @Test func planItemsCarryNothingFromNotesOrTags() {
        let withPrivateDetails = Reminder(
            title: "Morning meds",
            notes: "Blue pill and vitamin D",
            tags: ["health"],
            dueTime: dueTime,
            strength: .gentle
        )
        clock.now = dueTime
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [withPrivateDetails])

        let items = scheduler.lastPlan?.items ?? []
        #expect(items.count == 20)
        for item in items {
            #expect(item.title == "Morning meds")
            #expect(!item.body.contains("pill"))
            #expect(!item.body.contains("health"))
        }
    }

    /// Gentle never rings as an alarm: Normal nudges are ordinary notifications and High
    /// nudges are Time Sensitive.
    @Test(arguments: [
        (1, DeliveryKind.notification),
        (4, .notification),
        (5, .timeSensitiveNotification),
        (20, .timeSensitiveNotification),
    ])
    func gentleNudgeIsDeliveredAsNotificationByUrgency(nudgeNumber: Int, kind: DeliveryKind) throws {
        clock.now = dueTime
        _ = engine()
        let plan = try #require(scheduler.lastPlan)
        let item = try #require(plan.items.first { $0.nudgeNumber == nudgeNumber })
        #expect(item.deliveryKind == kind)
    }
}
