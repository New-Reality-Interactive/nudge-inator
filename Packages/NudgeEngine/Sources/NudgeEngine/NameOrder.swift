import Foundation

/// The order names are listed in, on the Tags tab, in the form's tag chooser and for Sent's people:
/// the person's locale's, so a name starting with an accented or non-Latin letter sits where a
/// reader of their language expects, with the numbers inside a name in natural order ("Tag 2" before
/// "Tag 10"). Case plays no part. Names this order calls equal (such as "Ana" and "ana") go to the
/// smaller ID, so a list never shuffles.
///
/// The locale is a parameter, so a test names one and doesn't depend on the device's language.
public struct NameOrder: Equatable, Sendable {
    public var locale: Locale

    /// The person's own locale unless told otherwise.
    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public func compare(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: [.caseInsensitive, .numeric], range: nil, locale: locale)
    }

    /// Whether `a` is listed before `b`, an equal name going to the smaller ID.
    public func isOrdered(_ a: String, _ aID: UUID, before b: String, _ bID: UUID) -> Bool {
        switch compare(a, b) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: aID.uuidString < bID.uuidString
        }
    }
}
