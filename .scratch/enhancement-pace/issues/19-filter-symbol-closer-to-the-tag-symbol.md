# 19: The Filter symbol is redrawn closer to the Tags tab's tag, and its count becomes a badge

**What to build:** My Day's Filter button shows a redrawn `tag.filter` symbol: the Tags tab's `tag` outline with a three-line filter badge at the lower right, so the two icons read as related. The number of tags chosen stops being text beside the icon and becomes the system's badge on the button, like the badge on the Now tab's bell.

**Blocked by:** none.

**Status:** needs-triage

Raised by Brian, 2026-10-24. Brian decides whether it's ready.

## What changes

Ticket 14 added `tag.filter`: a horizontal tag with three filter lines inside it. The Tags tab navigates to the Tags screen with the system `tag` symbol, and the Filter button opens the tag sheet as a filter. Brian wants the two to look related.

The redrawn symbol replaces the SVG inside `App/Resources/Assets.xcassets/tag.filter.symbolset/`. It keeps the same symbol name and file name, and `Contents.json` doesn't change. `MyDayFilterButton` loads `"tag.filter"` by name (`App/MyDay/MyDayFilterControls.swift:11`), so the symbol swap needs no code change.

The count changes too. `MyDayFilterButton` drops the `HStack` and the `Text` that shows the number of tags chosen beside the icon, and puts a badge on the button's content with `.badge(chosen)`. A count of 0 hides the badge on its own. The button keeps its accessibility label, which already says how many are chosen. The type's doc comment, which says the count sits "beside" the icon, is updated to match. The tint that turns the button accent-colored while a filter is on stays as it is.

## The new symbol

- **Source:** `~/Downloads/tag.filter.svg`, exported from the SF Symbols app (version 27.0) with File → Export Symbol. Template v7.0, SF Symbols' default annotations.
- **Design:** Apple's own `tag` outline plus a three-line, decreasing-width filter badge at the lower right, with a circular cutout in the tag where the badge sits. The badge is about 8% larger than the first draft; Brian approved that size.
- **Checked so far:** `actool` compiles it with no errors or warnings, including with the deployment target at iOS 26.1. It renders correctly at all nine weights, so the three sources (Ultralight-S, Regular-S, Black-S) interpolate. Each source is one path with the same structure.
- **One layer:** the tag and badge are one layer, so hierarchical and palette rendering treat them as one. That's fine: the button draws monochrome, tinted with the accent color while a filter is on. Splitting the badge into its own layer would be separate work in SF Symbols.
- **Orientation:** it matches the SF Symbols 27 `tag` template, with the narrow, dotted end at the upper right. Brian's Tags tab screenshot appears mirrored relative to it, so compare the two on the phone. Brian said to keep the new symbol as it is, and that stays true with the badge.
- **Wider than the old one:** the badge hangs past the tag's right edge.
- **The system badge lands on the dotted end:** the tag's dotted end is at the upper right, where the system badge lands, so the badge covers the dot. Brian saw a layout mock of this and chose to keep the symbol as it is. Mirroring the symbol is the fallback if it looks wrong in the shots.

## The count as a badge

What Apple's docs say (`apple-rag-mcp`):

- **Confirmed:** SwiftUI's `badge(_:)` is documented as appearing in "list rows, tab bars, toolbar items, and menus". The WWDC25 session "Build a SwiftUI app with the new design" (session 323) badges a toolbar item by applying the modifier to its content. `UIBarButtonItem.badge` is iOS 26+ and supports navigation bars and toolbars. The app's minimum is iOS 26.1, so no `#available` path is needed.
- **Not confirmed, so these are checks on the simulators and the iPhone:**
  - **Color:** the system draws these red. SwiftUI documents no way to change a toolbar badge's background or text color. `UIBarButtonItem.Badge` has `backgroundColor` and `foregroundColor` in UIKit only. The `badge(_ label: Text?)` overload says styling the `Text` works, but it names no effect for toolbar items.
  - **Placement and size:** the system decides them. Nothing says how the badge behaves at the largest text size, in landscape, or at counts of 10 and above. The most tags a person can choose is 999, so check that.
  - **VoiceOver:** the label already includes the count, so the system may read it twice.

## What it should do

