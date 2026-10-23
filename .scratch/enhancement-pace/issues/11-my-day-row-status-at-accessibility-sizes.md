# 11: My Day rows break words at accessibility text sizes

**What to build:** A bug fix. At the accessibility text sizes a My Day row puts its status label under its text, as the as-built mockup draws it, so no word breaks mid-word.

**Blocked by:** none.

**Status:** resolved

Found while making the as-built mockup (ticket 02), in simulator screenshots on `iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0` at the largest text size (AX5), 2026-10-21. Brian agreed the mockup draws the row as intended, and asked for this ticket.

## The bug

At the accessibility text sizes, a My Day row that shows a status label (✓ Done, Missed, Skipped, Paused) squeezes its text into a narrow column, so words break in the middle: the time reads "12:33 / PM", the title "Morn- / ing meds", the tags "#morn- / ing", and the label itself "Do / ne".

`MyDayRowView.opener` in `App/MyDay/MyDayRows.swift` puts `text`, a `Spacer` and the `outcome` (the status label) in an `HStack` at every size. `text` itself stacks the time over the title at accessibility sizes, but the label stays beside it and takes its share of the width.

## What it should do

The as-built mockup's My Day (`docs/mockups/2026-10-21-as-built/`, Text Size AX1 to AX5): at accessibility sizes the row stacks the time, then the title and its detail, then the status label under them, with the chevron. At the other sizes nothing changes.

- [x] At accessibility sizes a My Day row's status label sits under its text, and no word in the row breaks mid-word at AX5 (simulator screenshots on both simulators, portrait and landscape: `scripts/screenshots.sh`, the `myday` screens).
- [x] At the default size the row is unchanged (screenshots compared with the as-built mockup).
- [x] VoiceOver still reads the row as one element, with the status (device check on the iPhone, after the simulator pass).

## Before you start

- Builds on: nothing in the pace feature; it's a layout fix found in ticket 02. `App/Design/SizeAdaptiveStack.swift` already swaps an `HStack` for a leading `VStack` at accessibility sizes (`AnyLayout`, so the views keep their identity), and `SettingsRow` (ticket 09's Comments, 2026-10-23) drops its `Spacer` there. One of those is likely the fix for `MyDayRowView.opener`. The as-built mockup (`docs/mockups/2026-10-21-as-built/`) draws this row; the proposed pace mockup didn't change My Day.
- Watch for: the walk's `testMyDay` shoots `myday` in 3 pages, which at AX5 may not reach the rows with a status label. Ticket 10 added `shot(_:pages:stopsAtEnd:)`, which treats `pages` as a limit and stops at the end of the page; use it if 3 isn't enough. `SHOTS_TESTS="testMyDay"` shoots just that part. The row's VoiceOver element is combined, so check the combined label still carries the status after the layout change.
- Developer stops: agree the `tdd` seams (likely none: a layout-only change may have no seam outside the view, so say so); the simulator pass with `scripts/screenshots.sh`, portrait and landscape, AX5 and the default size against the as-built mockup; the VoiceOver device check.

## Comments

### 2026-10-23: the fix, and the simulator pass

- No `tdd` seam: the change is layout inside `MyDayRowView`, with nothing to test outside the view, so it was checked with screenshots.
- `MyDayRowView.opener` is a `SizeAdaptiveStack` and drops its `Spacer` at accessibility sizes, as `SettingsRow` does. There, a row with no Done button puts its status and the chevron on one line under the text, as the as-built mockup's `.trail` does. A row with a Done button keeps Done and the chevron on their own line, as before. The opener is full width, so a stacked row still opens anywhere across it.
- Screenshots: `SHOTS_TESTS="testMyDay"` with `SHOTS_VARIANTS="portrait landscape largest-text largest-text-landscape"` on both simulators. At AX5, portrait and landscape, the status sits under the text with the chevron, and no word breaks mid-word. At the default size the rows look as before, status and chevron trailing.
- `scripts/screenshots.sh` gains a `largest-text-landscape` variant, only on request: the criterion asks for AX5 in landscape, which no variant shot. `testMyDay` pages `myday` up to 20 pages, stopping at the end, then scrolls back to Filter with `scrollToTop(revealing:)`.
- Known gap, not this ticket's: on `iPhone 15 - iOS 27.0` in `largest-text-landscape`, the walk can't find the bar's Filter button after the `myday` shots, so `myday-filter` isn't shot there. The other three AX5 runs shoot it.
- Left as it is: at AX5 the "✓ Done" label starts a little in from the text's leading edge, where the mockup draws it flush. `StatusLabel` is a `Label`, and in a `List` the icon seems to get a column of its own. It is the same `StatusLabel` other screens use, so it wasn't changed here.

### 2026-10-23: criteria 1 and 2

- Criterion 1: Brian looked at the AX5 shots, portrait and landscape on both simulators, and they look fine. Ticked.
- Criterion 2: the default-size shots were compared with the app before this change, not with the as-built mockup. The default-size layout didn't change. Brian accepted that comparison in place of the mockup's. Ticked.
- Moved to their own tickets, at Brian's request: whether the Filter button should work the same way in portrait as in landscape, and whether its icon could say more clearly that it filters by tags (ticket 14). The indented status label at AX5 (ticket 15).

### 2026-10-23: device checks, on Brian's iPhone (iPhone 15, iOS 27.0.1)

The app wasn't installed at the start, so it was uninstalled afterwards. Brian made two reminders by hand, marked one Done and paused the other, then deleted both and put VoiceOver and the text size back.

- Criterion 3, at AX5 with VoiceOver: each row reads as one element with its status, then the hint. "3:13 PM, Task 1, Done at 3:13 PM after 1 nudge. Done, button", and "3:14 PM, Task 2, Skipped. The reminder was paused. Skipped, button", each followed by "Opens the reminder's details." Double-tapping each row opened its details. Ticked. (The second row says Skipped, not Paused: pausing a reminder whose occurrence was already due closes it as Skipped, as before this ticket.) A first run at the default text size read the same.
- The screenshot gap above, at AX5 in landscape with VoiceOver: after scrolling My Day to its end and back, the bar's Filter icon reads "Filter by Tags, button", and double-tapping it opens the Filter sheet. So the button works on the phone, and the walk's failure on the iOS 27 simulator is in the harness.
