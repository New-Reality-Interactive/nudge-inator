# 14: My Day's Filter button, the same in both orientations, and an icon that says tags

**What to build:** Two parts.

- **The icon, decided:** My Day's Filter button shows the custom `tag.filter` symbol (a tag with filter lines) in place of `line.3.horizontal.decrease`, wherever the button appears, so it says it filters by tags. Build it here.
- **The placement, still open:** research and a decision on whether the button should look and sit the same in portrait as in landscape. The outcome is a recommendation Brian agrees, recorded here, and the build tickets it needs.

**Blocked by:** none.

**Status:** needs-triage

Raised by Brian while checking ticket 11's screenshots, 2026-10-23.

## Today

`MyDayFilterButton` (`App/MyDay/MyDayFilterControls.swift`):

- **Portrait:** a bordered button in the content, above the counts. It reads "Filter by Tags", or "Filter (2)" while tags are chosen.
- **Landscape:** the mockup moves it into the navigation bar as an icon (`line.3.horizontal.decrease`) beside New Reminder, with the number of chosen tags.

The as-built mockup (`docs/mockups/2026-10-21-as-built/`) draws both.

## Questions to answer

- Should portrait match landscape, or the other way round? Weigh discoverability, the room a labelled button takes above the list, reach, and what Apple's apps do (Mail, Reminders, Files).
- ~~Is there an SF Symbol, or a pairing, that says "filter by tags" better than the funnel lines?~~ Decided: `tag.filter` (Comments, 2026-10-23).
- How does each option read with VoiceOver and at accessibility sizes, in both orientations?

## What it should do

- [x] The options, with Apple's guidance (apple-rag-mcp) and the mockup's view of each, are written up here.
- [ ] My Day's Filter button shows `tag.filter` in place of `line.3.horizontal.decrease`, in the bar beside New Reminder in portrait and landscape (placement B), with the chosen-tag count fitting beside it. Shot on both simulators at the default and largest text sizes; Brian signs off the shots. (Reworded 2026-10-23: B is built here; Comments.)
- [ ] VoiceOver reads the button as before ("Filter by Tags", with the count when tags are chosen).
- [x] DESIGN.md's symbol table uses `tag.filter` for the Filter button, and a new mockup, `docs/mockups/2026-10-23-tag-filter/`, draws it (reworded 2026-10-23: the dated mockups stay as they are; Comments).
- [x] Brian picks a placement, recorded in Comments, and it's built here rather than in a new ticket (reworded 2026-10-23; Comments).

## Before you start

- Builds on: ticket 11: `MyDayFilterButton` in both orientations, and the `largest-text-landscape` screenshot variant (its Comments). Ticket 11's Comments also record the phone's VoiceOver reading of the bar icon, "Filter by Tags, button", which is the baseline for "reads as before". The `tag.filter.symbolset` in the asset catalog is untracked in the working tree. Commit it on this ticket's branch.
- Watch for: on `iPhone 15 - iOS 27.0` in `largest-text-landscape`, `testMyDay` can't find the bar's Filter button, so `myday-filter` isn't shot there (tickets 11 and 12). The phone shows the button works. Shoot only what you need with `SHOTS_TESTS` and a `SHOTS_OUT` of its own. The iOS 26.5 simulator can stop turning to landscape, so look at a shot before trusting it (ticket 12). The status is `needs-triage`. Brian decides whether it's ready.
- Developer stops: no `tdd` seams for the icon (a symbol swap), so say so. Simulator shots of `myday` and `myday-filter` at the default and largest sizes, both orientations, for Brian to sign off. Brian's pick of a placement from the written-up options. The offer of an iPhone run.

## Comments

### 2026-10-23: the icon is decided

