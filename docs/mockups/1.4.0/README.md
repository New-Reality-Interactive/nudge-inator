# Nudge-inator iOS mockup: 1.4.0

The app as built at 1.4.0 (`v1.4.0`): the [1.3.0 mockup](../1.3.0/README.md), then `shared-reminders`
(spec #127). Made in the release PR from the feature's 16 change mockups, which form one chain with
three ends: the Last synced mockup (#434), the Sent swipe mockup (#429) and the Custom invite screen
mockup, which the chain had already taken in. The release merged the Sent swipe mockup into the Last
synced one. It takes in and replaces all 16. Frozen.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Shared reminders** group reaches what tapping can't: the other person's side, iCloud and offline
states, and the notifications.

## What changed since 1.3.0

- **Settings › Sharing:** a **Sharing** switch (off means none of sharing exists: no connections,
  invites, Sent, From labels or Send To), **Connections**, **Share Activity** and **How Sharing
  Works**. Turning Sharing off asks first whenever it deletes anything, with Remove or Keep as My
  Own Reminders once for everyone.
- **Connections:** Invite Someone is a screen the app draws itself (who to invite, a contact as a name
  pill, matches as you type, how to send it); invited and connected people's pages; a connection's
  Status Sharing and Delivery Mode, what the other person chose, Disconnect (Remove or Keep as My Own
  Reminders, a filled red button) and the Connection Ended sheet. A quiet connection (no sync for 14 days,
  status sharing on) shows "Last synced on <date>".
- **How Sharing Works:** four swipeable pages (Send Each Other Reminders, Connect, Send a Reminder,
  Who Sees What), which open by themselves the first time Sharing is turned on and replay from
  Settings.
- **Share Activity:** the record of what iCloud refused or lost, newest first.
- **Apple Account Changed:** a sheet saying what left this iPhone, and that the people in the removed
  connections weren't told.
- **Sending:** a **Send To** row and page on the reminder form, with Invite Someone New; a sent
  reminder has no tags.
- **Received reminders** on Now, My Day and the Reminders tab, labeled "From <name>", with their
  strength, a details page that says what the recipient can and can't do, "Don't share this one", and
  the "what changed" and "canceled" notes. **Ask me first** copies wait in a "Waiting for You" section
  with Accept and Remove.
- **Reminders tab, Mine | Sent:** Sent is grouped by person, with each copy's status and a repeating
  reminder's 7-day history (Done, Missed, Skipped, Coming up and "nothing due" each have their own
  glyph), search, Filter, Sort, and a swipe to Edit or Delete. Mine's rows swipe to Edit too.
- **From others** in the Reminders and My Day filter sheets; the filter sheets' Apply is a checkmark.
- **iCloud and offline:** messages on Connections, Send To and Sent, and "Waiting to sync".
- **Notifications:** the arrival, what changed, and the sender's Done, Removed and Missed.
- **Wording:** Settings' footer, Onboarding and How It Nudges say what's true with sharing, and Delete
  All Data says it also disconnects everyone and deletes what was sent and received. No action shows a
  success message.
- Every name is whole, everywhere ("From Maya Torres").
- `scripts/mockup-shots.py` has the screens these add.

Nothing else changed.

## Checked against the app

Before release, the screens this feature adds were compared with the app (`docs/agents/release.md`,
the drift check): the app's screenshots from the screenshots harness's sharing walk (the iPhone 15
simulator, iOS 27.2, portrait, with the Debug stand-in's people) beside this mockup's, screen by
screen. `as-built/` holds the app's, as small reference images.

- **Compared, and the same:** Settings › Sharing (on and off), Connections, a connection's page,
  an invited person's page, Disconnect, Turn Off Sharing, Share Activity (and empty), the Sent view (and
  empty, with no connections, and after a swipe and its delete question), a sent reminder's details,
  Filter Sent, a received reminder's details and edit form, the From others filters, Sharing is paused,
  You're offline, Apple Account Changed, and the Now and Reminders tabs with Sharing off.
- **Corrected here:** Invite Someone's Invite button sits at the bottom of the sheet, as the app draws
  it, not under the footer, and a disabled accent row (Invite Someone while sharing is paused) is dimmed. `scripts/mockup-shots.py`'s `invite-sheet` and `invite-already-connected`
  entries clicked something the mockup no longer has.
- **Differences that are data, not design:** the people (Maya Torres and Sam Okafor here, Riley Park in the
  app's stand-in), the dates, and the status strips under a repeating sent reminder, which the stand-in's
  sent reminders don't have.
- **Not compared:** How Sharing Works' pages, the notifications, a copy waiting to be accepted, the
  Last synced note, Send To with iCloud paused, Sent's search, sort menu and no-match states, Connection
  Ended and the accepted-invite sheet. Each was checked on the iPhone against its change mockup when its
  ticket was built.
