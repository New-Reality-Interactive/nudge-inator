# Nudge-inator iOS mockup: tag filter

My Day's Filter button, as decided in enhancement-pace
[ticket 14](../../../.scratch/enhancement-pace/issues/14-my-day-filter-button-across-orientations.md).
It's a copy of the [proposed-pace mockup](../2026-10-21-proposed-pace/README.md), changed only for
the Filter button, so the two can be compared screen by screen. Everything this README doesn't list
is as that mockup draws it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed

- **The icon:** `tag.filter`, a custom symbol (a tag with three filter lines) in the app's asset
  catalog, replaces `line.3.horizontal.decrease`. The mockup draws a stroked stand-in for it.
- **The placement:** Filter is a bar button beside New Reminder in both orientations. In portrait it
  was a labelled bordered button ("Filter by Tags", "Filter (2)") above the counts; that row is
  gone. While tags are chosen the bar button is a capsule with the number chosen beside the icon,
  in the accent color, as landscape already drew it.
- **Accessibility:** VoiceOver reads the button as before: "Filter by Tags", or "Filter by Tags, 2
  chosen". At accessibility text sizes the bar button stays bar-sized, as bar buttons do; the
  chosen tags show as tokens under the date, which do scale.
