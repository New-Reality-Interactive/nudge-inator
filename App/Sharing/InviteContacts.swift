import Contacts
import ContactsUI
import NudgeEngine
import SwiftUI

/// The system's contact picker, for Invite Someone's plus (#217). It needs no Contacts permission
/// and the app gets only what the person picks: one email address or phone number of one contact.
/// Presented over the screen that is up rather than inside a SwiftUI sheet: the picker dismisses
/// itself on a pick, which closed the Invite sheet with it when it was nested in one.
@MainActor
final class ContactPickerPresenter: NSObject, CNContactPickerDelegate {
    private static var active: ContactPickerPresenter?
    private var finish: ((InvitedPerson?) -> Void)?

    /// Shows the picker and returns the address the person picked, or `nil` if they canceled.
    static func pick() async -> InvitedPerson? {
        guard let presenter = UIViewController.frontmost() else { return nil }
        let delegate = ContactPickerPresenter()
        active = delegate
        return await withCheckedContinuation { (continuation: CheckedContinuation<InvitedPerson?, Never>) in
            delegate.finish = { person in
                active = nil
                continuation.resume(returning: person)
            }
            let picker = CNContactPickerViewController()
            picker.delegate = delegate
            // Only the two things an invite can go to; the person taps the one that is their Apple Account.
            picker.displayedPropertyKeys = [CNContactEmailAddressesKey, CNContactPhoneNumbersKey]
            picker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0 OR phoneNumbers.@count > 0")
            presenter.present(picker, animated: true)
        }
    }

    // The picker calls its delegate on the main thread.
    nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
        // Read here, so only plain values cross into the main actor.
        let address = (contactProperty.value as? String) ?? (contactProperty.value as? CNPhoneNumber)?.stringValue
        let name = CNContactFormatter.string(from: contactProperty.contact, style: .fullName)
        let person = address.map { InvitedPerson(name: name ?? $0, address: $0) }
        MainActor.assumeIsolated { finish?(person) }
    }

    nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        MainActor.assumeIsolated { finish?(nil) }
    }
}

enum InviteContacts {
    /// The people in the contacts the app can already read (all of them under full access, those the
    /// person shared under limited access) whose name matches `query`, one per email address and
    /// phone number, the first few. Empty when the app can't read contacts. The contact access
    /// button covers the contacts the app can't read yet.
    nonisolated static func people(matching query: String) async -> [InvitedPerson] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, [.limited, .authorized].contains(CNContactStore.authorizationStatus(for: .contacts)) else { return [] }
        let predicate = CNContact.predicateForContacts(matchingName: trimmed)
        return Array(fetchPeople(matching: predicate).prefix(5))
    }

    /// The people in the contacts with these identifiers, one per email address and phone number:
    /// what the contact access button shared with the app. Empty if they can't be read.
    nonisolated static func people(withIdentifiers identifiers: [String]) async -> [InvitedPerson] {
        return fetchPeople(matching: CNContact.predicateForContacts(withIdentifiers: identifiers))
    }

    private nonisolated static func fetchPeople(matching predicate: NSPredicate) -> [InvitedPerson] {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]
        guard let contacts = try? CNContactStore().unifiedContacts(matching: predicate, keysToFetch: keys) else { return [] }
        return contacts.flatMap { contact in
            let name = CNContactFormatter.string(from: contact, style: .fullName)
            let addresses = contact.emailAddresses.map { String($0.value) } + contact.phoneNumbers.map(\.value.stringValue)
            return addresses.map { InvitedPerson(name: name ?? $0, address: $0) }
        }
    }
}