- [x] `tag.filter.symbolset/tag.filter.svg` is the redrawn symbol. `actool` compiles the catalog with no errors or warnings, and `scripts/test.sh` passes.
- [ ] My Day's Filter button shows the new symbol in the bar beside New Reminder, in portrait and landscape, with no tag chosen and with tags chosen. Shot on both simulators at the default and the largest text size. Brian signs off the shots.
- [ ] The count is a system badge on the Filter button, not text beside the icon, and no badge shows when the count is 0. The badge shows in portrait and landscape, at the default and the largest text size, with counts of 1, 12 and 999. It isn't clipped at the trailing edge, and it doesn't push or crowd New Reminder. Shot on both simulators, and Brian signs off.
- [x] The badge's background is the teal accent color if the system allows it, and the system's standard badge if not. Try the SwiftUI options first: a tint, and `.badge(Text("\(chosen)").foregroundStyle(…))`, and look at the capsule in the shots. If the capsule stays system red, keep the standard badge; Brian has accepted that. Don't draw a custom badge, which would drop the system's placement and accessibility behavior. If the capsule does turn teal, its number stays legible in light and dark. Record in Comments which it is and what was tried.
- [x] `docs/design/DESIGN.md` uses red `{colors.badge}` only for the Now tab's nudging count, and says a count of 0 is never red. Record in Comments whether the filter count's badge fits that rule: a red capsule means the rule needs a line saying the Filter button's count is also drawn as the system's badge; a teal one means it needs a line for the accent-colored badge. Update DESIGN.md to match.
- [x] In the shots, the badge over the tag's dotted end is looked at, and Brian decides whether the symbol stays as it is or is mirrored. Record it in Comments.
- [ ] VoiceOver reads the button once, as "Filter by Tags", with the count when tags are chosen, and does not read the count twice. Device check.
- [x] A new interactive HTML mockup, `docs/mockups/2026-10-24-…/` (`index.html` and a `README.md`, like the other dated mockups), is made first, and Brian approves it before any code changes: no symbol swap, no change to `MyDayFilterButton`, nothing in the app target until he has. It is a copy of `2026-10-23-tag-filter` changed only for this ticket, and its README lists what changed:
  - The Filter button's count is a badge on the button, not text beside the icon. Choosing tags in the mockup shows it; choosing none hides it; it can be tried at counts of 1, 12 and 999. It is drawn as the system's standard badge (red), with a switch to the accent teal so Brian can see both, since the build may not be able to do teal.
  - The `"tag.filter"` entry in the mockup's symbol table is redrawn to match the new symbol: the `tag` outline with the three-line filter badge at the lower right. It is still a stand-in drawn in strokes.
  - The Tags tab's `tag` icon faces the right way. The mockups draw it mirrored: the narrow, dotted end is at the upper left, where the SF Symbols 27 `tag` has it at the upper right. The new mockup draws it as the real symbol is, everywhere it uses `tag`: the tab bar, the Tags row icons and the empty-state icon.
  - The earlier dated mockups stay as they are.
- [x] `docs/design/DESIGN.md`'s symbol table (line 323) is checked for the old icon. Record the decision in Comments.

## Before you start

- Apple platform questions go through `apple-rag-mcp` (AGENTS.md). The relevant pages are "Creating custom symbol images for your app", SwiftUI's `badge(_:)`, and `UIBarButtonItem.badge`.
- Start with the mockup. Brian's approval of it gates every code change; stop and ask for it before touching the app.
- Developer stops:
  - `tdd` seams: none, because it is a symbol swap and a view modifier. Say so.
  - Simulator shots of `myday` and `myday-filter` at the default and largest text sizes, in both orientations, on both simulators, with counts of 1, 12 and 999.
  - Whether the badge can be teal, shown in the shots. Brian has already said red is fine if it can't.
  - Brian's call on the badge covering the dotted end.
  - The offer of an iPhone run, for the VoiceOver check.
  - The new dated mockup, made first and approved by Brian before any code changes (a mockup has no behaviour, so it skips `tdd`; say so).
- Watch for: the iOS 26.5 simulator can stop turning to landscape. Look at a landscape shot before trusting it (ticket 15, Comments).

## Comments

### 2026-10-24: The count becomes a badge

