import Foundation

/// A way an invite's link goes out (spec #127, Invite; #217's mockup).
public enum InviteRoute: CaseIterable, Equatable, Sendable {
    /// iOS's message screen, prefilled with the person and the link.
    case messages
    /// iOS's mail screen, prefilled the same way.
    case mail
    /// The link on the clipboard, for the person to send anywhere.
    case copyLink
}

/// What the address an invite is for turns out to be, which decides the ways the invite can go out:
/// an email address can be mailed and a phone number texted, and the link of either can be copied.
public enum InviteAddressKind: Equatable, Sendable {
    case email
    case phone

    /// The kind of `address` as typed or chosen, or `nil` while it is neither yet: an email address
    /// needs something before and a dot after its @, and a phone number at least seven digits.
    public init?(address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") {
            let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty, let dot = parts[1].firstIndex(of: "."),
                  dot != parts[1].startIndex, parts[1].index(after: dot) != parts[1].endIndex else { return nil }
            self = .email
        } else if trimmed.filter(\.isNumber).count >= 7 {
            self = .phone
        } else {
            return nil
        }
    }

    /// The ways an invite to this kind of address can go out, the natural one first.
    public var routes: [InviteRoute] {
        switch self {
        case .email: [.mail, .copyLink]
        case .phone: [.messages, .copyLink]
        }
    }

    /// The way chosen for the person until they pick another: Mail for an email address, Messages
    /// for a phone number.
    public var naturalRoute: InviteRoute { routes[0] }

    /// The route to use given what the person last picked: that, while it still fits this address,
    /// else the natural one.
    public func route(preferring pick: InviteRoute?) -> InviteRoute {
        guard let pick, routes.contains(pick) else { return naturalRoute }
        return pick
    }
}
