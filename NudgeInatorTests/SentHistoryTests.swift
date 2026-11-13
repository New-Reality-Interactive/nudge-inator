import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A repeating reminder's 7-day history on the Sent view (ticket 207, spec #127 seam 1): Alex sends
/// Riley a daily reminder, a week of Riley's days goes by, and the tests read Alex's Sent row and the
/// sent reminder's details as Alex's app model builds them. Layout and VoiceOver are the phone check.
@MainActor
struct SentHistoryTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm, from Thursday 15 October: the phones' clocks say 8:00 that day.
    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm,
        pace: .consistent(wait: 10 * 60)
    )
    /// Due at 9:00 on 15 October, once, Gentle.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 15, 9, 0), strength: .gentle)

    /// Alex and Riley, connected, launched and joined by the network.
    func phones(sharesStatus: Bool = true, deliveryMode: DeliveryMode = .startRightAway) async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected, theirs: ConnectionChoices(sharesStatus: sharesStatus, deliveryMode: deliveryMode)),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(sharesStatus: sharesStatus, deliveryMode: deliveryMode)),
        ]))
        network.join(alex.adapter, riley.adapter, through: connectionID)
        for phone in [alex, riley] { await phone.launch() }
        return (alex, riley)
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    /// Both phones at `hour`:`minute` on `day` October, the app opened on each.
    func open(_ alex: Phone, _ riley: Phone, on day: Int, at hour: Int, _ minute: Int) async {
        for phone in [alex, riley] {
            phone.clock.now = NewYork.local(2026, 10, day, hour, minute)
            await phone.model.appOpened()
        }
        await settle(alex, riley)
    }

    /// The pills sent on Thursday 15 October, then a week: Riley marks each day's Done except
    /// Friday's, which is Missed, and it is 8:00 on Thursday 22 October, the day's still Coming up.
    func aWeekOfPills(sharesStatus: Bool = true) async throws -> (alex: Phone, riley: Phone) {
        let (alex, riley) = try await phones(sharesStatus: sharesStatus)
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        for day in 15...21 {
            await open(alex, riley, on: day, at: 8, 35)
            if day != 16 {
                riley.model.markDone(try copy(on: riley).id)
                await settle(alex, riley)
            }
        }
        await open(alex, riley, on: 22, at: 8, 0)
        return (alex, riley)
    }

    func row(on alex: Phone) throws -> SentScreen.Row {
        try #require(SentScreen(engine: alex.model.engine, sharing: alex.sharing.data).people.first?.rows.first)
    }

    func recipient(on alex: Phone, of reminder: Reminder) throws -> SentReminderDetails.Recipient {
        try #require(SentReminderDetails(engine: alex.model.engine, sharing: alex.sharing.data, id: reminder.id)?.recipients.first)
    }

    func copy(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    // MARK: The history

    @Test func aRepeatingRowShowsTodayAndTheSevenDaysBeforeEachWithItsStatus() async throws {
        let (alex, _) = try await aWeekOfPills()

        let history = try #require(try row(on: alex).history)

        #expect(history.days.map(\.status) == [.done, .missed, .done, .done, .done, .done, .done, .comingUp])
        #expect(history.days.map(\.initial) == ["T", "F", "S", "S", "M", "T", "W", "T"])
        #expect(history.days.map(\.isToday) == [false, false, false, false, false, false, false, true])
        #expect(history.voiceOverValue == "Thursday: Done, Friday: Missed, Saturday: Done, Sunday: Done, Monday: Done, Tuesday: Done, Wednesday: Done, Today: Coming up")
    }

    @Test func theRowsStatusLabelDetailLineAndVoiceOverLabelStayAsTheyWere() async throws {
        let (alex, _) = try await aWeekOfPills()

        let row = try row(on: alex)

        #expect(row.trailing == .status(.comingUp))
        #expect(String(localized: try #require(row.detailLine)) == "Delivered")
        #expect(String(localized: row.voiceOverLabel) == "Riley Park, Take the pills, Coming up, Today, 8:30\u{202F}AM")
    }

    @Test func theDetailsListTheDaysNewestFirstInWords() async throws {
        let (alex, _) = try await aWeekOfPills()

        let recipient = try recipient(on: alex, of: pills)
        let history = try #require(recipient.history)

        #expect(String(localized: recipient.historyHeader) == "Riley, Last 7 Days")
        #expect(history.newestFirst.map(\.label) == ["Today", "Wed, Oct 21", "Tue, Oct 20", "Mon, Oct 19", "Sun, Oct 18", "Sat, Oct 17", "Fri, Oct 16", "Thu, Oct 15"])
        #expect(history.newestFirst.map(\.status) == [.comingUp, .done, .done, .done, .done, .done, .missed, .done])
        #expect(history.newestFirst.map(\.glyph) == ["clock", "checkmark.circle.fill", "checkmark.circle.fill", "checkmark.circle.fill", "checkmark.circle.fill", "checkmark.circle.fill", "xmark.circle.fill", "checkmark.circle.fill"])
    }

    @Test func aDayBeforeItWasSentHasNothingDue() async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        await open(alex, riley, on: 16, at: 8, 0)

        let history = try #require(try row(on: alex).history)

        #expect(history.days.map(\.status) == [nil, nil, nil, nil, nil, nil, .missed, .comingUp])
        #expect(history.days.first?.glyph == "circle.slash")
        #expect(history.voiceOverValue.hasPrefix("Friday: Nothing due, "))
    }

    // MARK: When it's hidden

    @Test func aOneOffHasNoHistory() async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(call, to: [connectionID])
        await settle(alex, riley)
        await open(alex, riley, on: 15, at: 9, 5)

        #expect(try row(on: alex).history == nil)
        #expect(try recipient(on: alex, of: call).history == nil)
    }

    @Test func turningStatusSharingOffHidesTheHistoryAndOnShowsItAgain() async throws {
        let (alex, riley) = try await aWeekOfPills()

        try riley.sharing.change(ConnectionChoices(sharesStatus: false), for: connectionID)
        await settle(alex, riley)
        #expect(try row(on: alex).history == nil)
        #expect(try recipient(on: alex, of: pills).history == nil)

        try riley.sharing.change(ConnectionChoices(sharesStatus: true), for: connectionID)
        await settle(alex, riley)
        let history = try #require(try row(on: alex).history)
        #expect(history.days.map(\.status) == [.done, .missed, .done, .done, .done, .done, .done, .comingUp])
    }

    @Test func notSharingThisOneHidesTheHistory() async throws {
        let (alex, riley) = try await aWeekOfPills()

        try riley.model.setNotSharing(true, for: try copy(on: riley).id)
        await settle(alex, riley)

        #expect(try row(on: alex).history == nil)
        #expect(try recipient(on: alex, of: pills).history == nil)
    }

    @Test func waitingToSyncHidesTheHistory() async throws {
        let (alex, _) = try await aWeekOfPills()
        var sharing = alex.sharing.data
        sharing.sentCopies[0].waitingToSync = true

        let screen = SentScreen(engine: alex.model.engine, sharing: sharing)

        #expect(try #require(screen.people.first?.rows.first).history == nil)
    }

    @Test func aCopyWaitingForThemToAcceptHasNoHistory() async throws {
        let (alex, riley) = try await phones(deliveryMode: .askMeFirst)
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        await open(alex, riley, on: 16, at: 8, 0)

        #expect(try row(on: alex).delivery == .waitingForAcceptance)
        #expect(try row(on: alex).history == nil)
    }
}
