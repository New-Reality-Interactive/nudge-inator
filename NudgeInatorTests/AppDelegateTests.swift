import Testing
@testable import NudgeInator

/// The scene delegate that receives an iCloud invite (#217) finds the app's model through the
/// app delegate. SwiftUI's `UIApplication.shared.delegate` is its own wrapper, not our class, so
/// the app delegate has to say where it is itself.
@MainActor
struct AppDelegateTests {
    @Test func theAppDelegateIsFoundWithoutAskingUIApplication() {
        let delegate = AppDelegate()

        #expect(AppDelegate.current === delegate)
    }
}
