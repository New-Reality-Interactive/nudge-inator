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
