import CloudKit
import UIKit
import os

/// Receives the invite a tap opens the app with (#217). SwiftUI apps get a scene delegate only
/// through the app delegate, which names this class in the scene's configuration.
@MainActor
final class SharingSceneDelegate: NSObject, UIWindowSceneDelegate {
    private static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "CloudKit")

    /// The app wasn't running: the invite is in the scene's connection options.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { receive(metadata) }
    }

    /// The app was running.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        receive(cloudKitShareMetadata)
    }

    private func receive(_ metadata: CKShare.Metadata) {
        // Building the model makes the adapter, if this build has one and Sharing is on.
        guard let invite = CloudKitInvites.incomingInvite(from: metadata) else { return }
        guard let model = AppDelegate.current?.model else {
            Self.logger.error("An invite arrived and the app has no model to take it")
            return
        }
        // With Sharing off there's no adapter yet: the model asks first, and hands the invite over
        // once the person has turned Sharing on (#389).
        model.receiveInvite(from: invite.senderName) {
            CloudKitSharingAdapter.current?.receive(metadata)
        }
    }
}
