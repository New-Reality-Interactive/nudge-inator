import Contacts
import ContactsUI
import NudgeEngine
import SwiftUI

/// The system's contact picker, for Invite Someone's plus (#217). It needs no Contacts permission
/// and the app gets only what the person picks: one email address or phone number of one contact.
struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (InvitedPerson) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Only the two things an invite can go to; the person taps the one that is their Apple Account.
        picker.displayedPropertyKeys = [CNContactEmailAddressesKey, CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0 OR phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ picker: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (InvitedPerson) -> Void

        init(onPick: @escaping (InvitedPerson) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            let address = (contactProperty.value as? String) ?? (contactProperty.value as? CNPhoneNumber)?.stringValue
            guard let address else { return }
            let name = CNContactFormatter.string(from: contactProperty.contact, style: .fullName)
            onPick(InvitedPerson(name: name ?? address, address: address))
        }
    }
}

enum InviteContacts {
    /// The people in the contacts with these identifiers, one per email address and phone number:
    /// what the contact access button shared with the app. Empty if they can't be read.
    nonisolated static func people(withIdentifiers identifiers: [String]) async -> [InvitedPerson] {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]
        let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)
        guard let contacts = try? CNContactStore().unifiedContacts(matching: predicate, keysToFetch: keys) else { return [] }
        return contacts.flatMap { contact in
            let name = CNContactFormatter.string(from: contact, style: .fullName)
            let addresses = contact.emailAddresses.map { String($0.value) } + contact.phoneNumbers.map(\.value.stringValue)
            return addresses.map { InvitedPerson(name: name ?? $0, address: $0) }
        }
    }
}
