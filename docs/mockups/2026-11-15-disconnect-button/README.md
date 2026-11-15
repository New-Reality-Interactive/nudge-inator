# Nudge-inator iOS mockup: Disconnect button

The change mockup for a clearer Disconnect button (#402, spec #127, version 1.4.0). Copied from the
[Share Activity mockup](../2026-11-14-share-activity/README.md), the latest of the feature's change
mockups, so everything that mockup shows is here too. It's deleted when the 1.4.0 version mockup
takes the change in.

Open [`index.html`](index.html) in a browser. The controls panel's **Disconnect button (#402)**
section opens each sheet with the button, and its checkbox draws the button as it was, to compare.
Portrait and landscape come from the iPhone section's Orientation, and the largest text size from
iPhone settings' Text Size.

## What changed since the Share Activity mockup

- **The two sheets that end sharing confirm with a filled red button.** On #217's phone check the
  Disconnect button, red text on a light gray fill, looked disabled. It is now drawn as a prominent
  button in `{colors.negative}`, with the text in the color that prominent buttons use on the accent
  (white, black in Dark Mode), the same size and shape as Connection Ended's Continue:
  - **Disconnect from <name>**'s **Disconnect** (#197).
  - **Turn Off Sharing**'s **Turn Off Sharing** (#388).
  - **Now › Waiting for You**'s small **Remove** (#203), the only other button drawn as red text on
    the gray fill, is filled red too. **Accept** beside it is filled in the accent color, so the
    pair stays even. Both keep their capsule, and fill the width when the row stacks at the
    accessibility text sizes.
- Nothing else on these screens changes: the sheets' title, first line, Remove and Keep as My Own
  Reminders in that order with Remove chosen, note footer and ✕; each button's word and what it
  does. Connection Ended keeps its accent Continue.
- The app's other red actions keep their look: plain red rows in a list (Delete Reminder, Delete All
  Data, a connection's Disconnect, Cancel Invite, Delete Tag) and the buttons in system confirmation
  dialogs.
