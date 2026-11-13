import CloudKit
import Foundation
import NudgeEngine

/// Where the account is read from, so a test gives it any answer without iCloud (#215). The real
/// one is `CKContainer`.
protocol CloudKitAccountSource: Sendable {
    func accountStatus() async throws -> CKAccountStatus
    /// iCloud's name for the signed-in Apple Account's user record: the `AppleAccountID`.
    func userRecordName() async throws -> String
}

extension CKContainer: CloudKitAccountSource {
    func userRecordName() async throws -> String {
        try await userRecordID().recordName
    }
}

/// Reads the iCloud account as `SharingAccount`, from `CKContainer.accountStatus` (#215). Async,
/// so it never holds up the main actor; a request to iCloud happens only when `read()` is called.
struct CloudKitAccountReader: Sendable {
    let source: any CloudKitAccountSource

    func read() async -> SharingAccount {
        let status: CKAccountStatus
        do {
            status = try await source.accountStatus()
        } catch {
            return SharingAccount(state: .temporarilyUnavailable, id: nil)
        }
        let state = Self.state(for: status)
        guard state == .available else { return SharingAccount(state: state, id: nil) }
        // The ID is how the model tells a different Apple Account from the same one signing in
        // again. Without it the account still works, and `nil` changes nothing (#212).
        let name = try? await source.userRecordName()
        return SharingAccount(state: .available, id: name.map(AppleAccountID.init))
    }

    static func state(for status: CKAccountStatus) -> SharingAccountState {
        switch status {
        case .available: .available
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .couldNotDetermine, .temporarilyUnavailable: .temporarilyUnavailable
        @unknown default: .temporarilyUnavailable
        }
    }
}
