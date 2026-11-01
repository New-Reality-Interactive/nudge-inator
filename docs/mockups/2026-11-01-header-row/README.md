# Nudge-inator iOS mockup: Reminders header row

The change mockup for #111's header row: the [Sort menu mockup](../2026-11-01-sort-menu/README.md)
with the row's controls rearranged. It is copied from that change mockup, not from 1.2.0, because
1.2.0 has no Reminders tab. Once Brian signs it off on #111, the header row is checked against it.
The release's `1.3.0` mockup takes it in and deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed since the Sort menu mockup

- **The chips and the Sort button are apart:** the chips sit at the leading edge and the Sort button
  at the trailing edge, on one line under the count. They were together after the count, the Sort
  button first. Brian's call during #111's simulator check (2026-11-01).
- **The count has its own line in every size and orientation,** landscape included.
- **At large text** the chips wrap at the leading edge and the Sort button stays at the trailing
  edge of the first line.

Nothing else changed. The earlier mockups' choices, known differences and screens stand.
