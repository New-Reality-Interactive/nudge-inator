# Nudge-inator iOS mockup: How Sharing Works tutorial

The change mockup for a sharing tutorial (spec #127, version 1.4.0). Copied from the
[Disconnect button mockup](../2026-11-15-disconnect-button/README.md), the latest of the feature's
change mockups, so everything that mockup shows is here too. It's deleted when the 1.4.0 version
mockup takes the change in.

Open [`index.html`](index.html) in a browser. The controls panel's **How Sharing Works (tutorial)**
section opens it each way. Portrait and landscape come from the iPhone section's Orientation, and
the largest text size from iPhone settings' Text Size.

## What changed since the Disconnect button mockup

- **A four-page "How Sharing Works" sheet:** Send Each Other Reminders, Connect, Send a Reminder,
  Who Sees What. Continue moves forward and the last page's button is Done. Page dots show where you are.
  Back is top left from page 2 and Close is top right on every page, for consistency. The last
  page therefore shows Close, Back and Done together, which the HIG (Sheets) says to avoid; this
  was chosen on purpose.
- **It opens by itself once:** the first time Sharing is turned on in Settings. Closing it or Done
  ends it, and it doesn't open by itself again (HIG, Onboarding).
- **It can be replayed any time:** a **How Sharing Works** row in Settings › Sharing, shown with
  Sharing on or off, always the section's last row: under Share Activity while Sharing is on, under
  the switch while it's off (the developer moved it there on 2026-11-15, editing this mockup in place).
  It opens a sheet, not a page, so it has no chevron: its title is in the accent color, as Send a
  Test Nudge's is (the HIG keeps the disclosure indicator for drilling into the next level; the
  developer's call at #423's phone check, 2026-11-15, also edited in place).
- **An invite opened while Sharing is off** asks "Turn on sharing to connect with Riley Park?"
  first. Turn On Sharing turns it on and accepts the invite, so this is also the first time: the
  Connected sheet shows, and the tutorial opens when it closes with Done (a sheet closes before the
  next opens). Change These counts as seen, with no tutorial after it.
- Nothing else changes.
