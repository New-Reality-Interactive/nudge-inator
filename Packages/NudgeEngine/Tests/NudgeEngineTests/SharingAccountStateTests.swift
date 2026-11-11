import Foundation
import Testing
import NudgeEngine

/// The iCloud account state as the sharing adapter reports it, and what it means for sharing
/// (spec #127, Offline and iCloud): the screens read the reach, as the permission banners read
/// `Engine.reach`, so each says what sharing does and not what the account is.
struct SharingAccountStateTests {
    @Test func anAvailableAccountLetsSharingWork() {
        #expect(SharingAccountState.available.reach == .working)
    }

    @Test(arguments: [
        (SharingAccountState.noAccount, SharingReach.Pause.noAccount),
        (.restricted, .restricted),
        (.temporarilyUnavailable, .temporarilyUnavailable),
    ])
    func everyOtherStatePausesSharingForItsOwnReason(state: SharingAccountState, pause: SharingReach.Pause) {
        #expect(state.reach == .paused(pause))
    }
}
