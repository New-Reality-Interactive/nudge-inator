# 22: The Repeat page saves with a checkmark, and Back changes nothing

**What to build:** The form's Repeat page gets a checkmark in the top-right corner that saves its choice as the reminder's repeat and goes back to the form. Back goes back without changing anything. The Custom page's checkmark from ticket 17 then saves into the Repeat page's choice, not the form, so only the checkmark on the page being left saves.

**Blocked by:** 17.

**Status:** needs-triage

Brian asked for this ticket on 2026-10-24, after choosing ticket 17's checkmark for the Custom page.

## The problem

Each row on the Repeat page sets the reminder's repeat as soon as it's tapped (`RepeatPage`'s `CheckmarkRow` action writes `form.repeatPreset`). So Back always keeps whatever was tapped last, and the person can't look at the options and leave without changing the repeat. With ticket 17, the Custom page works the other way: nothing is kept until its checkmark is tapped. The two pages should work the same way.

## What it should do

- [ ] The Repeat page has a checkmark button in the top-right corner. Tapping it saves the page's choice as the repeat and returns to the form. Tapped with nothing changed, it leaves the repeat as it was.
- [ ] Back returns to the form and changes nothing: a choice made on the page is dropped, and the repeat stays as it was.
- [ ] Opening the page shows the reminder's current repeat checked: a preset, Never, or Custom with its summary.
- [ ] Only the checkmark on the page being left saves. The Custom page's checkmark writes its choices to the Repeat page's copy, not to the form. It returns to the Repeat page with Custom checked and its summary shown, and nothing reaches the form until the Repeat checkmark is tapped. Back on the Repeat page then drops that custom repeat too. Opening Custom again from the Repeat page shows the copy's choices.
- [ ] Cancel's confirmation (`hasChanges`) counts a choice on the Repeat page that hasn't been saved, as ticket 17 counts an unsaved Custom page edit (`customPageEdit`).
- [ ] The checkmark meets `docs/design/DESIGN.md` and matches the form's own Save checkmark and the Custom page's checkmark (ticket 17). VoiceOver reads it as "Done", as on the Custom page.
- [ ] While the reminder is nudging, the checkmark is locked as the page's rows are (ticket 13: `lockedWhileNudging`, `RepeatLockSection`).

## Before you start

- Changes ticket 17's behavior. In [ticket 17](17-custom-repeat-saved-with-a-checkmark.md), the Custom page's checkmark saves straight to the form. Here it writes to the Repeat page's copy instead, and only the Repeat checkmark reaches the form.
- Builds on: ticket 17's copy of the choices in `ReminderForm` (`customPageEdit`). The Repeat page needs its own copy of the repeat, opened from the reminder's repeat and written to the form only by its checkmark. The Custom page's copy opens from the Repeat page's copy and saves back into it.
- The mockup comes first, as in ticket 17. Mockups are frozen, and `docs/mockups/2026-10-24-custom-checkmark/` draws only the Custom page's checkmark. Make a new dated mockup copied from that one, showing the Repeat page's checkmark and the flow from Custom back to Repeat, and stop for Brian's approval before building.
- Watch for: a SwiftUI environment value read inside a toolbar isn't the screen's (ticket 19), so read the lock and Dynamic Type outside the toolbar and pass them in.
- Developer stops, in this order:
  - Approval of the new mockup.
  - `tdd` seam to agree: the Repeat page's copy, and how the Custom page's copy saves into it, are form state that `ReminderForm` tests can reach without a view. Propose the seam before the first test.
  - Simulator check: the Repeat page's checkmark, unlocked and locked, light and dark, default and largest text, on both simulators.
  - Device check on the iPhone: the checkmark's VoiceOver label; Back on the Repeat page dropping a preset choice; Back on the Repeat page dropping a custom repeat saved by the Custom page's checkmark.

## Comments

- 2026-10-24, Brian: asked for this ticket and decided three things: the Custom page's checkmark writes into the Repeat page's copy, not the form; `hasChanges` counts an unsaved Repeat choice; and the new mockup is the ticket's first step.
