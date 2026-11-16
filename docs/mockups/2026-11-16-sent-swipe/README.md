# Nudge-inator iOS mockup: Swipe to Edit on Sent

The change mockup for swiping a Sent row to Edit or Delete (#429, spec #127, version 1.4.0). Copied
from the [How Sharing Works tutorial mockup](../2026-11-15-sharing-tutorial/README.md), the latest of
the feature's change mockups, so everything that mockup shows is here too. It's deleted when the
1.4.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser. Swipe a row left with the mouse, or use the controls
panel's **Swipe to Edit (#429)** section. Light and dark come from iPhone settings' Appearance,
portrait and landscape from the iPhone section's Orientation, and the largest text size from Text
Size.

## What changed since the How Sharing Works tutorial mockup

- **A Sent row swipes.** Swiping left shows **Edit** (blue, `pencil`) at the edge and **Delete**
  (red, `trash`) beside it, the same tiles, size and order as a tag's swipe on the Tags tab. There's
  no full swipe: a long swipe stops at the tiles. Nothing is on the leading edge.
  - **Edit** opens the sent reminder's edit form, as the page's Edit does.
  - **Delete** asks the page's confirmation first, **Delete “<title>”?** with "It's canceled on
    everyone's iPhone, with a note saying so." and **Delete Reminder**. Nothing is deleted until
    it's confirmed.
  - Tapping the row still opens the sent reminder's page.
  - With VoiceOver on, Edit and Delete are the row's actions and the tiles aren't offered.
- **Mine's own rows add Edit, for the developer to decide.** A row of the person's own swipes to
  **Delete**, **Edit** and, while Nudging, **Done** at the edge. Edit opens the reminder's form, as
  its page's Edit does. A received copy keeps **Remove** only, because its sender owns what it
  says. The panel's **Mine without Edit (as today)** draws Mine's swipe as it was, to compare.
- Done isn't on Sent: a sent reminder doesn't nudge the sender, and the recipient owns Done.
