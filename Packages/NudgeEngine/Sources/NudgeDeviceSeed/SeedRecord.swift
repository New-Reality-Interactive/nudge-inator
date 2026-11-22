#if DEBUG
import Foundation

/// What the seed made, kept between the launch that loads and the launch that removes. Removal
/// reads this and nothing else, so it acts only on what the seed made, found by its own
/// identifiers.
public struct SeedRecord: Codable, Equatable, Sendable {
    public struct Loaded: Codable, Equatable, Sendable {
        public var reminderIDs: [UUID] = []
        /// Only tags the seed created. A tag the person already had is never listed here.
        public var createdTagIDs: [UUID] = []
        /// Each changed setting's value before the first load, by `SeedSetting.rawValue`.
        public var earlierSettings: [String: String] = [:]
        /// When the set's quiet span was added (#369), which is how removal finds it. Optional, so
        /// a record written before it still reads.
        public var quietSpanAddedAt: Date?

        public init(reminderIDs: [UUID] = [], createdTagIDs: [UUID] = [], earlierSettings: [String: String] = [:], quietSpanAddedAt: Date? = nil) {
            self.reminderIDs = reminderIDs
            self.createdTagIDs = createdTagIDs
            self.earlierSettings = earlierSettings
            self.quietSpanAddedAt = quietSpanAddedAt
        }
    }

    /// By set name.
    public var sets: [String: Loaded] = [:]

    public init() {}
}

/// Where the record lives between launches.
public protocol SeedRecordStore {
    func read() -> SeedRecord
    func write(_ record: SeedRecord)
}
#endif
