# Nudge-inator iOS mockup: Tag details and the Tags swipe (#376, #377, #378)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[My Day's day buttons mockup](../2026-11-23-my-day-day-buttons/README.md) with a Tag details page
and the Tags tab's changed swipe, and nothing else changed. It is deleted when the 1.6.0 version
mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The Tags tab
is the fourth tab; the controls' "Tag details" group jumps to each state.

## What changed

- **A tag row opens the Tag details page**, pushed on the Tags tab as a reminder's details page is
  from the Reminders tab, with Back to the list (its search, filter and sort as they were). The page
  shows the tag's tile and name, the counts line the row shows (the nudging part in the negative
  color), a Reminders row and a Delete Tag button. Edit is the bar's button, as on a reminder's
  details.
- **The Reminders row opens the tag's reminders page, unchanged.** Back from it returns to the
  details page.
- **Edit opens the Rename Tag sheet**, unchanged; the page shows the new name when it closes.
  **Delete Tag** asks with the existing question, then removes the tag and lands on the list.
- **The swipe on a tag row (right to left) offers three tiles:** Delete, Edit and Reminders (teal, Lagoon's
  #04666B, the Reminders tab's icon) at the edge. Edit opens the Rename Tag sheet, Reminders opens the
  reminders page and Back from it returns to the list, and Delete asks first. VoiceOver's row
  actions are the same three. The developer's call on the first mockup, 2026-11-23: keep Edit on the
  row beside the page's own Edit.
- **A tag deleted while its page is open** shows Tag Deleted ("This tag was deleted. Its reminders
  are still there."), the state the reminders page already has, on both pages.
