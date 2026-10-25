# 23: Checking a second tag in the filter sheet doesn't move the tags under the finger

**What to build:** In My Day's filter sheet, the Match choice (All Tags / Any Tag) is always shown above the tags, and disabled until two or more are checked, with the Tags footer saying why. Nothing appears or goes above the tag rows, so they stay where they are while the person checks and unchecks tags, checks No Tags, or taps Clear, and the next tap lands on the tag the person aimed at.

**Blocked by:** 20. Its code doesn't touch the sheet, but it edits the mockup this ticket copies (`docs/mockups/2026-10-24-filter-badge/`), and its `openMyDayFilter()` opens the sheet through the new Filter menu, which this ticket's shots use.

**Status:** ready-for-agent

Found by Brian on his iPhone 15, iOS 27.0.1, 2026-10-25, during ticket 20's device checks. Brian decides the design and whether it's ready.

## The problem

`MyDayFilterSheetView` shows the Match section above the Tags section only while two or more tags are checked (`MyDayFilterSheet.showsMatch`). Checking the second tag inserts that section above the list, so every tag row moves down by a section's height while the person is still tapping. Brian's next tap unchecked a tag he hadn't meant to.

It happens the other way too. Unchecking down to one tag, checking No Tags (`toggleNoTags()` empties the tags) or tapping the bar's Clear removes the section, and every row moves up.

## The design (Brian, 2026-10-25)

- **Match is always shown,** in its own section above Tags, as today when two tags are checked.
- **Disabled below two tags:** with none or one tag checked, or No Tags checked, the picker is disabled and keeps showing the current choice. From two tags on it works as today.
- **The Tags footer says why:** below two tags it explains that Match needs two or more tags (wording agreed in the mockup, in place of "Check one or more tags."). From two tags on it keeps "All Tags shows reminders with every checked tag. Any Tag shows those with at least one."

Rejected: moving Match below the tags. With many tags it would be off screen, and it would separate Tags from No Tags.

This changes what's on screen, so it gets a new dated mockup first. The dated mockups stay as they are.

## What it should do

- [x] Checking or unchecking any tag, checking or unchecking No Tags, and Clear leave every tag row where it was on screen. A UI test on both simulators compares each tag row's frame before and after each of those taps, starting from one tag and from two.
- [x] Match is shown with none, one or two tags checked, and with No Tags. It's disabled below two tags and with No Tags, and works from two tags on. Shots of each, on both simulators, in portrait and landscape, at the default and the largest text size (where Match is a menu), light and dark.
- [x] Match still chooses All Tags or Any Tag from two tags on, and the sheet's summary follows it. `MyDayFilterSheet` says whether Match can be used and which footer the Tags section shows, unit-tested in `MyDayScreenTests`, whose filter sheet test replaces its `showsMatch` checks.
- [x] The Tags footer below two tags says why Match is disabled, in the wording Brian approved in the mockup, with a translator comment.
- [ ] VoiceOver reads the Match choice and its current value, says it's dimmed below two tags, and reads the footer's reason. Device check.
- [x] `docs/design/DESIGN.md` (Tags › Match control) and a new dated mockup show Match always shown and disabled below two tags. Brian approves the mockup before any app code changes.

## Before you start

- Builds on: ticket 20 (merged in #64): the `2026-10-24-filter-badge` mockup as it left it, and `openMyDayFilter()` in `ShotsUITests`, which opens the sheet through the Filter menu once tags are chosen (its Comments, "Built to the revised design").
- Watch for: the harness's `tapText` scrolls only down, so tags are checked in A to Z order (ticket 20's Comments, "Shots; a clipping fix"); landscape and the largest size need it.
- Today the Match section's `if sheet.showsMatch` sits first in the sheet's `List`, and the Tags footer switches text on the same flag. The section stays first and loses its `if`; the footer still switches, but it sits below the rows, so a longer footer doesn't move them.
- `matchPicker` is a segmented `Picker`, a `.menu` at accessibility sizes. `.disabled` goes on the picker in both styles. Check `apple-rag-mcp` for how VoiceOver reads a disabled `Picker` and how a disabled segmented one is drawn before relying on it; where the docs are silent, it's the device check.
- `clearTags()` resets Match to All, and Clear stays disabled with no tags. Keep both.
- The mockup: copy `2026-10-24-filter-badge` as ticket 20 leaves it to a new dated folder, changed only for the filter sheet. In `dayFilterSheet()`, `f.ids.length > 1 ? matchControl(...)` is the same insert as the app's: draw it always, disabled below two tags, and change the Tags footer to match.
- Screenshot harness: `testMyDay` shoots `myday-filter` with nothing checked, then checks `#health`. Shoot the sheet with one tag (Match disabled) and with two (Match working).
- Developer stops, in this order:
  - Approval of the new mockup, with the footer's wording.
  - `tdd` seam to agree: the `MyDayFilterSheet` property that replaces `showsMatch` (whether Match can be used). Propose it before the first test.
  - Simulator check: the shots above, on both simulators.
  - Device check on the iPhone: checking tags quickly in a row lands each tap on the tag aimed at; VoiceOver on the Match choice.

