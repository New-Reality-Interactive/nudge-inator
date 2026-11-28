# Quiet hours banner

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

What the quiet hours banner mockup (`docs/mockups/2026-11-22-quiet-hours-banner/`, #499) adds. It
rewrites nothing above.
- **Shown** on Now, My Day and Reminders (Mine and Sent, empty states too) while Quiet Now is on or a
  schedule that's on covers the time, the same test as Settings' Quiet Hours row. It leads the content
  after any permission banners, above the lists, counts and filters; on Reminders it follows the
  Mine | Sent control, ahead of the sharing banner. On Reminders' empty states the banner and the
  empty state scroll as one page under that control: the banner at the top, the empty state centered
  in what is left (#516). Pinned, a banner taller than the screen pushed the control over the title.
- **Look:** the permission banner's card (`{colors.cell}`, `{rounded.card}`, 2 pt border) with a
  `{colors.neutral}` border and a `bell.slash` icon: being held is the person's own choice, not
  a problem to fix, so it uses neither red nor orange. A bold title, "Quiet hours are holding nudges",
  and under it, in `{colors.secondary-label}`, "Until 9:00 AM." (the latest end of the schedules
  running, as Settings' Until reads) or "Until you turn it off." for Quiet Now, then "Change this in
  Settings, under Quiet Hours."
- **Not tappable** (the developer's call, #499): it never leaves the tab, so it has no chevron, button
  or link styling, and names where to change quiet hours in words alone. VoiceOver reads it as one
  element. At accessibility text sizes the icon goes above the text, as the permission banner's does.
