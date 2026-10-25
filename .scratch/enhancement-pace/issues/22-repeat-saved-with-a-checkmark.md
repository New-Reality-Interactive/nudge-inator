# 22: The Repeat page saves with a checkmark, and Back changes nothing

**What to build:** The form's Repeat page gets a checkmark in the top-right corner that saves its choice as the reminder's repeat and goes back to the form. Back goes back without changing anything. The Custom page's checkmark from ticket 17 then saves into the Repeat page's choice, not the form, so only the checkmark on the page being left saves.

**Blocked by:** 17.

**Status:** resolved

Brian asked for this ticket on 2026-10-24, after choosing ticket 17's checkmark for the Custom page.

## The problem

Each row on the Repeat page sets the reminder's repeat as soon as it's tapped (`RepeatPage`'s `CheckmarkRow` action writes `form.repeatPreset`). So Back always keeps whatever was tapped last, and the person can't look at the options and leave without changing the repeat. With ticket 17, the Custom page works the other way: nothing is kept until its checkmark is tapped. The two pages should work the same way.

## What it should do

- [x] The Repeat page has a checkmark button in the top-right corner. Tapping it saves the page's choice as the repeat and returns to the form. Tapped with nothing changed, it leaves the repeat as it was.
- [x] Back returns to the form and changes nothing: a choice made on the page is dropped, and the repeat stays as it was.
- [x] Opening the page shows the reminder's current repeat checked: a preset, Never, or Custom with its summary.
- [x] Only the checkmark on the page being left saves. The Custom page's checkmark writes its choices to the Repeat page's copy, not to the form. It returns to the Repeat page with Custom checked and its summary shown, and nothing reaches the form until the Repeat checkmark is tapped. Back on the Repeat page then drops that custom repeat too. Opening Custom again from the Repeat page shows the copy's choices.
- [x] Cancel's confirmation (`hasChanges`) counts a choice on the Repeat page that hasn't been saved, as ticket 17 counts an unsaved Custom page edit (`customPageEdit`).
- [x] The checkmark meets `docs/design/DESIGN.md` and matches the form's own Save checkmark and the Custom page's checkmark (ticket 17). VoiceOver reads it as "Done", as on the Custom page.
- [x] While the reminder is nudging, the checkmark is locked as the page's rows are (ticket 13: `lockedWhileNudging`, `RepeatLockSection`).

## Before you start

- Changes ticket 17's behavior. In [ticket 17](17-custom-repeat-saved-with-a-checkmark.md), the Custom page's checkmark saves straight to the form. Here it writes to the Repeat page's copy instead, and only the Repeat checkmark reaches the form.
- Builds on: ticket 17 (Comments, "built, simulator check"). On `ReminderForm`, `customPageChoices` is the Custom page's copy (stored as `customPageDraft`, which criterion 5 still calls `customPageEdit`, its name before review). It reads the repeat's choices (`repeatChoices`) until a control changes it. `chooseCustomPageChoices()` is its checkmark, and `closeCustomPage()` is its Back. `hasChanges` counts the copy while it differs from `repeatChoices`. `checkLock()` drops it when `.repeatRule` locks. `customPageBlock` disables the checkmark. Here `repeatChoices`, and the checkmark's target, become the Repeat page's copy. `rule(for:)` keeps an unshown rule (BYMONTH) while its choices are unchanged (decision 5, ticket 25); the copy must keep that too.
- The checkmark to copy: `CustomRepeatPage`'s `toolbar(isLocked:canChoose:)`, with `Button(role: .confirm)`, a `Label` "Done" with `checkmark`, `.disabled(!canChoose)` and `.lockedWhileNudging(isLocked)`, so VoiceOver reads the lock's reason. The lock is read in `body` and passed in (ticket 19). `@Environment(\.dismiss)` on the pushed page pops it; Apple's `DismissAction` docs list popping a `NavigationStack` page, and on the iPhone it left the sheet open.
- Watch for: the Custom page drops its copy in `onDisappear`, which on the iPhone fired only when the page left: a cancelled swipe back and the End Date picker kept the changes (ticket 17's device checks). The Repeat page can't do the same, because pushing Custom over it fires its `onDisappear` too. Its Back needs another hook. Options: the form root's `onAppear`, or a `NavigationStack` path in `ReminderFormSheet`. Apple's docs don't say how either behaves on a cancelled swipe back, so it's a device check.
- Watch for: locked, the Repeat page's Custom row is plain, with no link or chevron (ticket 16). Opening Custom from the copy must still read the copy's choices.
- The mockup comes first, as in ticket 17. Mockups are frozen, and `docs/mockups/2026-10-24-custom-checkmark/` draws only the Custom page's checkmark. Make a new dated mockup copied from that one, showing the Repeat page's checkmark and the flow from Custom back to Repeat, and stop for Brian's approval before building. In that mockup, the Repeat page's `repeat` handler still writes `x.repeat` on tap, and `customSave` writes `state.sheet.draft`.
- Screenshot harness: `testFormPages` opens Repeat then Custom, taps the Custom page's "Done" and shoots `form-custom-chosen` on Repeat. Extend it to tap the Repeat page's checkmark too. `testCustomLocking` prints the accessibility tree before and after the lock (`reportCustomPageAccessibility`, page 0 is before). Bar buttons are tapped through `barTap`. Its walk only scrolls down: a drag down at the top of the sheet closes it.
- Developer stops, in this order:
  - Approval of the new mockup.
  - `tdd` seam to agree: the Repeat page's copy, and how the Custom page's copy saves into it, are form state that `ReminderForm` tests can reach without a view. Propose the seam before the first test.
  - Simulator check: the Repeat page's checkmark, unlocked and locked, light and dark, default and largest text, on both simulators.
  - Device check on the iPhone: the checkmark's VoiceOver label; Back on the Repeat page dropping a preset choice; Back on the Repeat page dropping a custom repeat saved by the Custom page's checkmark; a cancelled swipe back on the Repeat page keeping its choice.

## Comments

- 2026-10-24, Brian: asked for this ticket and decided three things: the Custom page's checkmark writes into the Repeat page's copy, not the form; `hasChanges` counts an unsaved Repeat choice; and the new mockup is the ticket's first step.

### 2026-10-24: built, simulator check; device checks to come

- Mockup: [2026-10-24-repeat-checkmark](../../../docs/mockups/2026-10-24-repeat-checkmark/README.md) is new, a copy of the Custom checkmark mockup changed only for the Repeat and Custom pages and Cancel's check. Brian approved it.
- `tdd` seam, agreed: on `ReminderForm`, the Repeat page's copy is `repeatPageDraft`, a preset or Custom with its choices, `nil` while the page shows the repeat itself. `repeatPagePreset` is what the page checks, `repeatPageSummary` the summary under Custom, `chooseRepeatPageChoice()` the checkmark and `closeRepeatPage()` Back. `customPageChoices` now reads the Repeat page's choices, and `chooseCustomPageChoices()` writes `.custom` into the copy, not the form. The tests that expected the Custom checkmark to reach the form now tap the Repeat checkmark too. Each new test failed first, except the BYMONTH one (`theRepeatPagesCheckmarkWithNothingChosenKeepsTheRule`), which guards the `nil` case and passed at once.
- `hasChanges` counts the copy while its rule differs from the repeat's, so checking the preset already chosen isn't a change. `checkLock()` drops both copies.
- Back: the Repeat page's `onDisappear` can't be the hook, since pushing Custom fires it, so `ReminderFormSheet` now binds a `NavigationStack` path and calls `closeRepeatPage()` when `.repeat` leaves it. Apple's `NavigationStack` docs say the stack removes a page's value from the path when Back or a swipe pops it. They're silent on a cancelled swipe, so that stays a device check.
- No `.disabled` on the Repeat checkmark, unlike the Custom page's: a preset can't be blocked, and a custom repeat that can't be saved can't get past the Custom page's disabled checkmark.
- DESIGN.md: the accent's list and "Fill sparingly" now name the Repeat page's filled checkmark beside the Custom page's.
- Review: no hard violations. Fixed: DESIGN.md, three over-long comment lines, `hasChanges` split into named parts, and the harness's `reportCustomPageAccessibility(page:)` renamed `reportFormPageAccessibility(_:)` with named screens. Left alone: `ReminderForm` now holds both pages' copies (Large Class; moving the Repeat and Custom copies into a small type of their own would be a follow-up), the four `switch repeatPageDraft`, and the two pages' near-identical checkmark toolbars.
- Simulator check (`testFormPages`, `testCustomLocking`, both simulators, portrait, landscape and largest text, light and dark): the Repeat page's checkmark is the same teal glass circle as Save and the Custom page's. After the Custom checkmark, Repeat shows Custom checked with "Every Saturday at 5:00 PM." under it, and after the Repeat checkmark the form's Repeat row reads Custom. Locked, it's grey and disabled, under the lock note. Accessibility tree: "Done" button before the lock, "Done", disabled, after it. `scripts/test.sh` passed on both simulators.
- Harness gap, not from this ticket: `testCustomLocking`'s shots in the landscape run come out portrait, ticket 17's own ones too. `testFormPages` shows the Repeat page and its checkmark in landscape.
- Open: criteria 1, 2 and 4 (the checkmark and Back on the iPhone: Back dropping a preset, Back dropping a custom repeat the Custom checkmark chose, a cancelled swipe back keeping the choice) and criterion 6's VoiceOver label, on the iPhone.

### 2026-10-24: device checks; resolved

On Brian's iPhone (iPhone 15, iOS 27.0.1), a fresh install (uninstalled afterwards), with one reminder repeating Every Day, edited and never saved:

- Back on the Repeat page drops a preset: Every Week tapped, Back, and the form still read Every Day; reopening Repeat showed Every Day checked. Criterion 2.
- Back drops a custom repeat from the Custom page's checkmark: the checkmark returned to Repeat with Custom checked and its summary shown; Back left the form on Every Day, and reopening Repeat showed Every Day checked. Every Week and the Repeat checkmark then set the form to Every Week, and the checkmark with nothing changed kept it. Criteria 1 and 4.
- A cancelled swipe back: Every Month tapped, a swipe back stopped halfway, and the page stayed with Every Month checked; Back then left the form on Every Week. Criterion 2.
- VoiceOver reads the Repeat page's checkmark as "Done, Button". Criterion 6.
- The form showed Every Day at the VoiceOver check, not the Every Week left by the swipe check. A re-check found no fault: with Every Week chosen, going to Settings and back kept the form open on Every Week, so the form had been reopened between the checks.
