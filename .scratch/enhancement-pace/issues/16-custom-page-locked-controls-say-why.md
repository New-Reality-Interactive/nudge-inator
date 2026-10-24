# 16: The Custom page's locked controls look and read locked

**What to build:** A bug fix, following ticket 13. When a reminder starts nudging while its Custom repeat page is open, every locked control there looks locked and VoiceOver gives the lock's reason on it, as the Edit form's locked fields do. Next Times stays current while the page is open.

**Blocked by:** 18.

**Status:** needs-triage

Found during a device check after ticket 13's, on Brian's iPhone (iPhone 15, iOS 27.0.1), 2026-10-23. Ticket 13's Comments had flagged it as likely. Brian asked for this ticket.

## The bug

Setup: a reminder repeating Custom, Weekly on Friday and Saturday, starting at 10:39 PM, Break Through Focus off. The Custom page was opened before it was due and left open until the lock note showed.

`CustomRepeatPage` (`App/ReminderForm/CustomRepeatPage.swift`) puts `lockedWhileNudging` on a `Group` around the Frequency, On and Ends sections. Ticket 13's fix (`lockedChoiceElement` in `LockableControls.swift`) isn't applied to them. What VoiceOver read (Larger Accessibility Sizes on, +4, unless noted):

- **Frequency and Ends segments:** "Daily, dimmed, button, 1 of 4" and "Selected, Weekly, button, 2 of 4", with no reason. The selected segment doesn't say "dimmed". This is ticket 13's bug. Ends reads the same way ("Selected, Never, button, 1 of 3").
- **The same at the largest size, as menus:** these pass. "Frequency, Weekly, dimmed, button, pop-up button", then the reason. Ends reads the same way.
- **Every stepper:** "Every Week, decrement, 1, dimmed, button" and "…increment…", with no reason, at both sizes.
- **Weekday rows and the "Choose one or more days" note:** these pass, with "dimmed" and the reason.
- **Headings:** "Frequency, dimmed, heading" then the reason, and the same for On and Ends. The `Group`'s hint lands on each section's header. A heading isn't a control, so it shouldn't read as one.

On screen, in light and dark mode:

- The segments are dimmed.
- The stepper's + is drawn as enabled: black in light mode, white in dark. The − is grey only because it's at its minimum of 1.
- The weekday names are drawn as enabled. Only the checkmarks are muted.
- The Frequency, On and Ends headings have no `lock` glyph, while Strength and Pace on the Edit form do (`LockableLabel`).

**Next Times goes stale.** The page was opened before 10:39 PM. At 10:53 it still listed "Today, 10:39 PM" first. After the text size changed (11:04) it started at Tomorrow. The list is worked out when the page draws and isn't redrawn as times pass.

## What it should do

- [ ] VoiceOver on each locked Frequency and Ends segment, the selected one too, reads the lock's reason, on an iPhone (phone and iOS version recorded). The menus at accessibility sizes still do.
- [ ] VoiceOver on the locked Every stepper reads the reason, at the default and accessibility sizes.
- [ ] Locked, the stepper's + and the weekday names look dimmed, like the segments, in light and dark mode.
- [ ] Locked, the Frequency, On and Ends headings carry the `lock` glyph, as Strength and Pace do, and VoiceOver reads them as headings, not dimmed controls with a hint.
- [ ] Next Times never lists a time that has passed while the page is open.
- [ ] Unlocked, the page looks and reads as it does now.

## Before you start

- Builds on: ticket 13 (`SegmentedChoiceSection`, `lockedChoiceElement`, `LockableLabel`). Frequency has the Every stepper after its segments, which `SegmentedChoiceSection`'s `rows` may fit.
- Watch for: the page can only lock while it's open, since the Repeat row is locked on a Nudging reminder. A device check needs a Custom reminder saved a few minutes ahead, with the page open as it falls due.
- Unknown: whether the stepper's + not dimming is iOS's own drawing of a disabled `Stepper`. Look it up with `apple-rag-mcp`, and check it on the simulators.

## Comments
