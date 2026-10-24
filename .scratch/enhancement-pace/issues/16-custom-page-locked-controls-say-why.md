# 16: The Custom page's locked controls look and read locked

**What to build:** A bug fix, following ticket 13. When a reminder starts nudging while its Custom repeat page is open, every locked control there looks locked and VoiceOver gives the lock's reason on it, as the Edit form's locked fields do. Next Times stays current while the page is open.

**Blocked by:** 18.

**Status:** resolved

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

- [x] VoiceOver on each locked Frequency and Ends segment, the selected one too, reads the lock's reason, on an iPhone (phone and iOS version recorded). The menus at accessibility sizes still do.
- [x] VoiceOver on the locked Every stepper reads the reason, at the default and accessibility sizes.
- [x] Locked, the weekday names look dimmed, like the segments, in light and dark mode, and the steppers are plain text without their − and +, as the Edit form's locked Every row is (reworded, Brian, 2026-10-24: Comments).
- [x] Locked, the Frequency, On and Ends headings carry the `lock` glyph, as Strength and Pace do, and VoiceOver reads them as headings, not dimmed controls with a hint.
- [x] Next Times never lists a time that has passed while the page is open.
- [x] Unlocked, the page looks and reads as it does now.

## Before you start

- Builds on: ticket 13 (`SegmentedChoiceSection`, `lockedChoiceElement`, `LockableLabel`). Frequency has the Every stepper after its segments, which `SegmentedChoiceSection`'s `rows` may fit.
- Watch for: the page can only lock while it's open, since the Repeat row is locked on a Nudging reminder. A device check needs a Custom reminder saved a few minutes ahead, with the page open as it falls due.
- Unknown: whether the stepper's + not dimming is iOS's own drawing of a disabled `Stepper`. Look it up with `apple-rag-mcp`, and check it on the simulators.
- Also builds on ticket 18 (Comments): `scripts/screenshots.sh` now shoots both simulators at once, so a targeted run (`SHOTS_TESTS`, `SHOTS_VARIANTS`) takes about 60% of the old time; run it while the code review runs, once `scripts/test.sh` passes (`docs/agents/ticket-workflow.md`, step 7). A change to a screen traces to the tests that reach it.
- Also builds on ticket 19 (Comments, iPhone checks 3 and 4): a SwiftUI environment value read inside a toolbar isn't the screen's (its Dynamic Type size stayed below the accessibility sizes), so read it outside and pass it in. A shot test can print what a control exposes to VoiceOver (`testMyDayFilterAccessibility` prints label and value in the test log), which is quick to check on the simulators before an iPhone run. VoiceOver check on the phone: the exact words, one scenario at a time.
- Developer stops:
  - No `tdd` seams are expected (SwiftUI views and accessibility), unless Next Times' freshness is a value the engine can compute from the time. Propose any seam before the first test.
  - Simulator check: the Custom page locked, in light and dark, at the default and the largest text size, on both simulators.
  - Device check on the iPhone for VoiceOver (the first four criteria): a Custom reminder saved a few minutes ahead, with the page open as it falls due.

## Comments

### 2026-10-24: built, simulator check, device checks to come

