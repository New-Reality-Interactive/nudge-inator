import Foundation
@testable import NudgeInator

extension LocalizedStringResource {
    /// The words in US English, as SwiftUI draws them on an English iPhone, whatever the Mac's or
    /// the simulator's language (CODING_STANDARDS.md, Localization).
    var english: String {
        var resource = self
        resource.locale = Locale(identifier: "en_US")
        return String(localized: resource)
    }
}

extension ReminderDetails.Next {
    /// The next due time's day and time in US English, or `nil` while paused or with none.
    var english: [String]? {
        if case let .at(day, time) = self { [day.english, time.english] } else { nil }
    }
}
