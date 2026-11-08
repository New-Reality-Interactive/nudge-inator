# Nudge-inator iOS mockup: End Repeat

The change mockup for #287: the [Repeat menu mockup](../2026-11-07-repeat-menu/README.md) with
**End Repeat** as its own row in the reminder form, for every repeat, as in Apple's Reminders on iOS 27
(spec #104). Once Brian signs it off on #287, the ticket is checked against it. The release's `1.3.0`
mockup takes it in and deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The
New Reminder form (the + button) reaches every state below.

## What changed since the Repeat menu mockup

- **End Repeat** shows under Repeat, and under the Custom row when there is one, whenever Repeat isn't
  Never. It's a pop-up menu of Never, After and On Date, with a checkmark on the current choice. A
  choice is the form's at once, held until the form's own Save.
- **After** adds a row with a stepper, "After 10 times" (2 to 30): how many times the reminder falls due
  before it ends.
- **On Date** adds an End Date row with a date button, which opens a calendar no earlier than the start.
- **Changing the repeat keeps the end.** It goes back to Never only when Repeat becomes Never, which hides
  the row.
- **A preset with an end is still that preset** in the Repeat menu: the preset is the pattern, and the end
  is its own row.
- **The footer** under the section always says the whole repeat, end included ("Every Monday at 9:00 AM,
  10 times."), for Never, the presets and Custom, and while locked. This reverses #283's rule that dropped
  it while the Custom row shows.
- **The Custom row and the Custom page's summary** write the repeat without its end ("Every Monday at
  9:00 AM"): End Repeat and the footer say the end.
- **An end date before the start** disables Save, with "The repeat ends before it starts. Change its end
  date." under Starts.
- **The Custom page has no Ends section.** (#284 turns it into a sheet.)
- **While nudging** End Repeat and its rows are locked, each with the `lock`, beside the lock note.
