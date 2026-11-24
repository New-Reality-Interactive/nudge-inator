import Foundation
import NudgeEngine

/// A moment's day and time as the engine words them ("Today", "7:58 AM"), for the Sharing pages
/// that say when something happened. With no engine (previews), Foundation's short date and time.
enum EngineDayAndTime {
    static func day(of date: Date, in engine: Engine?) -> LocalizedStringResource {
        engine?.dayLabel(of: date) ?? .alone(date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
    }

    static func time(of date: Date, in engine: Engine?) -> LocalizedStringResource {
        engine?.timeOfDay(of: date) ?? .alone(date, format: Date.FormatStyle(date: .omitted, time: .shortened))
    }
}