- Brian added a second change to this ticket: the Filter button's count becomes the system's badge (`.badge(chosen)`) instead of text beside the icon. The tag symbol stays as the ticket describes it, so orientation doesn't change.
- Docs: `badge(_:)` is documented for toolbar items and the WWDC25 session shows it, so it is supported. The color, the placement at large sizes and at counts of 10 and above, and VoiceOver are not documented. They are checks, listed under "The count as a badge".
- The badge lands on the tag's dotted end and covers the dot. Brian saw a layout mock of this and chose to keep the symbol as it is. If it looks wrong in the shots, mirroring the symbol is the fallback.
- Ticket 15's Comments has a "Filter count color" item: the count is accent-colored in the mockup and monochrome in the app. The badge changes what that question means, because the count is no longer text in the bar's tint. Ticket 15 is not edited. The badge's color criterion here replaces the question.
- Badge color, decided by Brian: he would like the badge background to be the teal accent color, but if the system can't do that, the standard badge (red) is fine. The ticket tries the SwiftUI options and keeps the system badge if the capsule stays red. A custom badge is not wanted.
- Mockup: a new interactive HTML mockup, `docs/mockups/2026-10-24-…/`, is required, not optional. The count moving to a badge changes what `docs/mockups/2026-10-23-tag-filter/` shows. Brian also noticed that the mockups draw the Tags tab's `tag` icon facing the wrong way (the dotted end at the upper left; the real symbol has it at the upper right), and the new mockup corrects it. The dated mockups stay as they are.
- Brian requires his approval of the new mockup before any code changes are made.

### 2026-10-24: The mockup is made, waiting for Brian

- `docs/mockups/2026-10-24-filter-badge/` is a copy of `2026-10-23-tag-filter` with the changes the criterion lists (README has them). No app code, symbol or test has changed. `tdd` is skipped: a mockup has no behaviour.
- Checked in headless Chrome at portrait, landscape and AX5, with 1, 12 and 999 and both colors: the badge sits on the button's upper trailing corner, and 999 almost touches New Reminder's left edge (no overlap at 393 pt wide).
- The mockup's `tag` is mirrored with a group transform on the old outline, so the dotted end is at the upper right. `tag.filter` is that outline in a mask with a circular cutout, plus three stroked lines. It is a stand-in, not the exported SVG.
- Stopped here for Brian's approval of the mockup before any code changes.

### 2026-10-24: Brian approved the mockup

