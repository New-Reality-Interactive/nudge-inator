Status: resolved

# Reminder details

Design spec: `docs/design/DESIGN.md` (Components: Reminder row, Via label, Buttons). Where it and the mockup disagree, see its Precedence note.

## What to build

Details screen with the reminder's title, notes, tags, due time, repeat (the engine's summary from ticket 09, for presets and custom rules alike), strength, Break through Focus and the current occurrence state. Actions: **Done** (when Nudging), Edit (opens ticket 24 form; the locked fields are disabled there while Nudging, ticket 13), Pause or Resume, and Delete with a confirmation. Reachable from Now, My Day, a tag's list, and the Open intent (ticket 20).

## Acceptance criteria

- [x] Done is shown only while Nudging and ends the occurrence.
- [x] Pause on a Nudging reminder shows it as Skipped (not Missed) afterwards; Resume returns it at its next future time.
- [x] Edit stays available while Nudging, and the Schedule section ends with the `lock` glyph and "Start, repeat, strength and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them."
- [x] A custom repeat shows its plain-language summary.
- [x] Delete asks for confirmation; Cancel keeps it; Confirm removes it and its pending items.
- [x] A route-to-reminder entry point exists for ticket 20 and an unknown ID shows a "reminder not found" state.
- [x] Notes and tags appear here and nowhere in notification or alarm content.
- [x] Device (human): editing a Nudging reminder shows the lock note at the top, and VoiceOver reads the lock note as the hint of each disabled control, the Strength segments included. The Repeat and Custom pages lock, with the note, if the reminder starts nudging while they're open. *(Moved here from tickets 24 and 25, which have no Edit entry point.)*

Blocked by: 09, 24, 26

## Comments