- No `tdd` seams: the engine already works Next Times out from its clock (`upcomingDueTimes` starts at now), so the stale list was only the page not drawing again. Everything else is SwiftUI and VoiceOver.
- The fix: the lock moved off the `Group` onto each control, so the headings stay headings. Frequency and Ends are `SegmentedChoiceSection`s (ticket 13's one VoiceOver element with the reason), with the Every and After steppers as its rows. The Frequency, On and Ends headings carry `LockableLabel`'s `lock`, and so do the steppers' and End Date's labels. The page ticks each minute (`EveryMinute`, on the `Form` so exactly one loop runs) and hands the minute to Next Times, which draws again from the clock.
- The weekday (and monthly) names didn't dim because `CheckmarkLabel` set `.label` on them, which a disabled row doesn't dim. Disabled, it now uses DESIGN.md's secondary label. That's shared, so the Repeat page's presets and Custom row dim too when they're locked, which they didn't before. Tags and the filter sheet are never disabled.
- The stepper's +: Apple's Stepper and `disabled(_:)` docs say nothing about how a disabled stepper draws. On both simulators, light and dark, the + stayed black or white while locked, so it's iOS's own drawing. Brian chose plain text without the − and +, as the Edit form's locked Every row is (`LockableStepper`), and criterion 3 is reworded to say so.
- The note under the weekdays ("Choose one or more days.") and the other footers no longer get the lock's hint: it came from the `Group` and landed on everything, headings too. A footer isn't a control, as a heading isn't, and the Edit form's footers don't carry it either.
- Screenshot harness: a `customLocking` scenario seeds a weekly Custom reminder due a minute or two after launch, and `testCustomLocking` opens its Custom page, waits for the lock, shoots it light (`SHOT_DARK` for dark) and prints the accessibility tree (`ACCESSIBILITY` lines). It only scrolls down: a drag down at the top of the sheet closes it.
- Simulator accessibility tree (iOS 27.0): "Frequency", value "Weekly", disabled, and "Ends", value "Never", disabled, each one element. The headings "Frequency", "On" and "Ends" are plain text and not disabled. XCUITest doesn't expose the hint, so whether VoiceOver reads the reason (and still says "dimmed") is for the iPhone.
- Review: no hard violations. Fixed: the tick was a `.task` on a `Section`, which may run once per row or not at all when Next Times is empty, so it moved to the `Form` and the minute is passed in. Two comments made clearer. Left alone: the harness's force unwraps (screenshot tooling, as the rest of its seed), a third `EveryMinute` loop (the form's lock tick runs only while editing, and a New Reminder's Custom page needs it too), and the hand-listed Ends choices (`CustomRepeat.Ending` isn't `CaseIterable`, an engine change this ticket doesn't need).

- Simulator check (`testCustomLocking`, both simulators, light and dark, default and largest text): the headings carry the `lock`, the weekday names and segments (menus at the largest size) are dimmed, and Every week is plain text with the `lock`. Next Times dropped today's time once it passed: at 1:19 PM, with the reminder due at 1:19, it started at Tomorrow. The walk now gives the reminder a 90-second lead time, since at the largest text on iOS 26.5 it reached the form after a 45-second lead had run out. One iOS 27 run was marked failed after both tests passed: Xcode crashed writing its result bundle (`CASTreeDataStructure … Unable to write data`).

### 2026-10-24: device checks passed on the iPhone

On Brian's iPhone (iPhone 15, iOS 27.0.1), fresh install. Starting settings: Larger Accessibility Sizes off, VoiceOver off. Test reminder: Weekly on Saturday and Sunday, saved at 1:52 PM to start at 1:57 PM, Break Through Focus off. Its Custom page was opened before 1:57 and left open as it fell due.

- Unlocked, default size (criterion 6): "Frequency, heading"; "Daily, button, 1 of 4", "Selected, Weekly, button, 2 of 4", "Monthly, button, 3 of 4", "Yearly, button, 4 of 4"; "Every week, decrement, 1, dimmed, button" (at its minimum) and "Every week, increment, 1, button"; "On, heading"; each weekday "Monday, Switch Button, Off", then "Double-tap to toggle setting"; "Ends, heading"; "Selected, Never, button, 1 of 3" and the others; Next Times "Today, 1:57 PM" first. As before, with no lock reason.
- Locked, default size (criteria 1, 2, 4, 5): "Frequency, heading"; "Frequency, Weekly, dimmed", then "Locked while it's nudging. Mark it Done or pause it to change it."; "Every week, dimmed", then the reason; "On, heading"; each weekday "Monday, dimmed, Switch Button, Off", then the reason; "Ends, heading"; "Ends, Never, dimmed", then the reason. Next Times started at "Tomorrow, 1:57 PM": today's time had passed.
- Locked, largest size (criteria 1 and 2): the Frequency and Ends menus and Every week read with "dimmed" and the reason. Brian reported they matched what was expected.
- On screen, light and dark (criteria 3 and 4): the Frequency, On and Ends headings carry the `lock`, "Every week" is plain text with the `lock` and no − or +, and the weekday names are grey.
- Clean-up: Brian put back his text size and VoiceOver and deleted the test reminder. The app wasn't on the phone at the start, so it was uninstalled, and `devicectl` confirmed it's gone.
- Every criterion is ticked, so the ticket is resolved.

