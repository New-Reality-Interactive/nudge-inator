# Nudge-inator iOS mockup: Custom Sheet

The change mockup for #284: the [End Repeat mockup](../2026-11-07-end-repeat/README.md) with the
**Custom repeat page as a sheet over the reminder form**, as in Apple's Reminders on iOS 27 (spec
#104). Once Brian signs it off on #284, the ticket is checked against it. The release's `1.3.0`
mockup takes it in and deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The
New Reminder form (the + button), with Repeat set to Custom and the Custom row tapped, reaches every
state below.

## What changed since the End Repeat mockup

- **The Custom row opens a sheet**, not a pushed page. The form steps back under it.
- **Each change on the sheet is the form's repeat as it's made.** The Custom row and the footer under
  the section show it once the sheet closes. The form still holds it until its own Save.
- **Apply (✓) is the sheet's only button.** It closes the sheet, and it's never disabled, so the
  sheet can always close. There's no Back and no Cancel.
- **A swipe down closes the sheet too, and keeps the changes.** In the mockup, drag its bar or grabber
  down, or press Escape.
- **Nothing on the sheet asks a question.** The form's Cancel asks "Are you sure you want to discard
  these changes?" when the repeat, or anything else, changed.
- **While nudging** the sheet shows the lock note at the top, as the form does.

The developer chose to follow Apple's app here, though the HIG's Sheets page pairs Done with Cancel
and avoids a sheet over a sheet (#284's comments record it).
