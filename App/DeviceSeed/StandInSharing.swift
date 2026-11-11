#if DEBUG
import Foundation
import NudgeEngine
import os
import UIKit

/// Sharing for the phone check of Connections (ticket 194), until the CloudKit adapter (#216) gives
/// the app a real sharing model: a launch with `NUDGE_SHARING_STANDIN=seeded` (a connection and two
/// invites, one 3 days old) or `=empty` gets a stand-in adapter over an in-memory sharing store. A
/// launch without the variable gets no sharing, as the shipped app. Nothing it holds outlives the
/// launch, so a launch without the variable is its cleanup. Debug builds only:
/// `scripts/check-release-has-no-seed.sh` checks Release builds hold none of it.
@MainActor
enum StandInSharing {
    static let variable = "NUDGE_SHARING_STANDIN"

    static func modelIfAsked(clock: any EngineClock, environment: [String: String] = ProcessInfo.processInfo.environment) -> SharingModel? {
        let seed: SharingData
        switch environment[variable] {
        case "seeded": seed = seeded(now: clock.now)
        case "empty": seed = SharingData()
        case .none: return nil
        case .some(let other):
            logger.error("No stand-in sharing called \(other, privacy: .public): use seeded or empty")
            return nil
        }
        var opened: SharingStore?
        return SharingModel(adapter: StandInSharingAdapter(), clock: clock) {
            if let opened { return opened }
            let store = try SharingStore(location: .inMemory)
            try store.save(seed)
            opened = store
            return store
        }
    }

    /// A model for previews: the mockup's people, or with `seeded` false, no one.
    static func previewModel(seeded: Bool = true) -> SharingModel {
        let clock = SystemClock()
        // Launched by `refreshAccountState`, which reads the store, as the app model's launch does.
        let model = modelIfAsked(clock: clock, environment: [variable: seeded ? "seeded" : "empty"])!
        model.refreshAccountState()
        return model
    }

    /// The mockup's people: Riley connected (at riley.park@icloud.com), Jordan invited today and
    /// Priya 3 days ago.
    private static func seeded(now: Date) -> SharingData {
        SharingData(connections: [
            // With an address, so a check can invite it under another name and see "Already Connected".
            SharingConnection(id: UUID(), name: "Riley Park", state: .connected, sharesStatus: true, address: "riley.park@icloud.com"),
            SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited, sharesStatus: true, address: "jordan.lee@icloud.com", invitedAt: now.addingTimeInterval(-20 * 60)),
            SharingConnection(id: UUID(), name: "Priya Shah", state: .invited, sharesStatus: true, address: "+1 (555) 010-4477", invitedAt: now.addingTimeInterval(-3 * 24 * 60 * 60)),
        ])
    }

    fileprivate static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "StandInSharing")
}

/// Stands in for the CloudKit adapter: the sharing sheet is an alert asking for a name and an
/// address, as the mockup's stand-in sheet does, and nothing goes anywhere. Its strings are English
/// only, on purpose: it never ships.
@MainActor
final class StandInSharingAdapter: SharingAdapter {
    weak var events: (any SharingAdapterEvents)?

    func submit(_ change: SharingChange) {
        StandInSharing.logger.notice("Stand-in: not sending a \(String(describing: change.kind), privacy: .public) change")
    }

    func accountState() async -> SharingAccountState {
        .available
    }

    func invite(_ connectionID: UUID) async throws -> InvitedPerson? {
        // `present` reports no failure, and the alert's buttons are what resume the wait, so it
        // presents only where it surely shows: otherwise the invite would wait for good.
        guard let presenter = Self.topViewController(), !presenter.isBeingDismissed, presenter.presentedViewController == nil else {
            StandInSharing.logger.error("Stand-in: nowhere to show the sharing sheet")
            return nil
        }
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: "Add People (stand-in)", message: "iOS draws this sheet with the real adapter.", preferredStyle: .alert)
            alert.addTextField { $0.placeholder = "Name (optional)" }
            alert.addTextField {
                $0.placeholder = "Email or phone"
                $0.keyboardType = .emailAddress
                $0.autocapitalizationType = .none
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in continuation.resume(returning: nil) })
            alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak alert] _ in
                let name = alert?.textFields?[0].text?.trimmingCharacters(in: .whitespaces) ?? ""
                let address = alert?.textFields?[1].text?.trimmingCharacters(in: .whitespaces) ?? ""
                guard !address.isEmpty else { return continuation.resume(returning: nil) }
                continuation.resume(returning: InvitedPerson(name: name.isEmpty ? address : name, address: address))
            })
            presenter.present(alert, animated: true)
        }
    }

    func revokeInvite(_ connectionID: UUID) {
        StandInSharing.logger.notice("Stand-in: revoked an invite")
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
#endif
