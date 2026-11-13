import CloudKit
import NudgeEngine
import Testing
@testable import NudgeInator

/// The real adapter's account state (#215), read from a stand-in for `CKContainer`.
struct CloudKitAccountTests {
    final class Source: CloudKitAccountSource, @unchecked Sendable {
        var status: Result<CKAccountStatus, Error> = .success(.available)
        var name: Result<String, Error> = .success("_abc123")
        private(set) var calls = 0

        func accountStatus() async throws -> CKAccountStatus {
            calls += 1
            return try status.get()
        }

        func userRecordName() async throws -> String {
            calls += 1
            return try name.get()
        }
    }

    struct Failure: Error {}

    @Test(arguments: [
        (CKAccountStatus.available, SharingAccountState.available),
        (.noAccount, .noAccount),
        (.restricted, .restricted),
        (.couldNotDetermine, .temporarilyUnavailable),
        (.temporarilyUnavailable, .temporarilyUnavailable),
    ])
    func statusMapsToState(status: CKAccountStatus, state: SharingAccountState) async {
        let source = Source()
        source.status = .success(status)
        let account = await CloudKitAccountReader(source: source).read()
        #expect(account.state == state)
    }

    @Test func availableAccountCarriesItsID() async {
        let account = await CloudKitAccountReader(source: Source()).read()
        #expect(account == SharingAccount(state: .available, id: AppleAccountID("_abc123")))
    }

    @Test func unavailableAccountHasNoIDAndAsksNothingMore() async {
        let source = Source()
        source.status = .success(.noAccount)
        let account = await CloudKitAccountReader(source: source).read()
        #expect(account.id == nil)
        #expect(source.calls == 1)
    }

    @Test func aFailedStatusReadIsTemporarilyUnavailable() async {
        let source = Source()
        source.status = .failure(Failure())
        let account = await CloudKitAccountReader(source: source).read()
        #expect(account == SharingAccount(state: .temporarilyUnavailable, id: nil))
    }

    @Test func aFailedIDReadKeepsTheAccountWorkingWithNoID() async {
        let source = Source()
        source.name = .failure(Failure())
        let account = await CloudKitAccountReader(source: source).read()
        #expect(account == SharingAccount(state: .available, id: nil))
    }

    @MainActor @Test func makingTheAdapterMakesNoRequest() async {
        let source = Source()
        let adapter = CloudKitSharingAdapter(reader: CloudKitAccountReader(source: source))
        adapter.start()
        #expect(source.calls == 0)
        _ = await adapter.signedInAccount()
        #expect(source.calls == 2)
    }
}
