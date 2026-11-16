import CloudKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The sample covers the whole schema, so the device check can't leave a type or field out.
struct DevelopmentSchemaSampleTests {
    let zoneID = CKRecordZone.ID(zoneName: UUID().uuidString, ownerName: CKCurrentUserDefaultName)

    @Test func theSampleHasEveryRecordType() throws {
        let types = Set(try DevelopmentSchemaSample.records(in: zoneID).map(\.recordType))

        #expect(types == Set(SharingRecordMapping.recordTypeNames))
    }

    @Test func theSampleSetsEveryField() throws {
        let fields = try DevelopmentSchemaSample.records(in: zoneID).reduce(into: Set<String>()) {
            $0.formUnion(DevelopmentSchemaSample.fields(of: $1))
        }

        #expect(fields == Set(SharingRecordMapping.fieldNames))
    }
}
