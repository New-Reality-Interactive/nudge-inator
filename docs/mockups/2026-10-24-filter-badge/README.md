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

- **One scrolling row:** My Day's chosen-tag tokens sit in a single row of the same 44 pt capsules,
  which scrolls sideways. Six tags no longer wrap to three rows, so the counts stay where they are.
- **The Clear link is gone:** each token's × still removes one tag. Clearing them all is in the
  Filter button's menu.
- **Long-press menu on the Filter button:** while any tag (or No Tags) is chosen, a long press on the
  Filter button shows a menu with **Clear All Tags**, which removes every tag from the filter. A tap
  still opens the filter sheet (SwiftUI's `Menu` with a primary action). With none chosen there is no
  menu. With a mouse, a right-click shows it too. The menu is drawn like the iOS 26 action sheet
  that grows out of its button, with the icon before the text, as iOS 26 menus appear to have it
  (WWDC25, "Get to know the new design system"). The system's menu may look a little different; the
  app's shots show it.
- **Scrolling with a mouse:** a phone scrolls the row with a finger. Here it also drags with the
  mouse, and a vertical wheel or trackpad scrolls it sideways. A drag doesn't tap a token.
- **`tag.xmark`:** the menu item's icon: the same mirrored tag and circular cutout as `tag.filter`,
  with an × badge instead. A stand-in drawn in strokes, for the exported symbol in
  `App/Resources/Assets.xcassets/tag.xmark.symbolset/`.
- **The fade:** while more tokens are off the trailing edge, the row fades out there. At the end of
  the row the fade goes.
- **Summary line:** unchanged. It still names every chosen tag, so nothing is hidden when the row has
  scrolled.
- **Tokens at the accessibility sizes:** a new control in **My Day's Filter badge** switches the row
  at AX1 to AX5 between **Scroll in one row** (the default) and **Wrap**, so the two can be compared.
  Which the app ships is decided from the app's shots (ticket 20).
- **Not shown:** the app hides the Filter button's badge at the accessibility sizes (ticket 19,
  after this mockup was approved). The mockup still draws it there.
- `scripts/mockup-shots.py` takes `myday-tokens-6` and `myday-tokens-6-wrap` (six tags chosen).