## Comments

- 2026-10-25: reviewed and rewritten to the ticket format (Claude). Added: the other taps that move the rows (unchecking to one tag, No Tags, Clear); blocked by 20 for the mockup and `openMyDayFilter()`; a UI test that compares row frames; the unit test's change; Before you start. Option 2 is recommended, not decided. Status stays `needs-triage` until Brian chooses.
- 2026-10-25, Brian: chose option 2, Match always shown and disabled below two tags. The options section is replaced by The design, and the criteria are rewritten for it. Status `ready-for-agent`.
- 2026-10-25, Brian: approved the mockup `docs/mockups/2026-10-25-match-always-shown` and the footer below two tags, "Check one or more tags. Match needs two or more." Agreed seam: `MyDayFilterSheet.canChooseMatch` and `tagsFooter` replace `showsMatch`.
- 2026-10-25: found by the row-frame test at the largest text size, both simulators: scrolled to the end of the sheet, No Tags (from two tags) shortened the Tags footer and the summary, so the list scrolled back and every row moved down 35 pt. Brian chose to keep the content from ever getting shorter while the sheet is open: `MyDayFilterSheetView.NeverShorter` adds blank space under the summary to make up the difference, starting again when the width changes. It shows only at the end of the list, below the summary.
- 2026-10-25: shots and tests on both simulators (iPhone 15 Pro - iOS 26.5, iPhone 15 - iOS 27.0), in portrait, landscape and the largest text size, light and dark (`testMyDayFilterMatch`, `testMyDayFilterRowsStayPut`): Match dimmed with no tag, one tag and No Tags, working with two; every tag row stays put. The test log has Match disabled below two tags (`ACCESSIBILITY Match` lines). Apple's docs (`disabled(_:)`) confirm it stops interaction; they don't say how VoiceOver reads a disabled `Picker`, so that's the device check.

### 2026-10-25: iPhone check list (for a fresh session)

Brian has the iPhone ready. Follow `docs/agents/device-testing.md`: note whether the app is installed first; one check at a time, waiting for Brian's go before each; record the phone and iOS version. Build from this branch (`2b502c9` or later). Every criterion except VoiceOver is ticked; these checks close it and the device items from the review.

1. **Taps land (the bug):** in My Day's filter sheet, check three or four tags quickly in a row; each tap lands on the tag aimed at, crossing two tags both ways (checking the second, unchecking down to one), after No Tags and after Clear. At the default and the largest text size.
2. **VoiceOver (criterion 5):** with none or one tag checked, and with No Tags, VoiceOver reads Match, its current value (All Tags) and that it's dimmed, then the footer's reason ("Check one or more tags. Match needs two or more."). With two tags it isn't dimmed and switches All Tags / Any Tag. At the default size (segmented) and at an accessibility size (menu). If it doesn't say dimmed, or the reason isn't reachable near Match, stop and discuss (the iOS review suggested an `.accessibilityHint` on the disabled picker).
3. **No jump at the scroll end (`NeverShorter`):** at the largest text size, check two tags, scroll to the end, tap No Tags; the rows don't move, not even for a frame. Then close the sheet, reopen it and make No Tags the first tap: still no move.
4. **Blank space:** after check 3, the space under the summary isn't odd to look at, and VoiceOver's focus box on the summary line isn't stretched by it in a way that confuses. Turning the phone or changing the text size with the sheet open clears it.
