# Nudge-inator iOS mockup: Apple Account Changed says the others weren't told

The change mockup for the Apple Account Changed note's footer (#433, spec #127, version 1.4.0).
Copied from the [tutorial swipe mockup](../2026-11-16-tutorial-swipe-top-bar/README.md), the latest
of the feature's change mockups. It's deleted when the 1.4.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser, then the controls' Sharing › "A different Apple
Account signs in".

## What changed since the tutorial swipe mockup

- **The Apple Account Changed footer**, when the change removed at least one connection, now reads:
  "Your own reminders haven't changed. The people you were connected with haven't been told, so
  they still see you as connected. To share with them again, invite them from Settings ›
  Connections."

  A connection belongs to the Apple Account in iCloud, so a device signed in to another account
  can't end it or tell the other person (#433). With no connection removed, the footer reads as
  before: "Your own reminders haven't changed. To share again, invite people from Settings ›
  Connections."
- Nothing else changes: the title, the first line, the rows under Removed from This iPhone, and OK.
