import Foundation

extension Date {
    /// "in 5 min.", the mockup's `rel`, for a nudge card's next nudge and a My Day row still to
    /// come. The formatter is built per call: it isn't `Sendable`, so a shared one can't be static.
    func shortRelative(to now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: now)
    }
}
