# Nudge-inator iOS mockup: filter badge

My Day's Filter button with its count as the system's badge, and the redrawn `tag.filter` symbol, as
proposed in enhancement-pace
[ticket 19](../../../.scratch/enhancement-pace/issues/19-filter-symbol-closer-to-the-tag-symbol.md).
It's a copy of the [tag-filter mockup](../2026-10-23-tag-filter/README.md), changed only for the
Filter button and the tag symbol, so the two can be compared screen by screen. Everything this README
doesn't list is as that mockup draws it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed

- **The count is a badge:** while tags are chosen, the Filter button carries a badge on its upper
  trailing corner with the number chosen, instead of the number beside the icon. Choose none and no
  badge shows. The icon still turns accent-colored while a filter is on. The button is a plain
  44 pt glass circle again, as when no tag is chosen.
- **Badge color:** drawn as the system's standard badge (red), as the Now tab's bell has. The build
  may not be able to change it, so **My Day's Filter badge → Badge color** switches to the accent
  teal to show the alternative. Which one ships is decided from the app's shots (ticket 19).
- **Badge number:** the same control group has **Badge number**, which shows 1, 12 or 999 on the
  badge to see how a wider badge sits beside New Reminder, in portrait, landscape and at the
  accessibility text sizes. The most tags a person can choose is 999.
- **`tag.filter`:** the `tag` outline with a three-line filter badge at the lower right, in a circular
  cutout of the tag; the badge hangs past the tag's edge. It is still a stand-in drawn in strokes, for
  the symbol in `App/Resources/Assets.xcassets/tag.filter.symbolset/`.
- **`tag` faces the right way:** the earlier mockups draw it with the narrow, dotted end at the upper
  left. The SF Symbols 27 `tag` has it at the upper right, so it is mirrored here everywhere it is
  drawn: the Tags tab, the Tags rows' icons and the empty state.
- **The badge over the dotted end:** with the symbol's dotted end at the upper right, where the
  system badge lands, the badge covers the dot. Try it at each size; mirroring the `tag.filter`
  symbol is the fallback.
- **Accessibility:** VoiceOver reads the button as before: "Filter by Tags", or "Filter by Tags, 2
  chosen". The badge is hidden from it, so the count isn't read twice. The app has to check that
  `.badge` does the same.

## What changed for ticket 20

Extended for enhancement-pace
[ticket 20](../../../.scratch/enhancement-pace/issues/20-clear-all-tags-icon-in-a-scrolling-token-row.md),
in this mockup rather than a new one, as the ticket asks.

Revised on 2026-10-25 after the app's shots: at the accessibility sizes a long press on a bar button
shows the Large Content Viewer, so the long-press menu couldn't be reached there. Brian replaced it
with a menu on a tap, and the sideways row with wrapping rows.

- **Tokens wrap, at most three rows:** My Day's chosen-tag tokens are the same 44 pt capsules and
  wrap as before, but never past three rows, so the counts stay near the top. Tokens that don't fit
  go into a **+N more** token at the end, which opens the filter sheet, where every tag is listed.
  At the largest size four tokens and "+2 more" fill the three rows. If "+N more" doesn't fit beside
  the third row's only token, it takes a row of its own, so three tags still show (as the app). Nothing scrolls inside My Day's
  list: the HIG warns against nesting scroll views of the same orientation ("Scroll views").
- **The Clear link is gone:** each token's × still removes one tag. Clearing them all is in the
  Filter button's menu.
- **The Filter button's menu:** while any tag (or No Tags) is chosen, a tap on the Filter button
  shows a menu with **Filter by Tags** (`tag.filter`), which opens the filter sheet, and **Clear All
  Tags** (`tag.xmark`), which removes every tag from the filter. With none chosen a tap opens the
  sheet as before. There's no long press. The menu is drawn like the iOS 26 menu that grows out of
  its button, with the icons before the text, as the system's menu has them (the app's shots).
- **`tag.xmark`:** Clear All Tags's icon: the same mirrored tag and circular cutout as `tag.filter`,
  with an × badge instead. A stand-in drawn in strokes, for the exported symbol in
  `App/Resources/Assets.xcassets/tag.xmark.symbolset/`.
- **Summary line:** with one tag it says "Due today with the selected tag". From two tags on, it
  says how they combine without naming them: "Due today with
  all selected tags" (Match All) or "Due today with any selected tags" (Match Any). With No Tags
  chosen it says "Due today with no tags". Only this
  line changes, and the empty row under the counts, which no longer repeats the filter: "Nothing is
  due today." (as the app). The filter sheet's text is as before.
- **Not shown:** the app hides the Filter button's badge at the accessibility sizes (ticket 19,
  after this mockup was approved). The mockup still draws it there.
- `scripts/mockup-shots.py` takes `myday-tokens-6` (six tags chosen) and `myday-filter-menu` (the
  Filter button's menu with six chosen).
