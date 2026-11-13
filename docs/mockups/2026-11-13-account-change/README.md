# Nudge-inator iOS mockup: Apple Account changed

The change mockup for the note shown when a different Apple Account signs in on the iPhone (#212,
spec #127, decision A13, version 1.4.0), copied from the
[history-nothing-due mockup](../2026-11-12-history-nothing-due/README.md), the latest of the
feature's change mockups. It's deleted when the 1.4.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser, then the controls' Sharing › "A different Apple
Account signs in".

## What changed since the history-nothing-due mockup

- **Apple Account Changed**, a sheet over whatever screen is up, shown once when this iPhone is
  signed in to a different Apple Account than the one its sharing was made with. Like Connection
  Ended it has no Cancel; unlike it there is no choice to make, so it has one prominent OK, and a
  swipe down closes it too. It says sharing stopped, and lists under "Removed from This iPhone"
  what went, leaving out a row with nothing in it:
  - the received reminders, by count and sender, whose nudges and alarms are canceled;
  - the connections, invites not yet accepted among them;

  Names are whole ("Maya Torres and Sam Okafor"), as the app keeps them: it has no first name of
  its own, and Connection Ended names the person in full too. The senders and connections are
  listed in Connections' order, as the locale writes a list ("Maya Torres, Sam Okafor, and Jordan
  Lee" in US English), which is how Foundation's list formatter writes it in the app.
  - the reminders this person sent, so Sent starts empty.

  Its footer says personal reminders haven't changed, and that inviting again is in Settings ›
  Connections. With nothing shared on the iPhone there is no note.
- Signing out alone is unchanged: the iCloud menu's "No iCloud account" pauses sharing and removes
  nothing. Signing back in to the same account resumes it.
- **Every name is whole**, everywhere in the mockup: "From Maya Torres", "Maya Torres owns this
  schedule", "Maya Torres, Last 7 Days", Disconnect from Maya Torres, the sender's notifications
  ("Maya Torres marked it Done") and the rest. The app keeps only whole names (Foundation reads
  "Alex Morgan" as one given name, #194), so the mockup's first-name-only field is gone, and a
  first name can't creep back in.