**From ticket 26 (Now tab), decided 2026-10-17.** Until this ticket, nothing on Now opens a reminder: a nudge card's title, a Coming Up row and a Last 24 Hours row aren't buttons, and the rows have no chevron. This ticket makes each one open the details (the mockup's `data-open`) and adds the rows' `chevron.right` in `tertiaryLabel` (DESIGN.md › Reminder row). The card's title becomes the link, with no chevron, as DESIGN.md › Nudge card says. The rows are `NowRowLayout` in `App/Now/NowRows.swift`; the card is `NudgeCardView`, whose summary is one VoiceOver element, so it would get the button trait.

**Resolved 2026-10-18.** Every criterion is ticked. Criterion 6 is met by the route entry point (`AppModel.showReminder`) plus "Reminder Not Found" for an unknown ID, and criterion 8 by the device checks below.

**Decisions.**
- Push: `ShellNavigation` (`selection` and `nowPath: [OpenedReminder]`) in `RootView`; `NowTab(path:)` is a `NavigationStack(path:)`; `reminderDetailsDestination()` is one modifier other stacks (My Day, tag lists) reuse. The path holds `OpenedReminder`, not a bare UUID, because `Tag.ID` is a UUID too. `AppModel.route` (the alarm's Open) and a tap share it.
- `AppModel.showReminder` always pushes the details for any ID, so an unknown ID shows "Reminder Not Found". The user chose this over ticket 21's landing on Now; ticket 21's test was changed to match.
- The hero's status words come from DESIGN.md's Status label. A "Last occurrence" row (not in the mockup) is where a paused reminder shows Skipped. Tags are plain text until ticket 29. How It Nudges belongs to ticket 31, and History is out of scope.
- Delete is a `confirmationDialog` hung on the Delete button (iOS 26 draws it as a popover pointing at its source). The screen keeps a snapshot while it slides away so it doesn't flash "not found".
- Resume with no future time shows a "Choose a New Time" alert. Choose Time opens Edit, and Save resumes the reminder (`AppModel.resumeAfterEdit`, tested), asking again if the Edit left no time.
- Found on the phone and fixed: the open Edit form and its Repeat and Custom pages did not lock by themselves when the reminder fell due (iOS 27.0.1 does not redraw them; the iOS 26.5 simulator does, so the simulator can't show it). The form now checks its lock at the start of every minute (`ReminderForm.checkLock`, `EveryMinute`). When the lock arrives, the locked fields go back to their saved values at once (the user's ruling), so the screen shows only what a Save can keep. Title, notes and tags edits are kept.
- Found on the phone and fixed: looking at the Custom page marked Custom. The page now shows `ReminderForm.customChoices`, stored only when a control changes. An undo on `onDisappear` was tried first and did not run on the phone.

**Tests.** `scripts/test.sh` passes: engine tests on macOS, and 193 app tests on iOS 26.1 and 26.5 (iPhone 17). The 193 app tests also passed on the iPhone 15 (iOS 27.0.1). Seams: `ShellNavigationTests`, `ReminderDetailsTests` (the `ReminderDetails` value through the real `AppModel`), `ReminderFormTests` additions. Layout, the dialog, the Edit sheet and VoiceOver are screenshot and device checks.

**Screenshots.** Simulator, iPhone 17, iOS 26.5, compared with the mockup's `viewRem`, at default and largest text, portrait and landscape: the same structure. The differences are the Last occurrence row and the Delete popover (iOS 26 draws the confirmation as a popover).

**Device checks** (iPhone 15, iOS 27.0.1; the app wasn't installed at the start, and it was uninstalled afterwards):
1. Details from a card's title and from Last 24 Hours and Coming Up rows; Done on the details: pass.
2. Pause shows Skipped (hero Paused, Next Paused, Last occurrence Skipped, the Now row "Skipped: the reminder was paused"). Resume with no future time shows "Choose a New Time"; Cancel keeps it paused; Choose Time then Save resumes it: pass.
3. Delete: the confirmation is a popover pointing at the button, with no Cancel button (a tap outside cancels). Cancel keeps it; Confirm returns to Now with no "Not Found" flash; no nudge arrived afterwards: pass.
4. Edit while nudging: lock note at the top, lock glyph on Starts, Repeat, Strength and Break Through Focus, those can't be changed, title and notes save: pass.
5. VoiceOver reads the lock note as the hint of Starts, Repeat, Break Through Focus and each Strength segment. The card reads as a button with "Opens the reminder's details."; a row reads as a button without the chevron: pass. Not confirmed on the phone: the title as a heading, and Edit reading "Edit <title>".
6. Repeat and Custom pages lock by themselves with the note, the Custom page's controls stop responding, Every Day stays checked and Custom is not marked, and Custom still shows after a real change (Weekly, Wednesday): pass, after the three fixes above (the first run failed: nothing locked by itself). A change made on the Custom page before the lock snaps back to the saved value, Strength likewise, the title is kept, and the first Save works: pass.
7. Largest text size, portrait and landscape: Now cards and rows with chevrons, the details (hero stacks, rows wrap, Pause and Delete, the Delete popover) and the Edit form while nudging: pass.

**Review.** The first review's findings were fixed (`resumeAfterEdit`, the tag labels helper, the VoiceOver tag list, the shared preview clock, `OpensDetails`, more tests). A scoped second review of the five commits after it found no breach of AGENTS.md. One finding was a possible bug: storing a preset's starting choices could change the rule. The check showed the due times are unchanged, except that Every Month and Every Year from the 29th to 31st skip short months once a control is tapped, where the preset used the last day. That is ticket 25's existing design, and the page's footer says so. It was kept, with tests that document it. The test setup was tidied so a missed seed fails rather than does nothing.

**Judgement calls kept.** The `AnyLayout` accessibility-size switch is written at several sites (each aligns differently). "Break Through Focus" follows the app's spelling, not GLOSSARY.md's "Break through Focus". The lock-note test reads `engine.lockedFields`. `tickEveryMinute` in `RootView` now uses the shared `EveryMinute` helper and fires 0.5 s after the minute. The `customPageSummary` and `customPageUpcomingDueTimes` pair repeats the shape of `repeatSummary` and `upcomingDueTimes`. `keepTheLockCurrent`'s timing loop has no test, only `checkLock()` does.

**Left alone.** The Open intent (ticket 20), My Day (28), tag lists and tag buttons (29), Settings (30), onboarding and banners (31), a Done before first unlock (32) and iPad.
