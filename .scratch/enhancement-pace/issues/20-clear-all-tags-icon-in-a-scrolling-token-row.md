# 20: My Day's filter tokens scroll in one row, with a pinned icon that clears every tag

**What to build:** On My Day, the chosen-tag tokens sit in one row that scrolls sideways, and the text "Clear" link after them is replaced by a single pinned icon button at the row's trailing end. The icon is a new custom symbol, `tag.xmark`: the same tag as the Filter button's, with a × badge, so it reads as "remove tags". One tap on it removes every chosen tag and No Tags from the filter.

**Blocked by:** 19 (`19-filter-symbol-closer-to-the-tag-symbol`), for ordering only, not for code. Both tickets edit `App/MyDay/MyDayFilterControls.swift` and `docs/design/DESIGN.md`, so build this one after 19 has merged.

**Status:** needs-triage

Raised by Brian, 2026-10-24. Brian decides whether it's ready.

## Today

`MyDayFilterTokens` (`App/MyDay/MyDayFilterControls.swift`):

- The tokens are laid out in a `FlowLayout`, so six tags wrap to three rows and push the counts down the screen.
- A text "Clear" button follows the tokens from two chosen tags on. Brian doesn't like the word as a link at the end of the last row.
- Each token is a 44 pt capsule with a small ×, and the × removes just that tag. That stays as it is.
- Under the tokens, from two tags on, a summary line ("Due today with #health and #work") names every chosen tag.
- The group reads to VoiceOver as "Filtering by".

The filter sheet's bar also has a "Clear" button (`App/MyDay/MyDayFilterSheetView.swift`). It stays as it is.

## The design Brian chose

- **One row, scrolls sideways:** the tokens sit in a single row of the same 44 pt capsules. The row scrolls horizontally; the counts and everything below stay put.
- **Pinned clear button:** a 44 pt button at the trailing end shows `tag.xmark` in the accent color. It removes every tag and No Tags from the filter by calling the existing `clearTags()`. It still appears only from two chosen tags on.
- **Fade:** the tokens fade out under the pinned button where they run out of room.
- **Summary line:** the line under the row stays. It names every chosen tag, so nothing is hidden when the row has scrolled.
- **Rejected, for the record:** a text link; `xmark.circle.fill` (says "remove" but not what); `tag.slash` (could be mistaken for the No Tags filter token); a long-press menu only (nobody finds it).

## The symbol

- **Source:** `~/Downloads/tag.xmark.svg`, exported by Brian from the SF Symbols app (File → Export Symbol). Template v7.0, SF Symbols' default annotations, one path per weight.
- **Design:** Apple's own `tag` outline plus a × badge at the lower right, with a circular cutout in the tag where the badge sits. It uses the same tag and the same cutout approach as `tag.filter` (ticket 19), so the two read as a pair. The tag's narrow, dotted end is at the upper right, as in `tag.filter`.
- **Checked so far:** `actool` compiles it with no errors or warnings, including with the deployment target at iOS 26.1. It renders correctly at all nine weights, so the three sources (Ultralight-S, Regular-S, Black-S) interpolate.
- **What the build does:** copy that SVG into `App/Resources/Assets.xcassets/tag.xmark.symbolset/` with a `Contents.json` like `tag.filter.symbolset`'s (one universal `tag.xmark.svg`), and load it with `Image("tag.xmark")`. If the file isn't in `~/Downloads`, stop and ask Brian. Don't redraw it.

## What it should do

- [ ] `tag.xmark.symbolset` is in the asset catalog, `actool` compiles the catalog with no errors or warnings, and `scripts/test.sh` passes.
- [ ] The token strip is one scrolling row, and the Clear text is gone. With six tags chosen, the counts below don't move down. Shot on both simulators, in portrait and landscape, at the default and the largest text size.
- [ ] The pinned button clears every tag and No Tags in one tap, only shows from two chosen tags on, and has a hit area of at least 44 pt.
- [ ] VoiceOver reads the button as "Clear all tags" (button), the tokens read as they do today, and the group is still "Filtering by". Device check.
- [ ] At accessibility text sizes a single scrolling row may be a poor fit, because the tokens get large. Decide, with shots, whether the row keeps scrolling or goes back to wrapping at those sizes, and record the decision in Comments. This is the criterion most likely to need Brian's call.
- [ ] The pinned icon is clearly different from each token's small ×, in both light and dark. Looked at in the shots.
- [ ] `docs/design/DESIGN.md` shows the new row and the `tag.xmark` icon: its Filter token entry (Tags section) and its symbol table.
- [ ] The Filter-badge mockup, `docs/mockups/2026-10-24-filter-badge/`, is extended with the new row: the scrolling tokens, the pinned `tag.xmark` button, the fade, and the summary line. Don't make a second mockup, and leave the older dated mockups as they are. If that mockup isn't in the tree when this is built, make it here as `docs/mockups/2026-10-24-…/`. Brian approves the mockup before any app code changes. Its README lists what changed.

## Before you start

- Apple platform questions go through `apple-rag-mcp` (AGENTS.md). The relevant pages are "Creating custom symbol images for your app" and the Human Interface Guidelines' search field and token guidance.
- Builds on: ticket 19 (the `tag.filter` symbol and its mockup) and ticket 14 (the filter tokens and the bar's Filter button).
- `FlowLayout` is also used by `App/MyDay/MyDayCounts.swift`, so it stays; only the token strip stops using it. The "Clear" string at the token strip goes with the button. The filter sheet's "Clear" is a separate use and stays.
- Developer stops:
  - `tdd` seams: none. `clearTags()` is already covered by `NudgeInatorTests/MyDayFilterTests.swift`, and the icon is a symbol and a layout change. Say so.
  - The extended mockup, made first and approved by Brian before any code changes (a mockup has no behaviour, so it skips `tdd`; say so).
  - Simulator shots of `myday-filter` on both simulators, in portrait and landscape, at the default and the largest text size, with six tags chosen.
  - Brian's call on the layout at accessibility text sizes.
  - The offer of an iPhone run, for the VoiceOver check.
- Watch for: the iOS 26.5 simulator can stop turning to landscape. Look at a landscape shot before trusting it (ticket 15, Comments).

## Comments