- Brian approved `docs/mockups/2026-10-24-filter-badge/`. He tried the teal badge (the **Badge color** control, which he first missed; a browser restoring the select's value without a change event was also fixed) and likes it, and he confirmed the Tags tab icon now faces the right way.
- Not decided yet, so still open under their own criteria: whether the shipped badge can be teal (decided by what SwiftUI allows in the app), and whether the symbol stays or is mirrored (decided from the app's shots).

### 2026-10-24: What the app does, and Brian's calls

Built: the redrawn `tag.filter.svg` replaces the old one; `MyDayFilterButton` is an icon with `.badge(chosen)`; DESIGN.md's badge rule and symbol row are updated. The harness has a `BadgeBarShot` screen and `testMyDayFilterBadge`, because counts of 12 and 999 can't be reached by tapping tags; they show the real Filter button and New Reminder at a given count.

- **Badge color:** the capsule stays the system's red. Tried on the iOS 27.0 simulator: `.tint(Color.accentColor)` on the button (already there for the icon), and `.badge(Text(chosen, format: .number).foregroundStyle(Color.white))`. Neither changed the capsule. Only UIKit's `UIBarButtonItem.Badge.backgroundColor` (iOS 26) can, which would mean bridging to the navigation item; not done, as the ticket says to keep the standard badge and not draw a custom one. The number is white on red in light and dark.
- **DESIGN.md:** the filter count's badge is red, so the rule gets a line: the Now tab's nudging count and the Filter button's count are both the system's badge, and a count of 0 shows no badge, so it is never red. The symbol table row describes the new `tag.filter`. Symbol table checked for the old icon: only that one row named it.
- **Largest text size (iOS 27.0 simulator):** the system draws the badge at the system text size, so it grows while the bar button doesn't. At the largest size 1 and 12 cover most of the tag icon, and 999 shows as "9…". `.dynamicTypeSize(...xxxLarge)` on the button changed nothing, so it was removed. **Brian's call: keep the system badge at every text size.** The chosen-tag tokens under the date still list what is chosen, and the VoiceOver label still has the count.
- **Dotted end:** the badge covers the dot while tags are chosen, and the symbol still reads as a tag with filter lines. **Brian's call: keep the symbol as it is, not mirrored.**

### 2026-10-24: Shots on both simulators

`SHOTS_TESTS="testMyDay testMyDayFilterBadge"` in `portrait`, `landscape`, `largest-text` and `largest-text-landscape`, both simulators, 6 min 26 s, in `docs/screenshots/2026-10-24-ticket-19/<simulator>/<variant>/` (git-ignored): `myday-filtered` (count 1, a real tag chosen), `myday-badge-12`, `myday-badge-999`, and `myday` and `myday-filter` with no tag chosen.

- **iOS 27.0:** the badge is on the Filter button's upper corner at every count. At the largest text size it grows with the text, covers the icon, and 999 reads "9…" (see the earlier Comment).
- **iOS 26.5:** the badge stays small at the largest text size, in portrait and landscape; 999 reads "999" and sits on the corner without touching New Reminder. So the large-text problem is iOS 27's drawing, not something every phone shows. The only phone available is on iOS 27.x, so Brian will see the iOS 27 version on the device.
- No badge when no tag is chosen, on both.
- Landscape turned correctly on both simulators in every variant.
- `scripts/mockup-shots.py` takes `myday-badge-12` and `myday-badge-999` from the filter badge mockup, so they can be put beside the app's.
- The device check (VoiceOver reading the count once) and Brian's sign-off of the shots are still open. The iOS reviewer found no doc saying whether `.badge` is read on top of the label that already has the count, so the check is real: with 0, 1 and 12 chosen.

### 2026-10-24: iPhone check 2 found a stale badge

On Brian's iPhone (iPhone 15, iOS 27.0.1), default text size, VoiceOver off: no badge with no tag chosen; choosing one then two tags in the filter sheet showed "1" then "2", in portrait and landscape, on the button's upper corner, over the dotted end (the symbol still reads as a tag with filter lines).

**Bug:** removing tags from My Day (a token's x, or Clear) left the old count on the badge, in both orientations; the icon's tint did follow. Reproduced on the iOS 27.0 simulator with a new shot test, `testMyDayFilterBadgeFollowsTokens` (choose two tags, remove one, remove the other): the badge stayed "2" after the first and after the last removal. The simulator shots missed it because they only ever raised the count, through the sheet.

**Fix:** `.id(chosen)` on the button, so each count is its own toolbar item and its badge is built again. The same test now shows "1" after the first removal and no badge after the second (iOS 27.0 simulator). Cause not found beyond that: `.badge` on a toolbar button doesn't refresh when the value changes without the sheet closing, and the docs say nothing about it.

### 2026-10-24: iPhone check 3: the badge at the largest text size

On Brian's iPhone (iOS 27.0.1), with Larger Accessibility Sizes turned on and the slider at the far right (it was off, slider at the default): the badge grows with the text and covers the tag icon, in portrait and landscape, as on the iOS 27.0 simulator. So it is how iOS 27 draws it. Only the iOS 26.5 simulator keeps it small. Apple's docs say nothing about how a bar badge should scale.

**Brian's call (revises the earlier "keep the system badge at every size"):** hide the badge at the accessibility text sizes for now, and open a research ticket on what using UIKit instead of SwiftUI would mean: ticket 21.

**Built:** `MyDayFilterButton` takes `showsBadge`, which `MyDayTab` sets to false at the accessibility sizes. It has to be read there: the Dynamic Type size inside a toolbar is the bar's, which stays below the accessibility sizes (a first try that read it in the button did nothing; this also explains why limiting the button's size did nothing earlier). At those sizes the icon shows in full and stays teal while a filter is on, the chosen-tag tokens list the tags, and the VoiceOver label keeps the count. iOS 27.0 simulator: default size shows the badge (1, 12, 999); largest size shows none.

**Differs from the approved mockup:** `2026-10-24-filter-badge` shows the badge at every size. A frozen mockup isn't edited; this is the record of why the app doesn't match it at the accessibility sizes. DESIGN.md says so.

### 2026-10-24: iPhone check 4: VoiceOver read the count twice

Brian's iPhone (iOS 27.0.1), default text size, VoiceOver on: no tag chosen, "Filter by tags, button"; one tag, "Filter by tags, 1 chosen, 1, button"; two tags, "Filter by tags, 2 chosen, 2, button". The system badge adds its own count after the label, which already had it. That is what the iOS review warned the docs couldn't rule out.

**Fix:** the label is always "Filter by Tags", and the count is the accessibility value ("1 chosen"), none when no tag is chosen. The string catalog has the value as a plural-variant entry and no longer has the old label's. A new shot test, `testMyDayFilterAccessibility`, prints what the Filter button exposes (the iOS 27.0 simulator): with none, label "Filter by Tags", value ""; with one, value "1 chosen"; with two, "2 chosen". An explicit value replaces the badge's own, in what the app exposes. Whether VoiceOver now speaks "Filter by tags, 1 chosen, button" needs the iPhone again. At the accessibility sizes the badge is hidden, and the value still carries the count.

