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

- [ ] Checking or unchecking any tag, checking or unchecking No Tags, and Clear leave every tag row where it was on screen. A UI test on both simulators compares each tag row's frame before and after each of those taps, starting from one tag and from two.
- [ ] Match is shown with none, one or two tags checked, and with No Tags. It's disabled below two tags and with No Tags, and works from two tags on. Shots of each, on both simulators, in portrait and landscape, at the default and the largest text size (where Match is a menu), light and dark.
- [ ] Match still chooses All Tags or Any Tag from two tags on, and the sheet's summary follows it. `MyDayFilterSheet` says whether Match can be used and which footer the Tags section shows, unit-tested in `MyDayScreenTests`, whose filter sheet test replaces its `showsMatch` checks.
- [ ] The Tags footer below two tags says why Match is disabled, in the wording Brian approved in the mockup, with a translator comment.
- [ ] VoiceOver reads the Match choice and its current value, says it's dimmed below two tags, and reads the footer's reason. Device check.
- [ ] `docs/design/DESIGN.md` (Tags › Match control) and a new dated mockup show Match always shown and disabled below two tags. Brian approves the mockup before any app code changes.

## Before you start

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
