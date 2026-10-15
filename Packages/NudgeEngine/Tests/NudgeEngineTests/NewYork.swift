import Foundation

/// Test dates as local wall-clock times in New York, which has DST, so no test depends on the
/// Mac's own time zone.
enum NewYork {
    static let timeZone = TimeZone(identifier: "America/New_York")!

    static func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
