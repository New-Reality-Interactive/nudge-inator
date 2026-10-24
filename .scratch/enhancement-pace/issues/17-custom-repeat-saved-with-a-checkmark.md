# 17: The Custom page saves with a checkmark, and Back changes nothing

**What to build:** The Custom repeat page gets a checkmark in the top-right corner that saves its choices as the reminder's repeat and goes back to the Repeat page with Custom checked. Back goes back without changing anything.

**Blocked by:** 16.

**Status:** needs-triage

Found by Brian on his iPhone (iPhone 15, iOS 27.0.1), 2026-10-23, during ticket 13's follow-up device check. Brian asked for this ticket and chose the behavior.

## The bug

On a reminder that repeats Never, Repeat → Custom shows "Weekly, every week, on [today], ends Never". If that's the repeat the person wants, they have no way to choose it: Back leaves the repeat at Never. Changing any control, then going back, does make it Custom.

`ReminderForm.customChoices` (`App/ReminderForm/ReminderForm.swift`) shows the choices that match the current repeat, and stores them only when a control changes. That was first-version ticket 27's fix, after just looking at the page marked the repeat Custom. For a preset this is harmless, since what the page shows is the preset's own schedule. For Never, the page shows a schedule the reminder doesn't have.

## What it should do

Brian's choice (option "d"):

- [ ] The Custom page has a checkmark button in the top-right corner. Tapping it saves the page's choices as the repeat and returns to the Repeat page, where Custom is checked with its summary. This works even when no control was changed, so from Never the shown weekly repeat can be chosen as it is.
- [ ] Back returns to the Repeat page and changes nothing: choices changed on the page are dropped, and the repeat stays as it was.
- [ ] Opening Custom on a reminder that already repeats Custom shows its saved choices.
- [ ] Just opening and leaving the page still doesn't mark the repeat Custom (ticket 27).
- [ ] The checkmark meets `docs/design/DESIGN.md` and matches the form's own Save checkmark. VoiceOver reads a label for it.

## Before you start

- Builds on: `CustomRepeatPage` edits the form as the person goes ("so Back keeps it", its doc comment). It needs to edit a copy of the choices, written to the form only by the checkmark.
- When the reminder starts nudging while the page is open, lock the checkmark as ticket 16 locks the page's other controls.
- To decide: whether `hasChanges` (Cancel's confirmation) needs anything, since nothing reaches the form until the checkmark is tapped.
- Check the mockup under `docs/mockups/` for the Custom page's toolbar before building.

## Comments
