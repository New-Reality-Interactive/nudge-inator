# Nudge-inator iOS mockup: Custom invite screen

A proposal for #217's invite flow, copied from the
[Delete All Data mockup](../2026-11-13-delete-all-data-sharing/README.md), the latest of the
feature's change mockups. It is not built: it shows what the app could draw itself instead of
`UICloudSharingController`'s screens, for the developer to compare. It is deleted if not taken in.

Open [`index.html`](index.html) in a browser, then Settings › Connections › Invite Someone (Invite Again too).

## What changed since the Delete All Data mockup

- **Invite Someone** is one screen the app draws itself, in place of the "Invite One Person" hint and
  `UICloudSharingController`'s screens (#217 uses those today). Top to bottom:
  - **Who to Invite**, a label with the email or phone field beneath it (placeholder "Email or phone"); the hint's advice
    ("use the email address or phone number of their Apple Account, or the invite won't open for
    them") is its footer.
  - **A chosen contact becomes a name pill in the field**, as in Messages: "Casey Morgan" with a ✕
    to remove it (back to typing). The pill replaces the typed address, and the footer then reads
    "The invite opens only for Casey Morgan at casey.morgan@icloud.com." An address typed by hand has no name, so
    it stays in the field as text. In the app the pill is a view holding the name and the address.
  - **Matches as you type**: under the field, the contacts whose name or address matches the text
    typed, each with its address and an **Allow** action. In the app this is the system's contact
    access button, which takes the typed text, shows the matching contact (or a short list when
    several match) and, on a tap, shares just that contact with the app, which then reads its email
    address or phone number and fills the field. The first tap asks for limited Contacts access.
    A stand-in here: iOS draws that button.
  - A **+** in a circle at the field's right end opens iOS's own contact picker (a stand-in here)
    and fills the field with the one email address or phone number picked. The picker needs no
    Contacts permission: the app receives only the chosen address. Casey Morgan and Maya Torres
    have an email, Jordan Lee a phone number.
  - **Send With** appears once there is a person (a chosen contact, or a typed email address or
    phone number), and lists only the ways that fit the address: an email address gives Mail
    (selected) and Copy Link, a phone number gives Messages (selected) and Copy Link. Before there is
    a person the section isn't shown. The person can switch to Copy Link, which is kept while the
    address changes; a selection that stops fitting returns to the natural one for the new address.
    Mail is also listed only when the device can send mail (`canSendMail`), and Messages only when
    it can send texts (`canSendText`).
  - **Invite** is dimmed until there is a person (a contact, or a typed email address or phone
    number). The way to send is then already selected.
  - On tapping **Invite**: Messages and Mail open iOS's own compose screen over this one (a stand-in here), with
    the person and the invite link filled in; the person taps Send there, because an app can't send a
    message itself. Copy Link copies the link and shows "Link copied". Canceling the compose screen
    leaves this screen as it is; the X closes it and nothing was added or sent.
  - One person per invite (spec #127, A6). In the app the person is added to the share only when
    the link is sent.
- **Invite Again**, from an invited person's page, opens the same sheet titled "Invite Again" with the
  person locked: their name pill has no ✕, there is no plus and no typing, because it's the same
  person and only the way to send is left to choose. Sending makes a new invite and the old link stops
  working (the person is listed once).
- **Already Invited.** Inviting someone who is already under Invited asks first: "You've already
  invited Casey Morgan. Inviting again sends a new invite, and the earlier one stops working." with
  **Invite Again** and Cancel. Invite Again replaces that invite, so the person is listed once, as the
  app does today. Someone already Connected still gets "Already Connected".
- Everything else, the Invited row and its page included, is unchanged.
