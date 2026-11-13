import Foundation
import Testing
@testable import NudgeEngine

/// What a status record the sender just received is news of, against the one it held (ticket 208,
/// spec #127, Status): Done, Missed or Removed, and nothing for the rest.
struct SenderNoticeEventTests {
    let eight = Date(timeIntervalSince1970: 1_000_000)
    let nextDay = Date(timeIntervalSince1970: 1_000_000 + 86_400)
    let dayAfter = Date(timeIntervalSince1970: 1_000_000 + 2 * 86_400)

    static let nudging = SentCopy.StatusRecord(report: StatusReport(label: .nudging, occurrences: []), notSharingThisOne: false)
    static let removed = SentCopy.StatusRecord(report: StatusReport(label: .removed, occurrences: []), notSharingThisOne: false)

    func occurrence(_ dueTime: Date, _ label: ReportedStatus) -> StatusReport.OccurrenceStatus {
        StatusReport.OccurrenceStatus(dueTime: dueTime, day: CalendarDay(year: 2026, month: 10, day: Int(dueTime.timeIntervalSince1970 / 86_400) - 11_000), label: label)
    }

    /// A record of a copy reading `label`, with these occurrences, oldest first.
    func record(_ label: ReportedStatus, _ occurrences: [StatusReport.OccurrenceStatus] = [], notSharingThisOne: Bool = false) -> SentCopy.StatusRecord {
        SentCopy.StatusRecord(report: StatusReport(label: label, occurrences: occurrences), notSharingThisOne: notSharingThisOne)
    }

    @Test func aRepeatingCopyMarkedDoneIsNewsEvenThoughItsLabelReadsComingUpAgain() {
        let held = record(.nudging, [occurrence(eight, .nudging)])
        let arriving = record(.comingUp, [occurrence(eight, .done)])

        #expect(SenderNoticeEvent(held: held, arriving: arriving) == SenderNoticeEvent(kind: .done, occurrence: eight))
    }

    @Test func aMissedOccurrenceIsNews() {
        let held = record(.nudging, [occurrence(eight, .nudging)])
        let arriving = record(.comingUp, [occurrence(eight, .missed)])

        #expect(SenderNoticeEvent(held: held, arriving: arriving) == SenderNoticeEvent(kind: .missed, occurrence: eight))
    }

    @Test(arguments: [nil, SentCopy.StatusRecord.heldBackRecord, SenderNoticeEventTests.nudging])
    func aCopyRemovedIsNewsWhateverTheSenderHeldButNotTwice(held: SentCopy.StatusRecord?) {
        #expect(SenderNoticeEvent(held: held, arriving: Self.removed) == SenderNoticeEvent(kind: .removed, occurrence: nil))
    }

    @Test func aCopyAlreadyHeldRemovedIsNoNews() {
        #expect(SenderNoticeEvent(held: Self.removed, arriving: Self.removed) == nil)
    }

    @Test func eachEventHasItsOwnToken() {
        #expect(SenderNoticeEvent(kind: .done, occurrence: eight).token != SenderNoticeEvent(kind: .missed, occurrence: eight).token)
        #expect(SenderNoticeEvent(kind: .done, occurrence: eight).token != SenderNoticeEvent(kind: .done, occurrence: nextDay).token)
        #expect(SenderNoticeEvent(kind: .done, occurrence: eight).token == SenderNoticeEvent(kind: .done, occurrence: eight).token)
        #expect(SenderNoticeEvent(kind: .removed, occurrence: nil).token != SenderNoticeEvent(kind: .done, occurrence: nil).token)
    }

    @Test func aStatusTheSenderAlreadyHeldIsNoNews() {
        let done = record(.comingUp, [occurrence(eight, .done)])

        #expect(SenderNoticeEvent(held: done, arriving: done) == nil)
        #expect(SenderNoticeEvent(held: record(.missed, [occurrence(eight, .missed)]), arriving: record(.missed, [occurrence(eight, .missed)])) == nil)
    }

    @Test func pauseResumeSkippedAndTheDayRollingOverAreNoNews() {
        let held = record(.nudging, [occurrence(eight, .nudging)])

        #expect(SenderNoticeEvent(held: held, arriving: record(.paused, [occurrence(eight, .nudging)])) == nil)
        #expect(SenderNoticeEvent(held: held, arriving: record(.comingUp, [occurrence(eight, .skipped)])) == nil)
        #expect(SenderNoticeEvent(held: held, arriving: record(.nudging, [occurrence(eight, .nudging), occurrence(nextDay, .comingUp)])) == nil)
    }

    /// Before the first report, after status sharing was turned off and on, and while "Don't share this
    /// one" held it back, the report is the baseline: showing the current status isn't news.
    @Test func withNothingHeldTheReportIsTheBaseline() {
        let done = record(.comingUp, [occurrence(eight, .done), occurrence(nextDay, .missed)])

        #expect(SenderNoticeEvent(held: nil, arriving: done) == nil)
        #expect(SenderNoticeEvent(held: .heldBackRecord, arriving: done) == nil)
    }

    @Test func aRecordHeldBackOrDeletedIsNoNews() {
        let held = record(.nudging, [occurrence(eight, .nudging)])

        #expect(SenderNoticeEvent(held: held, arriving: nil) == nil)
        #expect(SenderNoticeEvent(held: held, arriving: .heldBackRecord) == nil)
    }

    @Test func severalNewlyClosedOccurrencesAreOneNoticeForTheLatest() {
        let held = record(.nudging, [occurrence(eight, .nudging)])
        let arriving = record(.comingUp, [occurrence(eight, .missed), occurrence(nextDay, .missed), occurrence(dayAfter, .done)])

        #expect(SenderNoticeEvent(held: held, arriving: arriving) == SenderNoticeEvent(kind: .done, occurrence: dayAfter))
    }

    /// A one-off whose occurrence is older than the report's days has none in the report: its label tells.
    @Test func aOneOffClosedOutsideTheReportsDaysIsReadFromItsLabel() {
        #expect(SenderNoticeEvent(held: record(.nudging), arriving: record(.missed)) == SenderNoticeEvent(kind: .missed, occurrence: nil))
        #expect(SenderNoticeEvent(held: record(.nudging), arriving: record(.done)) == SenderNoticeEvent(kind: .done, occurrence: nil))
        #expect(SenderNoticeEvent(held: record(.done), arriving: record(.done)) == nil)
    }
}

extension SentCopy.StatusRecord {
    /// What the record mapping reads for "Don't share this one": only the flag.
    static let heldBackRecord = SentCopy.StatusRecord(report: StatusReport(label: .comingUp, occurrences: []), notSharingThisOne: true)
}
