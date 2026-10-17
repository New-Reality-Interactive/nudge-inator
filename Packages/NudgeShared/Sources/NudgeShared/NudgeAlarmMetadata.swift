import AlarmKit

/// The metadata every nudge alarm carries. Empty: Apple says "the implementation can be empty if
/// you don't want to provide any additional data for your alarm UI", and the alert is title only
/// (Privacy). Shared so the widget extension can decode it if it ever draws alarms.
public struct NudgeAlarmMetadata: AlarmMetadata {
    public init() {}
}
