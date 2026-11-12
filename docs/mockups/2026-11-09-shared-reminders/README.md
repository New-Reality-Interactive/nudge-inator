# Nudge-inator iOS mockup: shared reminders

The change mockup for `shared-reminders` (ticket #183, spec #127, version 1.4.0), copied from the
[1.3.0 mockup](../1.3.0/README.md). Brian approved it on 2026-11-09 (#183's Comments), and it's the
screen layout the feature's UI tickets are checked against. It's deleted when the 1.4.0 version
mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
new **Shared reminders (#183)** group reaches what tapping can't: the recipient's and the other
person's side, iCloud and offline states, and the notifications.

## What changed since 1.3.0

- **Settings › Connections:** a Sharing section with a Connections row. The page has an empty state
  with Invite Someone, then Connected and Invited rows.
- **A connection's page:** Status Sharing, Delivery Mode (Start right away or Ask me first), what the
  other person chose, and Disconnect.
- **An invited person's page:** when it was sent and to whom, "Didn't open for them?", Invite Again
  and Cancel Invite. iCloud doesn't tell the sender an invite failed, so the help is on every invited
  person's page, and on the row once the invite is 2 days old.
- **The invite:** a hint to use their Apple Account, a stand-in for the system's sharing sheet, an
  "Already Connected" alert, and the invite accepted on the recipient's side.
- **Disconnect:** a sheet choosing Remove (the default) or Keep as My Own Reminders. The other person
  gets the same choice in a "Connection Ended" sheet.
- **The reminder form:** a Send To row and page, with Invite Someone New. With someone chosen the
  form has no Tags row, because a sent reminder has no tags. A received reminder's form leaves only
  its tags editable and says the sender owns the rest.
- **Received reminders** on Now, My Day and the Reminders tab, labeled "From <name>" with their
  strength. Details say what the recipient can and can't do, and have "Don't share this one".
- **Waiting to be accepted:** a "Waiting for You" section on Now, between Nudging and Coming Up, with
  Accept and Remove. It doesn't count toward the Now badge.
- **The notes:** what changed, and Canceled, on a received reminder.
- **Reminders tab, Mine | Sent:** Sent is grouped by person, with each copy's status and a repeating
  reminder's 7-day history, and two empty states.
- **Sent's tools** (Brian's change at sign-off, replacing the spec's "no filters or search on Sent"):
  Mine's search, a Filter sheet (People, Status, Strength, Due Date) and Sort, which orders the
  reminders inside each person's group. Sent has no tags.
- **From others** in the Reminders and My Day filter sheets.
- **iCloud and offline:** messages on Connections, Send To and Sent, and "Waiting to sync".
- **Notifications:** the arrival, what changed, and the sender's Done, Removed and Missed.
- **Settings' footer and Delete All Data's wording** now say what's true with sharing.
- `scripts/mockup-shots.py` has the screens these add.

Nothing else changed.

## Known differences to build differently

- **Manage People** here pushes Connections onto the Reminders tab. The spec's link goes to Settings ›
  Connections, and the app follows the spec.
- **A waiting copy under status sharing off** shows "Waiting for them to accept", not "Not sharing
  status": the sender needs to know it hasn't started.

## Changed after sign-off

- **Mine | Sent sits under the search field** (#201, Brian's call at its phone check, 2026-11-12). iOS
  draws the search field in the navigation bar, so the control, in the content, comes below it; this
  mockup was changed to match. With no reminders, Mine has no search field, so the control is under the
  title.

## Checked

Rendered in headless Chrome in portrait, landscape and a large text size, and the invite, send,
accept, remove, disconnect, filter, sort and reset paths were run. The system's sharing sheet is a
stand-in: its layout is Apple's, and what a recipient sees for a mismatched invite is a two-account
device check.

## Publishing it as an artifact

The artifact viewer pads the page by the phone's safe-area insets. The published copy adds this
before `</style>`, or the tab bar is off screen in the Claude iPhone app. It isn't in this file,
because a plain browser adds no such padding.

```css
@media (max-width: 760px) {
  .device, .device[data-cut] { height: calc(100dvh - env(safe-area-inset-top, 0px) - env(safe-area-inset-bottom, 0px)); }
}
```
