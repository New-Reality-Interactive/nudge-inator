# Nudge-inator iOS mockup: Sharing switch

The change mockup for the Sharing switch (#386, spec #127, version 1.4.0), the gate for #387, #388 and
#389. Copied from the [Send With icons mockup](../2026-11-14-send-with-icons/README.md), the latest
of the feature's change mockups, so it already has the Sharing footer copy (#213), Delete All Data's
sharing wording (#214) and the invite screen (#217). The Reminders tab with Sharing on is as #328
and #329 built it. It's deleted when the 1.4.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser. The mockup starts with Sharing on and the made-up
connections, as the mockups before it did. The controls panel's **Sharing switch (#386)** section
reaches each state below. Its two starting points keep the tab you're on, so the same screen can be
compared with Sharing off and on. Portrait and landscape come from the iPhone section's Orientation.

## What changed since the Send With icons mockup

- **Settings › Sharing** starts with a **Sharing** switch (share-symbol tile, blue). Its footer reads
  "Connect with people through iCloud to send each other reminders." With the switch on, the
  Connections row is below it, as before. With it off, the section is only the switch and the footer.
  The switch row is new to `docs/design/DESIGN.md` (a blue tile, and a switch where Settings rows
  have a status or a chevron): #387 adds it there when it builds the row.
- **Sharing off** means none of sharing exists: no connections, invites, sent or received reminders.
  - The Reminders tab has no Mine | Sent. It is Mine alone, with its search, Filter and Sort.
  - The Now tab has no Waiting for You section, no "From <name>" labels and no paused-sharing banner.
  - The reminder form has no Send To.
  - The Reminders and My Day filter sheets have no From section.
  - The controls panel's #183 controls say Sharing is off instead of opening their screens.
- **Turning Sharing off while anyone is connected or invited** asks first, in a sheet titled
  **Turn Off Sharing**: "This disconnects you from 2 people and cancels 2 invites. You won't be
  able to send or receive reminders, and your Sent list and its history are deleted." Connections
  and open invites are counted apart, and either part is left out at 0. Below it is Disconnect's
  choice, asked once for everyone under "5 Reminders You've Received": **Remove** (checked) or
  **Keep as My Own Reminders**. The choice isn't shown when nothing has been received. Then the
  footer about everyone getting a note (only while someone is connected), and the **Turn Off
  Sharing** button. The X cancels, and Sharing stays on with nothing changed. The switch stays on
  until the person confirms. Confirming shows "Sharing turned off", as Disconnect shows
  "Disconnected from <name>". With no one connected or invited, the switch turns off at once.
- **Turning Sharing on** starts fresh: Connections shows No Connections, and Sent shows No One to Send To.
- **Opening an invite while Sharing is off** shows an alert titled "Turn on sharing to connect with
  Riley Park?", with the message "Riley Park invited you to send each other reminders through iCloud.
  Sharing is off on this iPhone." The buttons are **Not Now** and **Turn On Sharing**. Turn On
  Sharing turns it on and shows the usual Connected sheet. Not Now leaves Sharing off. With
  Sharing on, the same control shows Connected directly, as the old "Invite accepted" control did.
- **Delete All Data** also turns Sharing off (#388).
