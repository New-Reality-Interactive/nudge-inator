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

- [x] The Custom page has a checkmark button in the top-right corner. Tapping it saves the page's choices as the repeat and returns to the Repeat page, where Custom is checked with its summary. This works even when no control was changed, so from Never the shown weekly repeat can be chosen as it is.
- [ ] Back returns to the Repeat page and changes nothing: choices changed on the page are dropped, and the repeat stays as it was.
- [x] Opening Custom on a reminder that already repeats Custom shows its saved choices.
- [x] Just opening and leaving the page still doesn't mark the repeat Custom (ticket 27).
- [ ] The checkmark meets `docs/design/DESIGN.md` and matches the form's own Save checkmark. VoiceOver reads a label for it.

## Before you start

- Builds on: `CustomRepeatPage` edits the form as the person goes ("so Back keeps it", its doc comment). It needs to edit a copy of the choices, written to the form only by the checkmark.
- When the reminder starts nudging while the page is open, lock the checkmark as ticket 16 locks the page's other controls.
- To decide: whether `hasChanges` (Cancel's confirmation) needs anything, since nothing reaches the form until the checkmark is tapped.
- Check the mockup under `docs/mockups/` for the Custom page's toolbar before building. Mockups are frozen: if the checkmark isn't in one, it gets a new dated mockup first.
- Also builds on ticket 16 (Comments): each control on the Custom page takes the lock itself (`SegmentedChoiceSection`, `LockableStepper`, `LockableLabel`), and a locked row that is a link becomes plain, with no chevron (`RepeatPage`'s Custom row), so a disabled link doesn't fade its title. The page ticks a `minute` on its `Form` for Next Times. With a copy of the choices, Next Times and the summary should show the copy. `testCustomLocking` and the `customLocking` harness scenario shoot the page as it locks. Its walk only scrolls down: a drag down at the top of the sheet closes it.
- Watch for: a SwiftUI environment value read inside a toolbar isn't the screen's (ticket 19), so read the lock and Dynamic Type outside the toolbar and pass them in.
- Developer stops:
  - `tdd` seams to agree: the copy of the choices (opened from the repeat, saved by the checkmark, dropped by Back) is form state that `ReminderForm` tests can reach without a view. Propose the seam before the first test.
  - Approval of the new mockup, if one is needed.
  - Simulator check: the Custom page's checkmark, unlocked and locked, light and dark, default and largest text, on both simulators.
  - Device check on the iPhone: the checkmark's VoiceOver label, and Back dropping changes.

## Comments

### 2026-10-24: built, simulator check; device checks to come

- Mockup: the latest one drew no checkmark, so [2026-10-24-custom-checkmark](../../../docs/mockups/2026-10-24-custom-checkmark/README.md) is new, a copy of the filter-badge mockup changed only for the Custom page. Brian approved it. It also stops checking Custom when its row is tapped, which the app hasn't done since first-version ticket 27.
- Decisions (Brian): the checkmark's label is "Done", as the tag sheet's is. `hasChanges` counts the page's unsaved choices, so a swipe down on the Custom page is blocked; Back still drops them. The checkmark is disabled while the choices can't be saved (ends before the start, or no times left), as Save is.
- `tdd` seam, agreed: on `ReminderForm`, `customPageChoices` is the page's copy. It reads the repeat's choices until a control changes it (`customPageDraft`). `chooseCustomPageChoices()` is the checkmark, `closeCustomPage()` is Back (the page's `onDisappear`, which comes after the checkmark has already chosen). The summary, Next Times, the monthly note and day, and `customPageBlock` read the copy. `customChoices` is gone, and the tests that set it now tap the checkmark. The Back, `hasChanges` and lock tests were written after the code, so each was checked by breaking the code it covers: all three failed.
- A lock arriving drops the copy too (`checkLock()`), as ticket 27's ruling drops a locked field's changes. The checkmark takes the lock with `lockedWhileNudging`, so VoiceOver reads the reason, as the page's other controls do. The lock is read in `body` and passed to the toolbar (ticket 19).
- DESIGN.md: "Fill sparingly" and the accent's list now name the Custom page's filled checkmark, which takes the sheet's confirm button's place on that page.
- Review: no hard violations. Fixed: the missing lock hint on the checkmark, `customPageBlock` read twice per `body`, a misleading comment, two names. Left alone: `ReminderForm` growing a cluster of `customPage*` members (moving them into a small type of their own would be a follow-up), and `upcomingDueTimes`, which only tests still call to check the draft's schedule.
- Apple's docs say `dismiss` pops a pushed page. They're silent on whether `onDisappear` fires on a cancelled swipe back or a date picker's popover, so that's a device check.
- Simulator check (`testFormPages`, `testCustomLocking`, both simulators, portrait, landscape and largest text, light and dark): the checkmark is the form's teal glass circle at the top right. From Never, tapping it went back to Repeat with Custom checked and "Every Saturday at 4:00 PM." under it. Locked, it's grey and disabled. Accessibility tree: "Done" button before the lock, "Done", disabled, after it. `scripts/test.sh` passed on both simulators.
- Open: criterion 2 (Back drops the changes, including a cancelled swipe back, and the End Date picker keeps them) and criterion 5's VoiceOver label, on the iPhone.