- Brian supplied a custom symbol, `tag.filter`: a tag with three filter lines, drawn as a variable template (Ultralight-S, Regular-S, Black-S, each a single filled path), and asked for it to replace the tag filter button's icon wherever it's used, folded into this ticket. The only use in the app is `MyDayFilterButton`, in both orientations; DESIGN.md's symbol table and both mockups name the old icon too.
- The template was checked against Apple's docs ("Creating custom symbol images for your app"; "Creating custom symbols") and Xcode's asset compiler. Three fixes made it valid: the required `template-version` text in Notes; Black-S's hole contour given 41 points like the other two weights, so the three interpolate; and left and right margin guides for the three sources, which Xcode requires (set at each glyph's outer edges, so adjust them if optical alignment calls for it). It's now in the app's asset catalog as `tag.filter.symbolset`, left uncommitted for this ticket's branch; `actool` compiles the catalog with it, with no errors or warnings.
- Things to know: Regular-S rises 1.5 units and Black-S 5 units above the Small capline; Apple's docs don't forbid that, so it was left. Coordinates have 2 decimal places, where the docs recommend 7 or more. Xcode accepts it as is.
- The placement question stays open, and so does whether the badge needs adjusting for the new glyph.

### 2026-10-23: the icon is built

- `MyDayFilterButton` loads `tag.filter` with `Image(_:)`, the documented way to load a custom symbol from the asset catalog (`Image(systemName:)` looks only at system symbols): "Configuring and displaying symbol images in your UI". The one constant changes, so both styles take it. No `tdd` seams: a symbol swap has no behaviour to test.
- DESIGN.md's symbol table names `tag.filter` as a custom symbol. Both current mockups draw it as a stroked stand-in (a right-pointing tag with three shortening lines) under the key `tag.filter`. The archived mockups keep the old icon.

### 2026-10-23: placement, the options

Today, in the app and the as-built mockup: portrait has a labelled bordered button in the content above the counts ("Filter by Tags", "Filter (2)"); landscape has an icon in the bar at `.topBarTrailing`, beside New Reminder, with the count beside it in the accent color. VoiceOver reads both the same: "Filter by Tags", or "Filter by Tags, 2 chosen".

What Apple's docs say (apple-rag-mcp):

- HIG, Toolbars › Actions: "Prefer simple, recognizable symbols for items instead of text", and "Don't make people guess or experiment to figure out what a toolbar item does." iOS: "Because space is so limited, carefully consider which actions are essential."
- Adopting Liquid Glass: represent common toolbar actions with icons instead of text; don't mix text and icons in items that share a background; always give an icon an accessibility label.
- Large Content Viewer (WWDC19 "Large Content Viewer"; `accessibilityShowsLargeContentViewer()`): bar items stay small at accessibility sizes, and standard bars show the viewer on a long press instead. Apple says not to use it in place of Dynamic Type, only where items "must remain small". So a bar icon doesn't grow at AX5; a content button does.
- Not confirmed by the docs: whether a SwiftUI `ToolbarItem` holding a custom `Button` gets the viewer on its own (device check), and what Mail, Reminders and Files do with filters. Those apps' layouts aren't in Apple's developer docs; check them on the phone rather than from memory.

| | A: no change | B: bar icon in both | C: labelled button in both |
|---|---|---|---|
| Portrait | labelled button above the counts | icon + count in the bar beside New Reminder | labelled button above the counts |
| Landscape | icon + count in the bar | icon + count in the bar | labelled button in the content, where landscape's room is shortest |
| Discoverability | words in portrait; the icon (now a tag) in landscape | the icon only; `tag.filter` now says tags, and the filter tokens under the counts show what's chosen | words in both |
| Room above the list | portrait gives a row to it (several at AX5, where it wraps) | frees that row in portrait | costs a row in landscape too, where height is scarcest |
| Accessibility sizes | grows in portrait; small bar icon in landscape | small in both; relies on the Large Content Viewer | grows in both |
| Matches HIG toolbar guidance | in landscape | yes | the bar keeps only New Reminder |
| VoiceOver | as today | as today (same label) | as today |
| Mockup | as drawn now | portrait's bar gains the icon; the content row goes | landscape's bar loses the icon; the content row comes back |

