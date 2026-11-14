import Testing
@testable import NudgeEngine

/// Which ways an invite can go out for the address it is for (spec #127, Invite; #217's mockup).
struct InviteRouteTests {
    @Test(arguments: ["casey.morgan@icloud.com", "  Casey@iCloud.com ", "a@b.co"])
    func anEmailAddressIsAnEmail(_ address: String) {
        #expect(InviteAddressKind(address: address) == .email)
    }

    @Test(arguments: ["+1 (555) 010-0134", "5550100134", "555-0100"])
    func aPhoneNumberIsAPhone(_ address: String) {
        #expect(InviteAddressKind(address: address) == .phone)
    }

    @Test(arguments: ["", "  ", "casey", "casey@", "@icloud.com", "casey@icloud", "555", "12-34"])
    func anythingElseIsNeitherYet(_ address: String) {
        #expect(InviteAddressKind(address: address) == nil)
    }

    @Test func anEmailCanBeMailedOrItsLinkCopied() {
        #expect(InviteAddressKind.email.routes == [.mail, .copyLink])
        #expect(InviteAddressKind.email.naturalRoute == .mail)
    }

    @Test func aPhoneNumberCanBeTextedOrItsLinkCopied() {
        #expect(InviteAddressKind.phone.routes == [.messages, .copyLink])
        #expect(InviteAddressKind.phone.naturalRoute == .messages)
    }

    @Test func aPickThatFitsIsKept() {
        #expect(InviteAddressKind.email.route(preferring: .copyLink) == .copyLink)
        #expect(InviteAddressKind.phone.route(preferring: .copyLink) == .copyLink)
        #expect(InviteAddressKind.phone.route(preferring: .messages) == .messages)
    }

    @Test func aPickThatNoLongerFitsReturnsToTheNaturalRoute() {
        #expect(InviteAddressKind.phone.route(preferring: .mail) == .messages)
        #expect(InviteAddressKind.email.route(preferring: .messages) == .mail)
    }

    @Test func noPickGivesTheNaturalRoute() {
        #expect(InviteAddressKind.email.route(preferring: nil) == .mail)
        #expect(InviteAddressKind.phone.route(preferring: nil) == .messages)
    }
}
