# 20: My Day's filter tokens wrap to at most three rows, and the Filter button's menu clears every tag

**What to build:** On My Day, the chosen-tag tokens wrap to at most three rows; tokens past that go into a "+N more" token that opens the filter sheet. The text "Clear" link after them goes. Clearing every tag at once moves to the Filter button: while any tag (or No Tags) is chosen, a tap on it shows a menu with **Filter by Tags** and **Clear All Tags**, the second with a new custom symbol, `tag.xmark` (the same tag as the Filter button's, with a × badge). The summary line under the tokens says Match All or Any without naming the tags.

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

Revised by Brian twice on 2026-10-25 (Comments): first the pinned clear button became a long-press menu, then, after the app's shots, the long press became a tap and the sideways row became wrapping rows.

- **Wrapping, at most three rows:** the tokens are the same 44 pt capsules and wrap as today, but to at most three rows. When more don't fit, the last ones are left out and a **+N more** token ends the third row; a tap on it opens the filter sheet, which lists every tag. If it doesn't fit beside the third row's only token, it takes a row of its own below, so three tags still show at the largest text size. Nothing scrolls inside My Day's list (the HIG's Scroll views page warns against nesting scroll views of the same orientation).
- **The Filter button's menu:** while any tag (or No Tags) is chosen, the Filter button is a SwiftUI `Menu`, and a tap shows it: **Filter by Tags** (`tag.filter`) opens the filter sheet, **Clear All Tags** (`tag.xmark`) calls the existing `clearTags()`. With none chosen it stays a plain button that opens the sheet. No long press: at the accessibility sizes the bar's long press shows the Large Content Viewer, and lifting the finger acts as a tap (WWDC19, "Large Content Viewer"; the app's shots on both simulators).
- **Summary line:** from two tags on, "Due today with all selected tags" (Match All) or "Due today with any selected tags" (Match Any). It no longer names the tags (Brian: redundant beside the tokens). With one tag, "Due today with the selected tag" (Match doesn't apply). With No Tags chosen, "Due today with no tags", so every filter has a line.
- **Each token's ×** still removes just that tag.
- **Rejected, for the record:** a text link; a pinned `tag.xmark` button at the row's end (mocked on 2026-10-25, dropped by Brian for the menu); a long-press menu with a primary action (unreachable at the accessibility sizes); one row scrolling sideways (at the largest size it showed one and a half tokens); three rows scrolling vertically (nested same-axis scroll, against the HIG); `xmark.circle.fill` (says "remove" but not what); `tag.slash` (could be mistaken for the No Tags filter token).

## The symbol

- **Source:** `~/Downloads/tag.xmark.svg`, exported by Brian from the SF Symbols app (File → Export Symbol). Template v7.0, SF Symbols' default annotations, one path per weight.
- **Design:** Apple's own `tag` outline plus a × badge at the lower right, with a circular cutout in the tag where the badge sits. It uses the same tag and the same cutout approach as `tag.filter` (ticket 19), so the two read as a pair. The tag's narrow, dotted end is at the upper right, as in `tag.filter`.
- **Checked so far:** `actool` compiles it with no errors or warnings, including with the deployment target at iOS 26.1. It renders correctly at all nine weights, so the three sources (Ultralight-S, Regular-S, Black-S) interpolate.
- **Where it shows:** the icon of the Filter menu's Clear All Tags item.
- **What the build does:** copy that SVG into `App/Resources/Assets.xcassets/tag.xmark.symbolset/` with a `Contents.json` like `tag.filter.symbolset`'s (one universal `tag.xmark.svg`), and load it with `Image("tag.xmark")`. If the file isn't in `~/Downloads`, stop and ask Brian. Don't redraw it.

## What it should do

- [x] `tag.xmark.symbolset` is in the asset catalog, `actool` compiles the catalog with no errors or warnings, and `scripts/test.sh` passes.
- [ ] The tokens wrap to at most three rows, and the Clear text is gone. With six tags chosen at the largest text size, at least three tags show, one per row at most, and "+N more" ends the third row, or sits below it when it doesn't fit beside the third row's only token; a tap on it opens the filter sheet. With six tags at the default size, all six show and there is no "+N more". Shot on both simulators, in portrait and landscape, at the default and the largest text size.
- [x] The summary line reads "Due today with all selected tags" or "…any selected tags", by the Match setting, from two tags on; "Due today with the selected tag" with one; "Due today with no tags" with No Tags; and no line with no filter. Unit-tested in `MyDayScreenTests`.
- [ ] While a tag or No Tags is chosen, a tap on the Filter button shows a menu with Filter by Tags (`tag.filter`) and Clear All Tags (`tag.xmark`), at every text size including the largest. Filter by Tags opens the sheet; Clear All Tags removes every tag and No Tags. With none chosen, a tap opens the sheet. A UI test on both simulators, then the iPhone.
- [ ] The Filter button as a `Menu` keeps ticket 19's behaviour: the badge follows the count as tags are removed (including by Clear All Tags), and is hidden at the accessibility text sizes. Shot on both simulators.
- [ ] VoiceOver still reads the Filter button as "Filter by Tags" with its "N chosen" value, both menu items can be reached with VoiceOver, the tokens read as they do today, "+N more" reads as "N more tags", and the group is still "Filtering by". Device check.
- [x] `docs/design/DESIGN.md` shows the wrapping rows with "+N more", the Filter button's menu, the summary line and the `tag.xmark` icon: its Filter token entry (Tags section), the Filter button's entry and its symbol table.
- [x] The Filter-badge mockup, `docs/mockups/2026-10-24-filter-badge/`, is extended with the new design: the three-row cap with "+N more", the summary line, and the Filter button's tap menu. Don't make a second mockup, and leave the older dated mockups as they are. Brian approves the mockup before any app code changes. Its README lists what changed.

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

### 2026-10-25: Built, reviewed; paused overnight

- Built (uncommitted on the branch): `tag.xmark.symbolset` (`actool` clean at iOS 26.1); `MyDayFilterButton` is a `Menu` with a `primaryAction` while a tag or No Tags is chosen, else a `Button`, with `.badge`, `.id`, `.tint` and the accessibility label and value over both; `MyDayFilterTokens` is one horizontal `ScrollView` with an `onScrollGeometryChange` fade and no Clear; DESIGN.md's Filter token, Filter button and symbol entries; the catalog synced ("Clear All Tags" added, the token strip's "Clear" comment gone). New shot test `testMyDayClearAllTags`. `scripts/test.sh` passed on both simulators before the catalog sync; the catalog check passed after it.
- Shots: `SHOTS_TESTS="testMyDayClearAllTags testMyDayFilterBadgeFollowsTokens testMyDayFilterBadge"`, all four variants, into `docs/screenshots/2026-10-25-ticket-20/` (git-ignored). A SpringBoard crash in Apple's `XCTAutomationSupport` (seen in every run since 2026-10-23) hit between portrait and landscape; the run carried on. Check every variant's shots, the log at `.build/test-logs/screenshots-*`.
- Review (Standards, Spec, iOS, smells): no hard violations. To do: a fixed 32 pt fade as in the mockup (now 10% of the row) and a comment on the 1 pt tolerance; tidy `testMyDayClearAllTags` (one closure for the menu shot, a check that a long press with none chosen shows no menu, the badge and value after Clear All Tags, the comment over the tap check). From the shots: the badge on the `Menu`, the long press in landscape, the menu icon's side (record it), whether the row reaches the screen edge as in the mockup.
- Then: rerun `scripts/test.sh`, commit; Brian's call on scroll vs wrap at the accessibility sizes; offer the iPhone run (VoiceOver: the Filter button's label and value, and how Clear All Tags is reached; if it can't be, add `.accessibilityAction(named:)`); PR.

### 2026-10-25: What the shots found

The run exited 1: `testMyDayClearAllTags` failed in `largest-text` and `largest-text-landscape` on both simulators. Portrait and landscape passed on both.

- **Long press at the largest text size opens the sheet, not the menu (both simulators, portrait and landscape).** The `myday-filter-menu` shot shows the Filter My Day sheet, and "Clear All Tags" never appeared. The likely cause, not yet confirmed in Apple's docs: at the accessibility sizes, a long press on a bar button shows the Large Content Viewer, and lifting the finger activates the button. So at those sizes Clear All Tags can't be reached from the menu. The filter sheet's own Clear still works. **Needs Brian's call:** for example, accept the sheet's Clear at those sizes, or show a clear control in the token row only there. Look it up in `apple-rag-mcp` (Large Content Viewer, `accessibilityShowsLargeContentViewer`) first.
- **Landscape:** the long press opened the menu in landscape on both simulators (no portrait fallback was needed).
- **Menu icon side:** the real system menu puts `tag.xmark` before "Clear All Tags" (iOS 27.0 simulator, portrait), as in the mockup. Still to check on iOS 26.5.
- **Row:** the tokens run to the screen edge and fade there (iOS 27.0, portrait), as in the mockup.
- **Harness flake:** the test chose only 5 tags in some variants ("5 chosen"), because `tapText` missed `#appointments`: at the largest size it wraps to "#appoint-ments", and once (27.0, largest-text-landscape) it wasn't found at all. Choose tags that are reachable, or check the count before the long press.
- The SpringBoard crash in `XCTAutomationSupport` happened once, between portrait and landscape. It didn't fail a variant.

### 2026-10-25: Brian changed the design again: a tap menu and three wrapping rows

- **Large Content Viewer:** WWDC19 "Large Content Viewer" confirms that at the accessibility sizes a long press on a standard bar's button shows the viewer, and lifting the finger acts as a tap. Its advice for a button with its own long press is a longer press. The docs don't say whether SwiftUI's `Menu` does that. Brian chose to follow Apple's standards with a plain menu: with tags chosen, a tap shows **Filter by Tags** and **Clear All Tags**, at every size.
- **Accessibility-size layout (the criterion that asked for Brian's call):** decided, and folded into the new layout criterion. Brian asked for at most three rows, at least three tags visible at the largest size, at every size. His first idea was to scroll them vertically. The HIG's Scroll views page says "Nesting scroll views that have the same orientation can create an unpredictable interface that's difficult to control", and My Day's list scrolls vertically, so Brian chose a "+N more" token that opens the filter sheet instead.
- **Summary line:** Brian asked for the tag names to go from it, as they repeat the tokens. It's the only place on My Day that shows Match All against Any, so it stays as "Due today with all selected tags" / "…any selected tags", from two tags on (Brian's wording).
- **Criteria changed:** the scrolling-row criterion became the three-row criterion; a new summary-line criterion; the long-press criterion became the tap-menu criterion; the accessibility-size criterion is dropped as decided (above); VoiceOver adds the second item and "+N more"; DESIGN.md and the mockup name the new design. The mockup criterion is unticked until Brian approves it again.
- **Seen in the shots:** the system menu puts the icon before the text on both simulators. On iOS 26.5 it draws `tag.xmark` in system blue, not the app's teal; on 27.0 it's black. Not this ticket's to change unless Brian says so.
- **Mockup updated:** wrapping rows capped at three with "+N more", the tap menu with both items, the new summary line; the sideways drag, fade and accessibility-size control are gone. `scripts/mockup-shots.py`: `myday-tokens-6-wrap` became `myday-filter-menu`. Checked in headless Chrome: at the largest size four tokens and "+2 more" fill three rows; a tap shows the menu. Waiting for Brian's approval.
- **`tdd` seams to agree, once approved:** the summary text (`MyDayScreenTests`, existing tests change), and a pure function for how many tokens fit in three rows given their widths and the "+N more" width (new tests). The Filter menu stays a UI test.

### 2026-10-25: Mockup approved; No Tags gets a summary line

- Brian approved the mockup as revised above, and the two `tdd` seams (the summary text; how many tokens fit in three rows). The mockup criterion is ticked again.
- Brian, from `docs/screenshots/my-day-reminders-no-tags.png`: with No Tags chosen My Day showed the token but no line under it, unlike with tags. The line now says "Due today with no tags" there (no final period, like the other summary lines). The design and the summary criterion above include it, and the mockup draws it.

### 2026-10-25: Built to the revised design; reviewed

- `tdd`, the two agreed seams: `MyDayScreenTests.theChosenTagsShowAsTokensWithASummaryLine` (all, any, no tags; red, then green) and the new `FlowLayoutTests` for `FlowLayout.shownCount` (red, then green).
- **"+N more" on its own row (my call, from Brian's "at least 3 tags, one in each row"):** when "+N more" doesn't fit beside the third row's only token, it goes on a row of its own rather than taking that token's place, so three tags show at the largest size. The design and the layout criterion above say so now, and the mockup's `capTokens` does the same. Brian to confirm.
- `MyDayFilterTokens`: `FlowLayout`, each token measured by a hidden, accessibility-hidden copy (`onGeometryChange`), `shownCount` picks how many show, then "+N more" (VoiceOver "N more tags", plural forms). A token not measured yet counts as a whole row, so the strip never draws past three rows while measuring. `MyDayFilterButton`: a `Menu` with Filter by Tags and Clear All Tags, no `primaryAction`. Summary strings in `MyDayScreen`. DESIGN.md's Filter token and Filter button entries and the symbol table are updated.
- UI test `testMyDayClearAllTags`: six tags (asserts "6 chosen" before going on), no duplicate token elements, "+N more" opens the sheet when shown, the tap menu, Clear All Tags clears tags and then No Tags. `openMyDayFilter()` opens the sheet through the menu when tags are chosen; the other filter shot tests use it.
- Review (Standards, Spec, iOS, smells). Fixed: plural forms for "+%lld more"; one wrap rule shared by `arrange` and `shownCount`, which reads the layout's own spacing; `.accessibilityHidden(true)` on the measuring copies (Apple's `hidden()` page confirms no interaction, says nothing on accessibility); the unmeasured-token fallback above; the No Tags check; stale mockup and script comments. Kept: "Filter by Tags" as one catalog key for the button's label and the menu item (same meaning; the catalog joins the comments, as for "Tags"); the "+N more" policy in `FlowLayout`, beside the wrap rule it depends on; three `onGeometryChange` calls.
- Device checks from the iOS review: VoiceOver on the `Menu` (label, "N chosen" value, both items), `.badge` and `.id` on a toolbar `Menu`, the Large Content Viewer at accessibility sizes (a long press then lift should open the menu), and any first-frame jump in the token rows.
- **Empty row (Brian, 2026-10-25):** the mockup's "Nothing is due today without tags." repeated the summary line "Due today with no tags". Brian asked which should stay; my recommendation, applied: keep the summary line (it shows whether or not anything is due, and is the only place with Match All or Any) and drop the filter words from the empty row, which says "Nothing is due today." as the app already does (`MyDayScreen.emptyMessage`). Mockup only; no app change.
- **One tag gets a line too (Brian, 2026-10-25):** with one tag there was no line under the token, unlike two or more and No Tags. It now says "Due today with the selected tag" (my wording; Match doesn't apply to one tag). Test first in `MyDayScreenTests`. The design, the summary criterion, DESIGN.md and the mockup include it.

### 2026-10-25: Shots; a clipping fix in FlowLayout; committed

- **Clipping at the largest size:** "#appointments ×" is wider than the screen there. `FlowLayout` laid each item at its ideal width, so the strip ran past the row and the list centred it, cutting off both edges ("#home" read "/home"). An item wider than the row is now given the row's width, so its text wraps inside the capsule ("#appoint-ments"). `MyDayCounts` uses the same layout and gets the same fix.
- **Harness:** `testMyDayClearAllTags` chose only 5 tags in landscape and at the largest size: `tapText` scrolls only down, and #appointments is first A to Z. It's chosen first now. The test asserts "6 chosen" before going on.
- **Shots**, `SHOTS_TESTS="testMyDayClearAllTags testMyDay"`, four variants, both simulators, all pass (`docs/screenshots/2026-10-25-ticket-20d/`, git-ignored). The tap menu opens at every size, including the largest, on both. At the default size all six tags show with no "+N more". At the largest, three tags, one per row, then "+3 more" on a row of its own; VoiceOver gets "3 more tags". On iOS 26.5 the menu draws its icons first, in system blue.
- `scripts/test.sh` passes on both simulators (334 app tests each, catalog check included).
- Ticked: the symbol and test criterion, the summary-line criterion, the DESIGN.md criterion.
- **Still open:**
  - The layout criterion needs Brian to confirm "+N more" on a row of its own.
  - The menu criterion's iPhone run.
  - The badge criterion: look at the `myday-cleared` shots.
  - The VoiceOver device check.
