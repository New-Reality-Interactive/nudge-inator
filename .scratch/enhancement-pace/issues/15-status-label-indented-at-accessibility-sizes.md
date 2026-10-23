# 15: The Done status label is indented at accessibility sizes

**What to build:** A bug fix. At accessibility sizes, a My Day row's "✓ Done" status label starts at the text's leading edge, as the as-built mockup draws it.

**Blocked by:** none.

**Status:** needs-triage

Found in ticket 11's simulator screenshots (`iPhone 15 Pro - iOS 26.5` and `iPhone 15 - iOS 27.0`, AX5, portrait and landscape), 2026-10-23. Brian asked for this ticket.

## The bug

Ticket 11 moved the status label under the row's text at accessibility sizes. There, the "✓ Done" label starts a little in from the leading edge of the time and title above it. The mockup (`docs/mockups/2026-10-21-as-built/`, `.cell .trail` at AX sizes) draws it flush.

`StatusLabel` (`App/Design/StatusComponents.swift`) is a `Label` for Done, with `checkmark.circle.fill` as its icon. Inside a `List`, the label style seems to give the icon a column of its own, wider than the symbol, so the label is indented. Missed, Skipped and Paused are plain text and aren't indented. This is a guess, not yet confirmed.

`StatusLabel` is used on other screens too, so check each one. At the default size the label is trailing, and any extra width there is hard to see.

## What it should do

- [ ] At accessibility sizes the Done status label's icon starts at the row text's leading edge, on both simulators, portrait and landscape (`scripts/screenshots.sh`, the `myday` screens).
- [ ] Every other screen that shows `StatusLabel` looks as it does now at the default size (screenshots compared with the as-built mockup).
- [ ] VoiceOver still reads the status as part of the row.

## Comments
