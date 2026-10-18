import Foundation
import Testing
@testable import NudgeEngine

/// What a Now tab nudge card says about an open occurrence: how many nudges it has sent of its
/// limit, the urgency now, and when the next nudge comes, at what urgency and how it arrives.
struct NudgingStatusTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 8))
    let scheduler = FakeScheduler()
    /// Firm, due 9:00: nudges 1–4 at 9:00, 9:30, 9:45 and 9:52:30. Nudges 1–2 are Normal, 3 is
    /// High, and 4 on are Urgent.
    let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 16, 9), strength: .firm)

    func engine(permissions: PermissionStates = PermissionStates(), holding reminders: [Reminder]) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        engine.update(reminders: reminders)
        return engine
    }

    @Test func aCardSaysTheNudgesSentTheUrgencyNowAndTheNextNudge() throws {
        let engine = engine(holding: [bins])
        clock.now = NewYork.local(2026, 10, 16, 9, 40)

        let status = try #require(engine.nudgingStatus(of: bins.id))

        #expect(status.dueTime == NewYork.local(2026, 10, 16, 9))
        #expect(status.nudgesSent == 2)
        #expect(status.nudgeLimit == 20)
        #expect(status.urgency == .normal)
        #expect(status.nextNudge == NextNudge(
            nudgeNumber: 3,
            fireTime: NewYork.local(2026, 10, 16, 9, 45),
            urgency: .high,
            delivery: .notification(fallback: nil)
        ))
    }

    struct DeliveryCase: Sendable, CustomTestStringConvertible {
        /// When the card is read: at 9:10 the next nudge is Normal, at 9:40 High, at 9:50 Urgent.
        var minute: Int
        var breakThroughFocus = true
        var permissions = PermissionStates()
        var expected: NudgeDelivery
        var testDescription: String { "9:\(minute), \(breakThroughFocus ? "breaks through" : "held"), \(permissions) → \(expected)" }
    }

    /// The mockup's `viaLabel`: a nudge that arrives a weaker way than its urgency says why, and
    /// one that can't arrive says so. Normal is never weaker. An alarm still rings with
    /// notifications off.
    @Test(arguments: [
        DeliveryCase(minute: 50, expected: .alarm),
        DeliveryCase(minute: 50, permissions: PermissionStates(timeSensitive: .off), expected: .alarm),
        DeliveryCase(minute: 50, permissions: PermissionStates(notifications: .denied), expected: .alarm),
        DeliveryCase(minute: 50, permissions: PermissionStates(alarms: .denied), expected: .notification(fallback: .alarmsOff)),
        DeliveryCase(minute: 50, permissions: PermissionStates(alarms: .denied, timeSensitive: .off), expected: .notification(fallback: .alarmsAndTimeSensitiveOff)),
        DeliveryCase(minute: 50, permissions: PermissionStates(notifications: .denied, alarms: .denied), expected: .cannotArrive),
        DeliveryCase(minute: 50, breakThroughFocus: false, expected: .notification(fallback: .breakThroughFocusOff)),
        DeliveryCase(minute: 40, expected: .notification(fallback: nil)),
        DeliveryCase(minute: 40, permissions: PermissionStates(timeSensitive: .off), expected: .notification(fallback: .timeSensitiveOff)),
        DeliveryCase(minute: 40, breakThroughFocus: false, permissions: PermissionStates(timeSensitive: .off), expected: .notification(fallback: .breakThroughFocusOff)),
        DeliveryCase(minute: 40, permissions: PermissionStates(notifications: .denied), expected: .cannotArrive),
        DeliveryCase(minute: 10, breakThroughFocus: false, expected: .notification(fallback: nil)),
        DeliveryCase(minute: 10, permissions: PermissionStates(timeSensitive: .off), expected: .notification(fallback: nil)),
        DeliveryCase(minute: 10, permissions: PermissionStates(notifications: .denied), expected: .cannotArrive),
    ])
    func theNextNudgeSaysHowItArrives(_ check: DeliveryCase) throws {
        var bins = bins
        bins.breakThroughFocus = check.breakThroughFocus
        let engine = engine(permissions: check.permissions, holding: [bins])
        clock.now = NewYork.local(2026, 10, 16, 9, check.minute)

        let nextNudge = try #require(engine.nudgingStatus(of: bins.id)?.nextNudge)

        #expect(nextNudge.delivery == check.expected)
    }

    /// With room for one alarm, nudge 4 at 9:52:30 rings and nudge 5 at 9:57:30 falls back.
    @Test func anUrgentNudgePastTheAlarmLimitSaysSo() throws {
        var engine = Engine(clock: clock, scheduler: scheduler, giveUpLimit: .shipped, alarmLimit: AlarmLimit(pendingAlarms: 1), timeZone: NewYork.timeZone)
        engine.update(reminders: [bins])
        clock.now = NewYork.local(2026, 10, 16, 9, 53)

        let nextNudge = try #require(engine.nudgingStatus(of: bins.id)?.nextNudge)

        #expect(nextNudge.nudgeNumber == 5)
        #expect(nextNudge.delivery == .notification(fallback: .pastAlarmLimit))
    }

    /// Firm's nudge 20 fires at 11:12:30, five minutes after nudge 19, and it gives up a wait
    /// later, at 11:17:30. Until then the card says that was the last nudge and when it closes.
    @Test func afterTheLastNudgeThereIsNoNextAndTheCardSaysWhenItCloses() throws {
        let engine = engine(holding: [bins])
        clock.now = NewYork.local(2026, 10, 16, 11, 15)

        let status = try #require(engine.nudgingStatus(of: bins.id))

        #expect(status.nudgesSent == 20)
        #expect(status.nextNudge == nil)
        #expect(status.missedAt == Date(timeInterval: 30, since: NewYork.local(2026, 10, 16, 11, 17)))
    }

    /// In en_US and New York at 8:00 on Friday 16 October: the Now rows' time column, in the
    /// engine's locale and time zone, as the repeat summary writes them.
    @Test(arguments: [
        (NewYork.local(2026, 10, 16, 23, 30), "Today", "11:30\u{202F}PM"),
        (NewYork.local(2026, 10, 17, 0, 5), "Tomorrow", "12:05\u{202F}AM"),
        (NewYork.local(2026, 10, 15, 16, 4), "Yesterday", "4:04\u{202F}PM"),
        (NewYork.local(2026, 10, 20, 9), "Tue, Oct 20", "9:00\u{202F}AM"),
    ])
    func aTimeReadsAsItsDayAndTimeOfDay(date: Date, day: String, time: String) {
        let engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, locale: Locale(identifier: "en_US"))

        #expect(engine.dayLabel(of: date) == day)
        #expect(engine.timeOfDay(of: date) == time)
    }

    /// With the give-up limit widened, a daily 9:00 Firm reminder nudges every 5 minutes until the
    /// next occurrence takes over. Its last nudge before the take-over is at 8:57:30 the next day;
    /// the one after would be at 9:02:30, after the take-over, so there is none to come.
    @Test func aNudgeTheNextOccurrenceWouldTakeOverIsntComing() throws {
        let widened = GiveUpLimit(nudgeCount: 10_000, span: 72 * 60 * 60)
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 16), repeatRule: .everyDay, strength: .firm)
        var engine = Engine(clock: clock, scheduler: scheduler, giveUpLimit: widened, timeZone: NewYork.timeZone)
        engine.update(reminders: [pills])
        clock.now = NewYork.local(2026, 10, 17, 8, 58)

        let status = try #require(engine.nudgingStatus(of: pills.id))

        #expect(status.nextNudge == nil)
        #expect(status.missedAt == NewYork.local(2026, 10, 17))
    }
}