Recommendation: **B**. The new icon removes the main reason for words in portrait, it frees a row above the list, it matches the bar Apple describes, and both orientations then behave the same. The cost is AX5: the bar icon stays small, so B's build ticket would check the Large Content Viewer on the phone and add `accessibilityShowsLargeContentViewer()` if the bar doesn't give it. If keeping the words at large sizes matters more, A stays as is.

### 2026-10-23: mockups, and Brian's placement pick

- Mockups: Brian asked that the two dated mockups stay as they are. `2026-10-21-as-built` is the mock made after v1.0.0 was tagged, and `2026-10-21-proposed-pace` shows the pace system. A significant visual change gets its own new mockup, made first, and the decision follows it. The edits to both were undone, and the mockup criterion is reworded to match.
- New mockup: `docs/mockups/2026-10-23-tag-filter/`, a copy of `proposed-pace` changed only for the Filter button (its README lists what changed).
- Placement: Brian picked **B**. The Filter icon sits in the bar beside New Reminder, in both orientations. The new mockup draws only B: in portrait the labelled button's row above the counts is gone, and the count capsule fits beside New Reminder at the default size and at AX5.
- Build: Brian chose to build B in this ticket rather than file a new one. Criteria 2 and 5 are reworded to match. `MyDayFilterButton` loses its content style, so the "Filter (%lld)" string goes, and My Day's list loses the button's row. The screenshot harness shoots `myday-filtered` (a tag chosen, so the count shows) after `myday-filter`, and no longer scrolls back up to find the button.
- Icon size: Brian asked for the icon to be as tall and wide as the + in New Reminder. In the app the glyph is already as tall as the + (about 57 px against 55 in the iOS 27 landscape shot) and wider, because a tag is longer than it is tall. The mockup's stand-in was the small one: drawn at 22 pt against the +'s 24, and 13 units tall against the +'s 15. It is now drawn at 24 pt and as tall as the +.
- Brian approved the new mockup, `docs/mockups/2026-10-23-tag-filter/` (placement B, the icon as tall as the +), 2026-10-23.

### 2026-10-24: tests, review, shots

- `scripts/test.sh` passed on both simulators.
- Review (Standards, Spec, iOS, code smells): no hard violations and nothing to fix in code. Notes:
  - At accessibility sizes the bar button stays bar-sized and doesn't grow with Dynamic Type, where the labelled button used to wrap. CODING_STANDARDS.md › Accessibility asks text to wrap or stack at large sizes. Brian's approval of the new mockup covers this: its README says the bar button stays bar-sized, and the chosen tags show as tokens, which do scale.
  - Proposed, for Brian to agree or not: the options write-up said B's build would check the Large Content Viewer on the iPhone, and no criterion covers that yet. Apple's docs don't say whether a SwiftUI toolbar `Button` gets it automatically. The proposal is a device check at AX5: long-press Filter. If no viewer appears, add `accessibilityShowsLargeContentViewer` with the "Filter by Tags" label and the `tag.filter` image.
  - The mockup draws the count in the accent color while the filter is on. The app draws it in the bar's monochrome, as it did in landscape before this ticket. This drift came from the proposed-pace mockup, not from this ticket.
  - Seen in the AX5 shots, not this ticket's: the Now marker breaks "AM" across two lines ("12:03 A / M").
- Shots: `docs/screenshots/2026-10-23-ticket14-B/` (git-ignored), `testMyDay`, all four variants on both simulators, including the new `myday-filtered`. On iOS 27 every variant shot, including `myday-filter` at AX5 in landscape, the gap from tickets 11 and 12, which is now gone because Filter no longer needs a scroll back to reach it. The iOS 26.5 simulator didn't turn for either landscape variant (ticket 12), and a plain retry didn't help. After a simulator restart (`xcrun simctl shutdown`) it turned, and both landscape variants were reshot into `docs/screenshots/2026-10-23-ticket14-B-265-landscape/`. Use those for iOS 26.5 landscape.
