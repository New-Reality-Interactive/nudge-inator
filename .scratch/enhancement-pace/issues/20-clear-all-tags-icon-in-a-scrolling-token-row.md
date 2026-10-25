# 20: My Day's filter tokens scroll in one row, and the Filter button's long-press menu clears every tag

**What to build:** On My Day, the chosen-tag tokens sit in one row that scrolls sideways, and the text "Clear" link after them goes. Clearing every tag at once moves to the Filter button: while any tag (or No Tags) is chosen, a long press on it shows a menu with **Clear All Tags**, with a new custom symbol, `tag.xmark` (the same tag as the Filter button's, with a × badge). A tap on the button still opens the filter sheet.

**Blocked by:** 19 (`19-filter-symbol-closer-to-the-tag-symbol`), for ordering only, not for code. Both tickets edit `App/MyDay/MyDayFilterControls.swift` and `docs/design/DESIGN.md`, so build this one after 19 has merged.

**Status:** ready-for-agent

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

Revised by Brian on 2026-10-25 (Comments): the pinned clear button in the row was replaced by the long-press menu.

- **One row, scrolls sideways:** the tokens sit in a single row of the same 44 pt capsules. The row scrolls horizontally; the counts and everything below stay put.
- **Fade:** the tokens fade out at the row's trailing edge while there are more to scroll to.
- **Long-press menu:** the Filter button becomes a SwiftUI `Menu` with a `primaryAction`: a tap opens the filter sheet as today, and a long press shows the menu (Apple's `Menu` docs, "Primary action"). The menu has one item, **Clear All Tags**, with `tag.xmark`, which calls the existing `clearTags()`. It's there only while a tag or No Tags is chosen; with none, the button stays a plain button and a long press does nothing.
- **Summary line:** the line under the row stays. It names every chosen tag, so nothing is hidden when the row has scrolled.
- **Each token's ×** still removes just that tag.
- **Rejected, for the record:** a text link; a pinned `tag.xmark` button at the row's end (mocked on 2026-10-25, dropped by Brian for the menu); `xmark.circle.fill` (says "remove" but not what); `tag.slash` (could be mistaken for the No Tags filter token). The first version of this ticket rejected a long-press menu because nobody finds it; Brian chose it anyway, as each token's × still clears tags one by one.

## The symbol

- **Source:** `~/Downloads/tag.xmark.svg`, exported by Brian from the SF Symbols app (File → Export Symbol). Template v7.0, SF Symbols' default annotations, one path per weight.
- **Design:** Apple's own `tag` outline plus a × badge at the lower right, with a circular cutout in the tag where the badge sits. It uses the same tag and the same cutout approach as `tag.filter` (ticket 19), so the two read as a pair. The tag's narrow, dotted end is at the upper right, as in `tag.filter`.
- **Checked so far:** `actool` compiles it with no errors or warnings, including with the deployment target at iOS 26.1. It renders correctly at all nine weights, so the three sources (Ultralight-S, Regular-S, Black-S) interpolate.
- **Where it shows:** the icon of the Filter menu's Clear All Tags item.
- **What the build does:** copy that SVG into `App/Resources/Assets.xcassets/tag.xmark.symbolset/` with a `Contents.json` like `tag.filter.symbolset`'s (one universal `tag.xmark.svg`), and load it with `Image("tag.xmark")`. If the file isn't in `~/Downloads`, stop and ask Brian. Don't redraw it.

## What it should do

- [ ] `tag.xmark.symbolset` is in the asset catalog, `actool` compiles the catalog with no errors or warnings, and `scripts/test.sh` passes.
- [ ] The token strip is one scrolling row, and the Clear text is gone. With six tags chosen, the counts below don't move down. Shot on both simulators, in portrait and landscape, at the default and the largest text size.
- [ ] While a tag or No Tags is chosen, a long press on the Filter button shows a menu with Clear All Tags (`tag.xmark`), and one tap on it removes every tag and No Tags. A tap on the button still opens the filter sheet. With none chosen, a long press shows no menu. A UI test on both simulators, then the iPhone.
- [ ] The Filter button as a `Menu` keeps ticket 19's behaviour: the badge follows the count as tags are removed (including by Clear All Tags), and is hidden at the accessibility text sizes. Shot on both simulators.
- [ ] VoiceOver still reads the Filter button as "Filter by Tags" with its "N chosen" value, Clear All Tags can be reached with VoiceOver, the tokens read as they do today, and the group is still "Filtering by". Device check.
- [ ] At accessibility text sizes a single scrolling row may be a poor fit, because the tokens get large. Decide, with shots, whether the row keeps scrolling or goes back to wrapping at those sizes, and record the decision in Comments. This is the criterion most likely to need Brian's call.
- [ ] `docs/design/DESIGN.md` shows the new row, the Filter button's long-press menu and the `tag.xmark` icon: its Filter token entry (Tags section), the Filter button's entry and its symbol table.
- [x] The Filter-badge mockup, `docs/mockups/2026-10-24-filter-badge/`, is extended with the new row: the scrolling tokens, the fade, the summary line, and the Filter button's long-press menu. Don't make a second mockup, and leave the older dated mockups as they are. Brian approves the mockup before any app code changes. Its README lists what changed.

## Before you start

- Apple platform questions go through `apple-rag-mcp` (AGENTS.md). The relevant pages are "Creating custom symbol images for your app" and the Human Interface Guidelines' search field and token guidance.
- Builds on: ticket 19 (the `tag.filter` symbol and its mockup) and ticket 14 (the filter tokens and the bar's Filter button). From 19's Comments: `tag.filter.svg` was redrawn with a circular cutout and is the pattern for `tag.xmark.symbolset`. `docs/mockups/2026-10-24-filter-badge/` is approved and in the tree, so extend it, with its `tag` mirrored so the dotted end is at the upper right. Its `tag.filter` is a stand-in drawing, not the exported SVG. The Filter button's count is the system's red `.badge(chosen)`. The harness has `BadgeBarShot` and `testMyDayFilterBadge` for counts that tapping can't reach. 19's shots ran with `SHOTS_TESTS="testMyDay testMyDayFilterBadge"`.
- Watch for: at the largest text size the iOS 27 badge grows over the Filter icon, and the iOS 26.5 one doesn't (19's shots). Brian kept the system badge at every size, so it isn't this ticket's to fix, but the row of tokens sits under it. `~/Downloads/tag.xmark.svg` was there on 2026-10-24.
- `FlowLayout` is also used by `App/MyDay/MyDayCounts.swift`, so it stays; only the token strip stops using it. The "Clear" string at the token strip goes with the button. The filter sheet's "Clear" is a separate use and stays.
- Developer stops:
  - `tdd` seams: none. `clearTags()` is already covered by `NudgeInatorTests/MyDayFilterTests.swift`, and the rest is a symbol, a menu and a layout change. Say so.
  - The extended mockup, made first and approved by Brian before any code changes (a mockup has no behaviour, so it skips `tdd`; say so).
  - Simulator shots of `myday-filter` on both simulators, in portrait and landscape, at the default and the largest text size, with six tags chosen.
  - Brian's call on the layout at accessibility text sizes.
  - The offer of an iPhone run, for the VoiceOver check.
- Watch for: the iOS 26.5 simulator can stop turning to landscape. Look at a landscape shot before trusting it (ticket 15, Comments).

## Comments

### 2026-10-25: The mockup is extended, waiting for Brian

- Started by `/implement` while the Status was still `needs-triage`; taken as Brian's go.
- `tdd` seams: none, as the ticket says. `clearTags()` is already covered by `NudgeInatorTests/MyDayFilterTests.swift`, and the rest is a symbol and a layout change. The mockup has no behaviour, so it skips `tdd` too.
- `docs/mockups/2026-10-24-filter-badge/` is extended, not copied (the ticket overrides the usual new-mockup rule here): one scrolling token row, the pinned `tag.xmark` button ("Clear all tags"), the trailing fade while more tokens are off the edge, the summary line as before. Its README's "What changed for ticket 20" lists it. A new control, **Tokens at the accessibility sizes**, switches AX1 to AX5 between scrolling and wrapping, for the accessibility-size decision.
- `scripts/mockup-shots.py` gained `myday-tokens-6` and `myday-tokens-6-wrap`. Checked in headless Chrome in portrait, landscape and AX5: six tags stay in one row with the button pinned and the fade under it; the counts stay put. With wrap at AX5 the six tokens take six lines and push the counts off the first screen.
- No app code, symbol or test has changed. Stopped for Brian's approval of the mockup.

### 2026-10-25: Brian's first look at the mockup

- **Couldn't scroll the tags:** a desktop browser doesn't scroll a row sideways with a plain wheel or a drag. The mockup now drags with the mouse and turns a vertical wheel into a sideways scroll; a drag doesn't tap a token. Checked in headless Chrome: a drag scrolled the row to its end, and the fade went there.
- **The button looked small, and maybe should look like a button:** it's now a 44 pt circle with a 26 pt icon (was 24). A new control, **Clear All Tags button**, switches between the system styles the app could use: bordered circle (`.bordered` with `.buttonBorderShape(.circle)`, the default), prominent circle (`.borderedProminent`), glass (`.glass`), and the plain icon. The docs confirm those styles and the circle shape. They don't say whether glass suits a button in the content rather than a bar.
- Waiting for Brian to pick a style and approve the mockup.

### 2026-10-25: Brian changed the design to a long-press menu

- After trying the pinned button in the mockup, Brian chose a long-press menu on the Filter button with an option to clear the tags while any are chosen. Asked about the rest: the tokens still scroll in one row, and the Clear link is removed, so the menu is the one way to clear them all at once. Agreed with Brian: the title, What to build, the design and the criteria above are rewritten to match.
- Criteria changed: "the pinned button clears every tag…, 44 pt" became the long-press menu criterion; "the pinned icon is clearly different from each token's small ×" is dropped, as there is no icon in the row; a new criterion keeps ticket 19's badge behaviour now that the button is a `Menu`; the VoiceOver, DESIGN.md and mockup criteria name the menu instead of the button. `tag.xmark` stays, as the menu item's icon (my call; say if a system symbol is wanted instead).
- Docs: Apple's `Menu` page confirms that with a `primaryAction` a tap runs the action and a long press shows the menu, on iOS too (also WWDC21, "What's new in SwiftUI"). Not documented: whether `.badge` and the `.id(badgeCount)` fix behave the same on a `Menu` in the toolbar, and how VoiceOver reaches its menu. Both are checks under the criteria above.
- Status set to `ready-for-agent`: Brian started `/implement` on it and chose the design.
- Mockup updated: the pinned button and its style control are gone; a long press (or a right-click, for a mouse) on the Filter button while tags are chosen shows an anchored menu with Clear All Tags. Checked in headless Chrome: the press shows the menu without opening the sheet, Clear All Tags removes all six tags, and focus goes back to the Filter button. Waiting for Brian's approval.
- Menu item layout: Brian asked whether the icon after the text is standard. The HIG's Menus page and UIKit's menu docs don't say which side. WWDC25, "Get to know the new design system", gives the iOS 26 menu's anatomy as "selection indicator, icon, label, and accessory item", the Mac's layout, which points to the icon first. The mockup now puts it before the text (Brian's call). The app uses the system `Menu`, so the iOS 26.5 and iOS 27.0 shots show where it really goes; record that when they're taken.

### 2026-10-25: Brian approved the mockup

- Brian approved `docs/mockups/2026-10-24-filter-badge/` as extended for this ticket: the one scrolling row with its fade, no Clear link, and the Filter button's long-press menu with Clear All Tags, its icon before the text. The mockup criterion is ticked. App code starts now.
