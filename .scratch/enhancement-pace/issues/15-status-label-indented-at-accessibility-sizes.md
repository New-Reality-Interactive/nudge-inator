# 15: The Done status label is indented at accessibility sizes

**What to build:** A bug fix. At accessibility sizes, a My Day row's "✓ Done" status label starts at the text's leading edge, as the as-built mockup draws it.

**Blocked by:** none.

**Status:** resolved

Found in ticket 11's simulator screenshots (`iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0`, AX5, portrait and landscape), 2026-10-23. Brian asked for this ticket.

## The bug

Ticket 11 moved the status label under the row's text at accessibility sizes. There, the "✓ Done" label starts a little in from the leading edge of the time and title above it. The mockup (`docs/mockups/2026-10-21-as-built/`, `.cell .trail` at AX sizes) draws it flush.

`StatusLabel` (`App/Design/StatusComponents.swift`) is a `Label` for Done, with `checkmark.circle.fill` as its icon. Inside a `List`, the label style seems to give the icon a column of its own, wider than the symbol, so the label is indented. Missed, Skipped and Paused are plain text and aren't indented. This is a guess, not yet confirmed.

`StatusLabel` is used on other screens too, so check each one. At the default size the label is trailing, and any extra width there is hard to see.

## What it should do

- [x] At accessibility sizes the Done status label's icon starts at the row text's leading edge, on both simulators, portrait and landscape (`scripts/screenshots.sh`, the `myday` screens).
- [x] Every other screen that shows `StatusLabel` looks as it does now at the default size (screenshots compared with the as-built mockup).
- [x] VoiceOver still reads the status as part of the row.
- [x] The two drifts carried over from ticket 14 (Comments, "Carried over from ticket 14") are reviewed with Brian. For each, he decides: fix it here, file a ticket under the open feature, or no change. His decisions are recorded in Comments.

## Before you start

- Builds on: ticket 11: the status under the row's text at accessibility sizes, the `largest-text-landscape` screenshot variant, and `testMyDay` paging `myday` up to 20 pages (its Comments). Ticket 14: `testMyDay` no longer scrolls back to Filter, which is now always in the bar, and it shoots `myday-filtered` too (its Comments, "tests, review, shots").
- Watch for: the iOS 26.5 simulator can stop turning to landscape. Look at a landscape shot before trusting it. If it's portrait, `xcrun simctl shutdown` that simulator and reshoot, which fixed it in tickets 12 and 14. On iOS 27, `testMyDay` now shoots every variant, `largest-text-landscape` included (ticket 14). Shoot only what you need with `SHOTS_TESTS` and a `SHOTS_OUT` of its own. The dated mockups are never edited. This fix matches the as-built mockup, so no new mockup is needed; if the fix changes what's drawn, make a new dated mockup first. The status is `needs-triage`, and Brian decides whether it's ready.
- Developer stops: `tdd` seams (likely none: a layout fix inside a view, so say so). Simulator shots of `myday` at AX5, portrait and landscape, on both simulators, plus the other `StatusLabel` screens at the default size. The VoiceOver check on the iPhone (criterion 3). Brian's decision on each ticket-14 drift (criterion 4). The offer of an iPhone run.

## Comments

### 2026-10-24: Carried over from ticket 14

Found during ticket 14's review and shots. Neither was that ticket's to fix. Show Brian the evidence for each and let him decide.

- **Filter count color.** My Day's Filter bar button shows the number of tags chosen beside the `tag.filter` icon. The current mockup (`docs/mockups/2026-10-23-tag-filter/`, `.btn.bar.filter-on`) draws the icon and count in the accent color while the filter is on. The app draws them in the bar's monochrome. Landscape already did this before ticket 14, so the drift came from the proposed-pace mockup. Evidence: ticket 14's `myday-filtered` shots, against the mockup with a tag chosen. Options: tint the button while the filter is on, or keep monochrome and draw it that way in a new dated mockup.
- **The Now marker breaks "AM".** At AX5, My Day's Now marker wraps its time mid-word: "Now, / 12:03 A / M". Seen in ticket 14's AX5 `myday-filtered` shots on both simulators (`NowMarkerView`, `App/MyDay/MyDayRows.swift`). It's the same kind of break ticket 11 fixed for the row status.

### 2026-10-24: The fix, the drifts, and the shots

**Cause, confirmed.** Before the fix, the AX5 shot on `iPhone 15 - iOS 27.0` drew the checkmark in from the text's leading edge, with a wide gap before "Done": the `List`'s icon column for a `Label`. Apple's docs don't describe that column in a `List`. The closest they come is iOS 26's `labelReservedIconWidth(_:)`, the width reserved for a label's icon. `StatusLabel` now draws Done as an `HStack` of the checkmark and the word, 4 pt apart (`Design.Spacing.s1`, the as-built mockup's `.state .i { margin-right: 4px }`). The checkmark is hidden from VoiceOver, so the word alone speaks, as the `Label`'s title did. No `tdd` seams: a layout fix inside views.

**Ticket 14's drifts, Brian's decisions (2026-10-24): fix both here.**
- Filter count color: `MyDayFilterButton` is tinted with the accent while a tag is chosen, as the tag-filter mockup draws it. The bar draws its icons monochrome (WWDC25, "Build a SwiftUI app with the new design"). Shots: the icon and count are teal and the + beside them stays black; with no tag chosen the button is black.
- The Now marker: its text has layout priority over the line, which took width the time needed. At AX5 it reads "Now, 9:17 AM" on one line, on both simulators. Both changes bring the app to the mockups, so no new mockup.

**Shots** (`scripts/screenshots.sh`, both simulators):
- Criterion 1: `myday` at `largest-text` and `largest-text-landscape`, flush on both. The iOS 26.5 landscape shots were landscape.
- Criterion 2: Now's Last 24 Hours and default My Day match the as-built mockup (checkmark, 4 pt, word). Details shows Nudging, which is plain text. No shot reaches Details' last-occurrence row or a held `DoneSlot`; both are the same `StatusLabel`.
- Timings for ticket 18. The full walk, four variants, took 61 min on `iPhone 15 Pro - iOS 26.5` alone (portrait 14, landscape 13, largest-text 18, largest-text-landscape 17), so about two hours for both simulators; it was stopped after iOS 26.5. The targeted run took 18 min: `testMyDay` on iOS 26.5 (6 min) and `testMyDay testNow` on iOS 27.0 (13 min), four variants each, one simulator after the other.

**Review** (Standards, Spec, iOS, code smells): no defects. Applied: the doc comment names "enhancement-pace ticket 15" (a first-version ticket 15 is cited elsewhere), Nudging added to the colors it lists, and the VoiceOver comment worded as `StrengthBadge`'s.

### 2026-10-24: VoiceOver on the iPhone

Brian's iPhone (iPhone 15, iOS 27.0.1). The app wasn't installed, so it was installed for the check and uninstalled after. One reminder, "Test", Gentle or Firm, Break Through Focus off, Repeat Never, marked Done on its first nudge, then deleted. The text size started at the default and was put back.

- Default size, My Day: "9:41 AM, Test, Done at 9:41 AM after one nudge, Done, button", then the hint. Pass.
- Default size, Now (Last 24 Hours): "9:41 AM, Today, Test, Done after one nudge, Done, button", then the hint. Pass.
- The largest accessibility size, both screens: the same. Pass.

The checkmark isn't read on its own. Every criterion is ticked.
