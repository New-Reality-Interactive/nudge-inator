import AppIntents
import Foundation
@testable import NudgeShared
import Testing

/// The alarm's Open intent through its one seam: `perform()`, with the opener set by hand. The
/// system resolves the one the app registers only inside its own run of the intent, and the
/// simulator runs no App Intent from an alarm (ticket 02), so that path is a device check.
@MainActor
struct OpenReminderIntentTests {
    @Test func performHandsTheAlarmAndReminderToTheAppsOpener() async throws {
        let opened = OpenedIDs()
        let alarmID = UUID()
        let reminderID = UUID()
        var intent = OpenReminderIntent(alarmID: alarmID, reminderID: reminderID)
        intent.opener = AlarmOpener { alarmID, reminderID in
            await opened.record(alarmID, reminderID)
        }

        _ = try await intent.perform()

        #expect(await opened.ids == [OpenedIDs.Pair(alarmID: alarmID, reminderID: reminderID)])
    }

    /// The app builds both from UUIDs, so this shouldn't happen. If it does, there is no alarm to
    /// stop and no reminder to show, and the intent mustn't crash.
    @Test(arguments: [("not an alarm", UUID().uuidString), (UUID().uuidString, "not a reminder")])
    func performWithAnIDThatIsntAUUIDCallsNothingAndDoesntCrash(alarmID: String, reminderID: String) async throws {
        let opened = OpenedIDs()
        var intent = OpenReminderIntent()
        intent.alarmID = alarmID
        intent.reminderID = reminderID
        intent.opener = AlarmOpener { alarmID, reminderID in
            await opened.record(alarmID, reminderID)
        }

        _ = try await intent.perform()

        #expect(await opened.ids.isEmpty)
    }

    /// AlarmKit's `secondaryIntent` takes only a `LiveActivityIntent`. `.foreground` brings the app
    /// forward, in place of the deprecated `openAppWhenRun`, and hidden from Siri, Spotlight and
    /// Shortcuts, where an alarm's IDs mean nothing.
    @Test func itIsALiveActivityIntentThatOpensTheAppAndIsntOfferedElsewhere() {
        let intent: any LiveActivityIntent = OpenReminderIntent(alarmID: UUID(), reminderID: UUID())

        #expect(type(of: intent).supportedModes == .foreground)
        #expect(type(of: intent).isDiscoverable == false)
    }
}

/// What the opener was handed, across the opener's `Sendable` boundary.
private actor OpenedIDs {
    struct Pair: Equatable {
        var alarmID: UUID
        var reminderID: UUID
    }

    private(set) var ids: [Pair] = []

    func record(_ alarmID: UUID, _ reminderID: UUID) {
        ids.append(Pair(alarmID: alarmID, reminderID: reminderID))
    }
}
