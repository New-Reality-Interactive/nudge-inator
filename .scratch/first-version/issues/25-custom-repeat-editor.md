Status: resolved

# Custom repeat editor

Visual spec: mockup Repeat and Custom pages of the New Reminder form (`docs/mockups/archive/2026-10-04-first-version/`).

Design spec: `docs/design/DESIGN.md`. The page uses only system controls (`Picker` in the segmented style, `Stepper`, checkmark lists and a `DatePicker`), which DESIGN.md says are drawn as the system draws them, so it adds no new component. Where it and the mockup disagree, see its Precedence note.

## What to build

The Repeat page lists the seven presets, then **Custom** in its own section with a chevron, as Calendar does. Its footer is the summary when Custom is chosen, and a one-line hint otherwise. Choosing Custom starts from the preset that was chosen (Every 2 Weeks becomes weekly, every 2 weeks, on the start's weekday) and pushes the Custom page. The page builds a rule through the engine's rule type (ticket 09). The person never sees or types RRULE.

- **Summary** at the top, from the engine ("Every 2 weeks on Monday and Wednesday at 9:00 AM, 5 times."). It updates as the choices change.
- **Frequency:** Daily, Weekly, Monthly or Yearly, then a stepper row "Every 2 weeks". The upper limits are 30 days, 12 weeks, 12 months and 10 years.
- **On**, for weekly: a checkmark list of the weekdays, Monday first. The last chosen day can't be cleared.
- **On**, for monthly: a choice derived from the start date, so there's nothing else to pick.
  - "On the 28th".
  - "On the fourth Monday", offered when it's the first to fourth.
  - "On the last Monday", offered when the start is in the month's last week.
  - "On the last day".
  - For the 29th to the 31st, the footer says those months are skipped and points to "On the last day".
- **Yearly:** no extra control. The footer says it repeats on the start's day and month.
- **Ends:** Never, After or On Date. After adds a stepper ("After 10 times", 2 to 30). On Date adds a date picker no earlier than the start.
- **Next Times:** the next three due times from the engine, with the year when it isn't this year, and "Then it ends." when fewer remain.
- An end date before the start shows its reason as text and disables Save. So does a rule with no times left.

## Acceptance criteria

- [x] Choosing Custom after a preset opens it with that preset's frequency, interval and day already set.
- [x] Each control builds the rule the summary describes (UI or unit test through the app model).
- [x] Monthly choices follow the start date, and a choice the new start doesn't offer falls back to the day of the month.
- [x] Next Times matches the engine's output and updates as controls change.
- [x] An end date before the start shows a visible reason, and Save is disabled.
- [x] Choosing a preset after Custom replaces the custom rule, and reopening an existing reminder with a custom rule shows Custom checked with its choices restored.
- [x] VoiceOver reads each weekday as a checkbox with its name and state, each monthly choice as a radio button, and the summary as one element. Nothing relies on colour alone.
- [x] Works at the largest Dynamic Type size (segmented pickers become menus) and in landscape.
- [x] A `#Preview` for the page in Light, Dark and the largest Dynamic Type size.

Blocked by: 09, 24

## Comments

**Decisions settled with the user before coding (2026-10-17).** Apple's docs, read through apple-rag (short queries; long ones came back empty), confirm the following:
- `Stepper(value:in:)` keeps the value in its range. The docs don't say what VoiceOver reads.
- `DatePicker(selection:in: PartialRangeFrom, displayedComponents: .date)` gives a date-only picker with a minimum.
- `.segmented` is for two to five options and `.menu` for more.
- `.combine` merges children, "not all traits".
- SwiftUI's `AccessibilityTraits` has `isToggle` (iOS 17+, "switch button") and `isSelected`, but **no checkbox or radio trait**. `radioButton` is BrowserEngineKit's `UIAccessibilityTraits` only, and `.toggleStyle(.checkbox)` is macOS only.

The decisions:
1. **The logic is in NudgeEngine** (`CustomRepeat.swift`).
   - `CustomRepeat` holds the page's plain choices: `frequency`, `interval`, `weekdays` (never empty, changed by `toggle(_:)`), `monthlyDay` (`.dayOfMonth`, `.weekdayOfMonth`, `.lastWeekdayOfMonth`, `.lastDay`), and `ending` (`.never`, `.afterCount`, `.onDate`) with `count` and `endDate`, both kept while another ending is chosen.
   - Its limits are `intervals(for:)` (30 days, 12 weeks, 12 months, 10 years) and `counts` (2...30). A new frequency clamps the interval.
   - On `Engine`, which owns the Gregorian calendar and time zone:
     - `customRepeat(from:startingAt:)` seeds from a preset or Never, as the mockup's `customFrom`, or restores a custom rule, clamped to the limits;
     - `repeatRule(for:startingAt:)` builds the rule;
     - `monthlyDays(startingAt:)`, `monthlyDay(of:startingAt:)` (the fallback to the day of the month), `title(of:startingAt:)`, `skippedMonthsNote(of:startingAt:)`, `name(of:)` and `endsBeforeStart(_:startingAt:)`.
   - The monthly titles and the skipped-months note are whole sentences in the engine's catalog. The page's other words are in the app's catalog, with plurals for "Every %lld days/weeks/months/years" and "After %lld times".
2. **Test seams:**
   - `CustomRepeatChoicesTests` (engine, macOS, 19 tests) compares with RRULE literals and summary wording pinned in en_US.
   - `ReminderFormTests` (app, through the real AppModel) went from 21 to 31 tests.
   - VoiceOver, AX5 and landscape are screenshot and device checks.
3. **The page edits the form live.**
   - `ReminderForm` stores `customRepeat`, and `repeatRule` is computed from it and the start. So moving the start re-derives the monthly day and the yearly date, and a choice the new start doesn't offer falls back to the day of the month.
   - A preset clears it. The Custom link pushes the page, whose `onAppear` calls `chooseCustom()`, which seeds only if the repeat isn't already custom. Back just pops.
   - Accepted: a custom "Daily, every day, never ends" equals Every Day and reopens as Every Day.
4. **Save blocks:** `SaveBlock.endsBeforeStart` and `.noTimesLeft` come after `.noTitle` and `.pastTime`.
   - They come from `form.repeatBlock`, so the Custom page shows its reason even while the title is empty. The page reads "Choose an end date after the start." under Ends, and "This repeat has no times left. Change when it ends." under Next Times. The Starts footer reads the mockup's "The repeat ends before it starts…" or "The repeat has already ended…".
   - `.noTimesLeft` doesn't apply while the start and the repeat are as saved, so an ended reminder can still be renamed. This departs from the mockup's `noTimesLeft`.
5. **A rule the page can't show** (BYMONTH, an UNTIL time, a COUNT above 30) is read into the nearest choices. The form **keeps the rule as set** until a choice or the start changes (this came from review).
6. **VoiceOver:**
   - Weekdays are a `CheckmarkRow` plus `.isToggle`.
   - Monthly choices are a `CheckmarkRow` (`.isSelected`), as the Repeat page's presets are.
   - The summary is one `Text`.

**Tests:**
- **Red first:**
  - seeding from Every 2 Weeks and from the other presets;
  - the monthly choices, their rules, the fallback and the titles;
  - Ends;
  - the restore;
  - the limits and the clamp;
  - the weekday toggle;
  - ends-before-start;
  - the form's `chooseCustom`, `upcomingDueTimes`, the two save blocks and `showsYear(of:)`;
  - each review fix.
- **Passed on their first run, kept as acceptance coverage:**
  - the ticket's example summary;
  - a rule the page can't show;
  - the form's start-change fallback;
  - reopening a saved custom repeat, with a preset after it;
  - each control through the form;
  - a weekly start on a day that isn't chosen, which still falls due as RFC 5545's first instance (ticket 09).
- **`scripts/test.sh` passes:** 223 engine tests, and 149 app tests on each of the iOS 26.1 and 26.5 simulators.

**Screenshots** (iPhone 17 simulator, iOS 26.5): a throwaway XCUITest project in the scratchpad, with nothing committed. The simulator was put back to `large` text and light appearance, and the app was uninstalled. Compared with the mockup's Repeat and Custom pages:
- **Repeat page:** the presets, then Custom in its own section with a checkmark and chevron, and the summary footer.
- **Custom page, weekly:**
  - the bold summary on top;
  - Frequency as a segmented control and the Every stepper;
  - On with the weekdays, Monday first, and "Choose one or more days.";
  - Ends as a segmented control and After's stepper;
  - Next Times with Today, short dates and the time trailing.
- **Monthly:** "On the 17th", "On the third Saturday", "On the last day", and "These follow the start date…". With On Date, the End Date pill and "Then it ends.".
- **Yearly:** "On October 17, from the start date…".
- **Landscape:** centered at the readable width.
- **AX5 in Dark:** Frequency and Ends become menus under their labels, rows stack, and text wraps.

This matches the mockup's layout. One difference: the summary's "until Sun, Jan 17" has no year when the end date is next year. That is the engine's summary format from ticket 09, not this page.

**Code review** (two axes, against main). Fixed:
- **Spec:**
  - An Edit form rebuilt a custom rule from the choices, so a rule with parts the page can't show was rewritten on a rename. It's now kept until a change (`aRuleThePageCantShowIsKeptUntilAChoiceChanges`).
  - A restored interval or count could fall outside the steppers' limits. It's now clamped (`aRestoredRuleIsReadInWithinTheSteppersLimits`).
  - Next Times used `.now` rather than the form's clock. It now uses `form.currentTime` and `showsYear(of:)`.
  - The Repeat and Custom pages didn't lock if the reminder started nudging while they were open. They're now disabled with the lock note at the top (`RepeatLockSection`).
  - Only two controls went through the app model. All of them do now (`eachCustomPageControlBuildsItsRule`).
- **Standards:**
  - The app had a second ordinal formatter and second weekday names. Both now come from the engine (`aMonthlyDaySomeMonthsLackSaysTheyAreSkipped`, `weekdayNamesFollowTheEnginesLocale`).
  - The until date fell back to 0 silently. It now uses `calendar.component`.
  - `CheckmarkLabel` is shared by `CheckmarkRow` and the Custom link.
  - The Next Times count is one constant.
  - `MonthlySection` takes only the form.
  - The checkbox comment cites the docs.
  - GLOSSARY.md defines **Start**.
- **Kept, as judgement calls:**
  - `startWeekday`'s `?? .monday`, commented as unreachable (Gregorian weekdays are 1 to 7);
  - each place keeps the mockup's own wording for a repeat block;
  - the summary sits in an empty section's header, as the mockup puts it above the sections;
  - the form's monthly pass-throughs follow the form's pattern of reading the engine.
- **Noted, not changed:**
  - a yearly 29 February gets the engine summary's "(skipped in years without one)" but no footer, because the ticket asks for the footer only for monthly;
  - the end date is split into a day in the engine's time zone, the device's own.

**Device run (2026-10-17), Brian's iPhone: iPhone 15, iOS 27.0.1, wired, Xcode 26.6.**
- **Before:** Nudge-inator was not installed. A first attempt failed because the phone was locked, and it left the app installed. It was uninstalled before the real run. **After:** it was uninstalled, and `xcrun devicectl device info apps` lists no Nudge-inator.
- **All 149 app tests pass on the phone** from a fresh install (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`, two prompts). The ring and notification-action checks were skipped, as they are by default.
- **Manual checks Brian ran with the app installed:**
  1. Custom from each preset opens with its frequency, interval and day: pass.
  2. VoiceOver on weekdays: "Saturday, switch button, on … Double tap to toggle setting", and "Sunday, switch button, off".
  3. VoiceOver on monthly choices: "Selected, On the 17th, button".
  4. The steppers' limits: pass. The Ends segments read "Never, button, 1 of 3".
  5. An end date before the start shows the reason under Starts and on the Custom page, and ✓ is dimmed. Picking a later date clears both: pass.
  6. The largest text size, in portrait and landscape: menus, stacked rows, nothing cut short, landscape full-screen and centered: pass.
- **Found and fixed on the device**, each rechecked there and passing:
  - **The Frequency and Ends headings were hidden from VoiceOver.** The segments don't read the picker's label, so the headings are now read.
  - **The End Date picker showed the start in place of an earlier end date** that the rule still held. Its range now keeps that date.
- **The VoiceOver criterion is met by the user's definition:** VoiceOver reads what the control is on this iOS version, and the controls are the right ones for the job.
  - The weekdays are a multiple choice, which iOS reads as toggles: "switch button, on/off" on iOS 27.0.1.
  - The monthly choices are a single-choice checkmark list, as the Repeat page and Calendar use, read as "Selected …, button".
  - iOS has no checkbox or radio trait.
  - The summary is one static-text element holding the whole sentence. This was checked in the iOS 26.5 simulator's accessibility tree, which VoiceOver reads from.

**Device checks, done (2026-10-17, iPhone 15, iOS 27.0.1):**
- **The summary** is read by VoiceOver as one element: "Every Saturday at 6 PM, heading".
- **The Strength picker** had the same unnamed-segments problem as Frequency and Ends. Its heading is now read too, and VoiceOver says "Strength" before the segments.
- **A time-zone change** while the app ran (to Tokyo) left the end date right: October 30 read "until Fri, Oct 30". The repeat kept its moment, not its wall-clock time; that question is noted in ticket 21.
- **The lock on the Repeat and Custom pages** moved to ticket 27's criteria, since it needs Edit's entry point.

**Left alone:**
- typing RRULE text, sub-daily repeats, and BYSETPOS and the rest outside the subset;
- the Now, My Day and Tags content (26, 28, 29);
- reminder details and Edit's entry point (27);
- How It Nudges (31);
- iPad.

